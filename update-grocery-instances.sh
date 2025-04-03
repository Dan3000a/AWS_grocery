#!/bin/bash

# Fully automated deployment update script for GroceryMate

# Configuration variables
REGION="eu-central-1"
ASG_NAME="grocery-asg"
BASTION_USER="ec2-user"
KEY_PATH="/Users/siebert/Documents/AWS_grocery/infrastructure/grocerymate-key.pem"
APP_INIT_REMOTE_PATH="/home/ec2-user/backend/app/__init__.py"
APP_DIR_REMOTE="/home/ec2-user/backend/app"
S3_BUCKET="grocerymate-app-bucket"
FRONTEND_DIR="/Users/siebert/Documents/AWS_grocery/frontend"
LOG_FILE="/Users/siebert/Documents/AWS_grocery/deployment.log"

# Ensure log file exists
touch "$LOG_FILE"

# Logging function
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Error handling function
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Dynamically fetch Bastion Host IP
log "Fetching Bastion Host IP dynamically..."
BASTION_IP=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Name,Values=BastionHost" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].PublicIpAddress" --output text) || handle_error "Failed to fetch Bastion Host IP"
if [ -z "$BASTION_IP" ] || [ "$BASTION_IP" == "None" ]; then
    handle_error "No running Bastion Host found with tag 'Name=BastionHost'"
fi
log "Bastion Host IP found: $BASTION_IP"

# Generate secure JWT_SECRET_KEY
log "Generating secure JWT_SECRET_KEY..."
JWT_SECRET=$(openssl rand -hex 32) || handle_error "Failed to generate JWT_SECRET_KEY"

log "Creating or updating JWT secret in AWS Secrets Manager..."
aws secretsmanager create-secret \
    --name grocerymate-jwt-secret \
    --secret-string "{\"jwt_secret_key\":\"$JWT_SECRET\"}" \
    --region "$REGION" \
    || aws secretsmanager put-secret-value \
        --secret-id grocerymate-jwt-secret \
        --secret-string "{\"jwt_secret_key\":\"$JWT_SECRET\"}" \
        --region "$REGION" || handle_error "Failed to create or update JWT secret in AWS Secrets Manager"

# Define the full content of app/__init__.py
APP_INIT_CONTENT=$(cat << 'EOF'
import logging
import shutil
import tempfile
import zipfile
from logging.handlers import RotatingFileHandler
import os
import socket
from flask import Flask, send_from_directory, render_template, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager
from sqlalchemy import text
from flask_migrate import Migrate
from dotenv import load_dotenv
from datetime import timedelta
import requests
from dateutil import parser
import boto3
import json

load_dotenv()
db = SQLAlchemy()
migrate = Migrate()

def get_db_credentials():
    secret_name = "grocerymate-db-credentials"
    region_name = "eu-central-1"
    session = boto3.session.Session()
    client = session.client(service_name='secretsmanager', region_name=region_name)
    try:
        get_secret_value_response = client.get_secret_value(SecretId=secret_name)
    except Exception as e:
        raise Exception(f"Error fetching secret from AWS Secrets Manager: {e}")
    secret = json.loads(get_secret_value_response['SecretString'])
    return secret['username'], secret['password']

def get_jwt_secret_key():
    secret_name = "grocerymate-jwt-secret"
    region_name = "eu-central-1"
    session = boto3.session.Session()
    client = session.client(service_name='secretsmanager', region_name=region_name)
    try:
        get_secret_value_response = client.get_secret_value(SecretId=secret_name)
        secret = json.loads(get_secret_value_response['SecretString'])
        return secret['jwt_secret_key']
    except Exception as e:
        raise Exception(f"Error fetching JWT secret from AWS Secrets Manager: {e}")

POSTGRES_USER, POSTGRES_PASSWORD = get_db_credentials()
POSTGRES_DB = os.getenv("DB_NAME", "grocerymate")
POSTGRES_HOST = os.getenv("DB_HOST", "grocerymate.cp6kci4uaepj.eu-central-1.rds.amazonaws.com")
POSTGRES_PORT = os.getenv("DB_PORT", "5432")

CONNECT_ARGS = {
    "sslmode": "verify-full",
    "sslrootcert": "/home/ec2-user/rds-ca.pem"
}

class Config:
    SQLALCHEMY_DATABASE_URI = f"postgresql://{POSTGRES_USER}@/{POSTGRES_DB}"
    SQLALCHEMY_ENGINE_OPTIONS = {
        "connect_args": {
            "host": POSTGRES_HOST,
            "port": POSTGRES_PORT,
            "user": POSTGRES_USER,
            "password": POSTGRES_PASSWORD,
            "dbname": POSTGRES_DB,
            **CONNECT_ARGS
        }
    }
    print(f"Using Database Connection - Host: {POSTGRES_HOST}, User: {POSTGRES_USER}")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JWT_SECRET_KEY = get_jwt_secret_key()
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=4)

    @classmethod
    def is_rds(cls):
        rds_hostnames = ["rds.amazonaws.com", "amazonaws.com"]
        return any(h in POSTGRES_HOST for h in rds_hostnames)

    @classmethod
    def is_local_postgres(cls):
        return not cls.is_rds()

def detect_environment():
    if Config.is_rds():
        print("Running on AWS RDS (Production)")
    elif Config.is_local_postgres():
        print("Running on Local PostgreSQL (Development)")
    else:
        print("Could not detect database environment. Set POSTGRES_URI manually.")
    print(f"Using Database Connection - Host: {Config.SQLALCHEMY_ENGINE_OPTIONS['connect_args']['host']}")

detect_environment()

def fetch_frontend():
    pass

def create_app():
    app = Flask(__name__)
    CORS(app)
    handler = RotatingFileHandler('/home/ec2-user/backend/logs/grocerymate_error.log', maxBytes=1000000, backupCount=5)
    handler.setLevel(logging.ERROR)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    app.logger.addHandler(handler)
    logging.getLogger('').addHandler(handler)
    debug_handler = RotatingFileHandler('/home/ec2-user/backend/logs/grocerymate_debug.log', maxBytes=1000000, backupCount=5)
    debug_handler.setLevel(logging.DEBUG)
    debug_handler.setFormatter(formatter)
    app.logger.addHandler(debug_handler)
    app.logger.setLevel(logging.DEBUG)
    app.config.from_object(Config)
    db.init_app(app)
    JWTManager(app)
    migrate.init_app(app, db)

    @app.route('/api/debug')
    def debug_config():
        return jsonify({"database_uri": app.config['SQLALCHEMY_DATABASE_URI']})

    @app.route('/api/health')
    def health_check():
        try:
            with db.engine.connect() as connection:
                connection.execute(text("SELECT 1"))
            return jsonify({"status": "ok"}), 200
        except Exception as e:
            app.logger.error(f"Health check failed: {str(e)}")
            return jsonify({"status": "error", "message": str(e)}), 500

    @app.route('/')
    def serve_frontend():
        return send_from_directory('/var/www/html/build', 'index.html')

    @app.route('/<path:path>')
    def serve_static(path):
        return send_from_directory('/var/www/html/build', path)

    from .routes.config_routes import config_bp
    from .routes.user_routes import user_bp
    from .routes.product_routes import product_bp
    from .routes.auth_routes import auth_bp

    app.logger.debug("Registering blueprints...")
    app.logger.debug(f"Config blueprint: {config_bp.url_prefix}")
    app.logger.debug(f"User blueprint: {user_bp.url_prefix}")
    app.logger.debug(f"Product blueprint: {product_bp.url_prefix}")
    app.logger.debug(f"Auth blueprint: {auth_bp.url_prefix}")

    app.register_blueprint(config_bp)
    app.register_blueprint(user_bp)
    app.register_blueprint(product_bp)
    app.register_blueprint(auth_bp)

    app.logger.debug("All registered routes:")
    for rule in app.url_map.iter_rules():
        app.logger.debug(f"Route: {rule}, Endpoint: {rule.endpoint}")

    return app

if __name__ == '__main__':
    app = create_app()
    fetch_frontend()
    app.run(host='0.0.0.0', port=8000)
EOF
)

# Write content to a temporary file and verify it's not empty
log "Writing app/__init__.py content to temporary file..."
echo "$APP_INIT_CONTENT" > /tmp/__init__.py || handle_error "Failed to write app/__init__.py to temporary file"
if [ ! -s /tmp/__init__.py ]; then
    handle_error "/tmp/__init__.py is empty – possible content issue"
fi

# Step 1: Fetch the private IP addresses of running instances in the ASG
log "Fetching running instances in ASG $ASG_NAME..."
aws ec2 describe-instances --region "$REGION" --filters "Name=tag:aws:autoscaling:groupName,Values=$ASG_NAME" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,State.Name]" --output table | tee -a "$LOG_FILE"

INSTANCE_IPS=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:aws:autoscaling:groupName,Values=$ASG_NAME" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].PrivateIpAddress" \
    --output text) || handle_error "Failed to fetch instance IPs"

if [ -z "$INSTANCE_IPS" ]; then
    log "No running instances found in ASG $ASG_NAME"
    exit 1
fi

# Convert the space-separated list of IPs into an array (Bash 3.x compatible)
IPS_ARRAY=()
for ip in $INSTANCE_IPS; do
    IPS_ARRAY+=("$ip")
done
log "Found ${#IPS_ARRAY[@]} instances: ${IPS_ARRAY[*]}"

# Step 2: Update app/__init__.py and deploy frontend assets on each instance
for IP in "${IPS_ARRAY[@]}"; do
    log "Deploying to instance $IP..."

    # Update permissions for backend app directory
    log "Updating permissions on $IP before uploading app/__init__.py..."
    ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -J "$BASTION_USER@$BASTION_IP" "$BASTION_USER@$IP" /bin/bash << EOF | tee -a "$LOG_FILE"
        echo "Creating parent directory if it doesn't exist..."
        sudo mkdir -p $APP_DIR_REMOTE
        echo "Updating permissions for $APP_DIR_REMOTE and $APP_INIT_REMOTE_PATH..."
        sudo chown ec2-user:ec2-user $APP_DIR_REMOTE
        sudo chmod u+rw $APP_DIR_REMOTE
        if [ -f "$APP_INIT_REMOTE_PATH" ]; then
            sudo chown ec2-user:ec2-user $APP_INIT_REMOTE_PATH
            sudo chmod u+rw $APP_INIT_REMOTE_PATH
        fi
        echo "Verifying permissions..."
        ls -ld $APP_DIR_REMOTE
        if [ -f "$APP_INIT_REMOTE_PATH" ]; then
            ls -l $APP_INIT_REMOTE_PATH
        else
            echo "$APP_INIT_REMOTE_PATH does not exist yet, will be created by scp"
        fi
EOF

    # Upload __init__.py using scp
    log "Uploading app/__init__.py to $IP..."
    scp -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ProxyJump="$BASTION_USER@$BASTION_IP" /tmp/__init__.py "$BASTION_USER@$IP:$APP_INIT_REMOTE_PATH" || handle_error "Failed to upload app/__init__.py to $IP"

    # SSH into the instance to set up Gunicorn, Nginx, and frontend assets
    ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -J "$BASTION_USER@$BASTION_IP" "$BASTION_USER@$IP" /bin/bash << 'EOF' | tee -a "$LOG_FILE"
        echo "Ensuring log directory and files exist..."
        sudo mkdir -p /home/ec2-user/backend/logs
        sudo touch /home/ec2-user/backend/logs/grocerymate_error.log
        sudo touch /home/ec2-user/backend/logs/grocerymate_debug.log
        sudo chown ec2-user:ec2-user /home/ec2-user/backend/logs -R
        sudo chmod u+rw /home/ec2-user/backend/logs -R
        echo "Verifying log file permissions..."
        ls -l /home/ec2-user/backend/logs

        echo "Setting up Gunicorn service..."
        if [ ! -f "/etc/systemd/system/grocerymate.service" ]; then
            sudo bash -c 'cat > /etc/systemd/system/grocerymate.service << "SERVICE_EOF"
[Unit]
Description=GroceryMate Application
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/home/ec2-user/backend
ExecStart=/home/ec2-user/backend/venv/bin/gunicorn --bind 0.0.0.0:8000 --access-logfile /home/ec2-user/backend/logs/grocerymate.log --error-logfile /home/ec2-user/backend/logs/grocerymate_error.log run:app
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE_EOF'
            sudo systemctl daemon-reload
            sudo systemctl enable grocerymate.service
        fi
        echo "Updating Gunicorn service to remove hardcoded JWT_SECRET_KEY..."
        sudo sed -i '/Environment="JWT_SECRET_KEY=/d' /etc/systemd/system/grocerymate.service
        echo "Restarting Gunicorn service..."
        sudo systemctl daemon-reload
        sudo systemctl restart grocerymate.service
        sudo systemctl status grocerymate.service --no-pager

        echo "Checking Gunicorn error logs for debugging..."
        cat /home/ec2-user/backend/logs/grocerymate_error.log
        echo "Checking Gunicorn debug logs for debugging..."
        cat /home/ec2-user/backend/logs/grocerymate_debug.log

        echo "Ensuring Nginx is installed on $IP..."
        if ! command -v nginx >/dev/null 2>&1; then
            echo "Nginx is not installed. Installing Nginx..."
            sudo yum install -y nginx || exit 1
            sudo systemctl enable nginx || exit 1
            sudo systemctl start nginx || exit 1
            echo "Nginx installed and started."
        else
            echo "Nginx is already installed."
        fi

        echo "Checking if Nginx configuration file exists..."
        if [ ! -f "/etc/nginx/nginx.conf" ]; then
            echo "Nginx configuration file does not exist. Creating /etc/nginx/nginx.conf using vi..."
            sudo mkdir -p /etc/nginx
            sudo vi /etc/nginx/nginx.conf << 'NGINX_EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format  main  "$remote_addr - $remote_user [$time_local] \"$request\" "
                      "$status $body_bytes_sent \"$http_referer\" "
                      "\"$http_user_agent\" \"$http_x_forwarded_for\"";

    access_log  /var/log/nginx/access.log  main;
    sendfile            on;
    tcp_nopush          on;
    keepalive_timeout   65;
    types_hash_max_size 4096;
    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    server {
        listen 80 default_server;
        server_name _;
        root /var/www/html/build;
        index index.html index.htm;

        location / {
            try_files $uri $uri/ /index.html;
        }

        location /static/ {
            root /var/www/html/build;
            try_files $uri $uri/ =404;
            expires max;
            access_log off;
        }

        location /api/ {
            proxy_pass http://localhost:8000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
NGINX_EOF
            sudo chmod 644 /etc/nginx/nginx.conf
            echo "Nginx configuration file created with correct permissions."
        else
            echo "Nginx configuration file already exists. Updating configuration..."
            sudo bash -c 'cat > /etc/nginx/nginx.conf << "NGINX_EOF"
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format  main  "$remote_addr - $remote_user [$time_local] \"$request\" "
                      "$status $body_bytes_sent \"$http_referer\" "
                      "\"$http_user_agent\" \"$http_x_forwarded_for\"";

    access_log  /var/log/nginx/access.log  main;
    sendfile            on;
    tcp_nopush          on;
    keepalive_timeout   65;
    types_hash_max_size 4096;
    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    server {
        listen 80 default_server;
        server_name _;
        root /var/www/html/build;
        index index.html index.htm;

        location / {
            try_files $uri $uri/ /index.html;
        }

        location /static/ {
            root /var/www/html/build;
            try_files $uri $uri/ =404;
            expires max;
            access_log off;
        }

        location /api/ {
            proxy_pass http://localhost:8000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
NGINX_EOF'
            sudo chmod 644 /etc/nginx/nginx.conf
            echo "Nginx configuration updated with correct permissions."
        fi

        echo "Fetching and deploying frontend assets from S3..."
        sudo mkdir -p /var/www/html
        aws s3 cp s3://grocerymate-app-bucket/frontend-build.tar.gz /tmp/frontend-build.tar.gz
        sudo tar -xzf /tmp/frontend-build.tar.gz -C /var/www/html/
        sudo chown -R nginx:nginx /var/www/html/build
        sudo chmod -R 755 /var/www/html/build
        rm -f /tmp/frontend-build.tar.gz
        sleep 5  # Wait 5 seconds to ensure files are ready

        echo "Restarting Nginx to clear cache..."
        sudo systemctl restart nginx
        sudo nginx -s reload  # Force reload to clear cache
        sudo systemctl status nginx --no-pager

        echo "Testing Nginx port 80..."
        sudo netstat -tuln | grep :80 || echo "Port 80 not open"

        echo "Testing API endpoints..."
        curl -s http://localhost:8000/api/health || echo "Health check failed"
        echo
        curl -s http://localhost:8000/api/config/ || echo "Config endpoint failed"
        echo
        curl -s http://localhost:8000/api/me/info || echo "Me/info endpoint failed"
        echo
        curl -s http://localhost:8000/api/me/all-users || echo "Me/all-users endpoint failed"
        echo
        PRODUCTS_RESPONSE=$(curl -s http://localhost:8000/api/products/all_products)
        if [ -n "$PRODUCTS_RESPONSE" ] && echo "$PRODUCTS_RESPONSE" | grep -q "category"; then
            echo "Product descriptions exist"
        else
            echo "Products/all_products endpoint failed or no descriptions found"
        fi
        echo
        curl -s http://localhost:8000/api/me/basket || echo "Me/basket endpoint failed"
        echo

        echo "Verifying static assets..."
        echo "Listing contents of /var/www/html/build..."
        ls -l /var/www/html/build
        ls -l /var/www/html/build/static/js
        ls -l /var/www/html/build/static/css
        curl -s -I http://localhost/static/js/main.93144096.js | grep HTTP || echo "Specific JS asset not found"
        echo
        curl -s -I http://localhost/static/css/main.3a49d97d.css | grep HTTP || echo "Specific CSS asset not found"
        echo

        echo "Checking Nginx configuration..."
        cat /etc/nginx/nginx.conf

        echo "Testing external access (from Bastion)..."
        curl -s -I http://$IP || echo "External access to $IP failed"

        echo "✅ Deployment completed for $IP"
EOF
done

# Step 3: Update the frontend to fix the products endpoint
log "Updating frontend to fix the products endpoint..."
cd "$FRONTEND_DIR" || handle_error "Failed to change directory to $FRONTEND_DIR"

log "Searching for the file containing the products/all endpoint..."
PRODUCTS_FILE=$(grep -rl "products/all" src/) || log "No file found containing 'products/all', proceeding without update"
if [ -n "$PRODUCTS_FILE" ]; then
    log "Found file to update: $PRODUCTS_FILE"
    log "Updating $PRODUCTS_FILE to use /api/products/all_products..."
    sed -i '' 's|products/all|products/all_products|g' "$PRODUCTS_FILE" || handle_error "Failed to update $PRODUCTS_FILE"
else
    log "No update needed for products/all endpoint."
fi

# Rebuild and redeploy the frontend
log "Rebuilding and redeploying the frontend..."
npm install || handle_error "Failed to run npm install"
npm run build || handle_error "Failed to run npm run build"

JS_FILE=$(find "$FRONTEND_DIR/build/static/js" -name "main.*.js" | head -n 1 | xargs basename)
CSS_FILE=$(find "$FRONTEND_DIR/build/static/css" -name "main.*.css" | head -n 1 | xargs basename)
if [ -z "$JS_FILE" ] || [ -z "$CSS_FILE" ]; then
    handle_error "Failed to detect static assets in $FRONTEND_DIR/build/static"
fi
log "Detected static assets: JS=$JS_FILE, CSS=$CSS_FILE"

tar -czf frontend-build.tar.gz -C "$FRONTEND_DIR" build || handle_error "Failed to create frontend-build.tar.gz"
aws s3 cp frontend-build.tar.gz "s3://$S3_BUCKET/frontend-build.tar.gz" --region "$REGION" || handle_error "Failed to upload frontend-build.tar.gz to S3"
log "Waiting for S3 upload to propagate..."
sleep 10  # Wait 10 seconds to ensure S3 consistency

# Verify instances after deployment
log "Fetching updated instances in ASG $ASG_NAME after deployment..."
aws ec2 describe-instances --region "$REGION" --filters "Name=tag:aws:autoscaling:groupName,Values=$ASG_NAME" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,State.Name]" --output table | tee -a "$LOG_FILE"

# Deployment completion message
log "🎉 All instances updated successfully, frontend redeployed, and JWT_SECRET_KEY secured."
log "Please manually verify the application in the browser:"
log "- Open http://grocerymate-alb-1936728233.eu-central-1.elb.amazonaws.com or http://my-tennistrainer-24.de in a browser."
log "- Open the browser’s developer tools (F12 or Ctrl+Shift+I)."
log "- Go to the 'Network' tab, filter by 'JS' and 'CSS', and confirm the assets (e.g., $JS_FILE) are loading with a 200 OK status."
log "- Go to the 'Console' tab and check for any remaining errors."
log "- Report any errors or issues observed."

# Wait 5 minutes after showing the link
log "Waiting 5 minutes to allow manual verification of the website..."
sleep 300

# Cleanup
log "Cleaning up temporary files..."
rm -f /tmp/__init__.py
rm -f "$FRONTEND_DIR/frontend-build.tar.gz"

log "Script completed."