user_data = base64encode(<<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/null) 2>&1

yum update -y
yum install -y python3 python3-pip nginx

# Create web directory with proper permissions
mkdir -p /var/www/html
chown ec2-user:ec2-user /var/www/html
chmod 755 /var/www/html

# Ensure writable temp directory for frontend
mkdir -p /tmp/frontend_temp_extract
chown ec2-user:ec2-user /tmp/frontend_temp_extract

# Download and extract backend
echo "Downloading backend.tar.gz..."
aws s3 cp s3://grocerymate-app-bucket/backend.tar.gz /home/ec2-user/ || { echo "Failed to download backend.tar.gz"; exit 1; }
echo "Extracting backend.tar.gz..."
tar -xzf /home/ec2-user/backend.tar.gz -C /home/ec2-user/ || { echo "Failed to extract backend.tar.gz"; ls -la /home/ec2-user/; exit 1; }
cd /home/ec2-user/backend

# Download and extract pre-built frontend
echo "Downloading frontend-build.tar.gz..."
aws s3 cp s3://grocerymate-app-bucket/frontend-build.tar.gz /home/ec2-user/ || { echo "Failed to download frontend-build.tar.gz"; exit 1; }
echo "Extracting frontend-build.tar.gz..."
tar -xzf /home/ec2-user/frontend-build.tar.gz -C /var/www/html/ || { echo "Failed to extract frontend-build.tar.gz"; ls -la /var/www/html/; exit 1; }

# Replace the backend URL placeholder in index.html
sed -i 's|{{ backend_url }}|http://grocerymate-alb-1936728233.eu-central-1.elb.amazonaws.com|g' /var/www/html/build/index.html

# Create and activate virtual environment
echo "Creating virtual environment..."
python3 -m venv /home/ec2-user/backend/venv --clear
chown -R ec2-user:ec2-user /home/ec2-user/backend/venv
source /home/ec2-user/backend/venv/bin/activate
echo "Upgrading pip..."
pip install --upgrade pip || { echo "Pip upgrade failed"; exit 1; }
echo "Installing dependencies..."
pip install -r /home/ec2-user/backend/requirements.txt || { echo "Pip install failed, retrying with sudo..."; sudo -u ec2-user pip install -r /home/ec2-user/backend/requirements.txt --ignore-installed requests || { echo "Final install attempt failed"; exit 1; } }
deactivate

# Download RDS CA certificate
echo "Downloading RDS CA certificate..."
curl -s -o /home/ec2-user/rds-ca.pem https://truststore.pki.rds.amazonaws.com/eu-central-1/eu-central-1-bundle.pem
chown ec2-user:ec2-user /home/ec2-user/rds-ca.pem

# Create logs directory and files
mkdir -p /home/ec2-user/backend/logs
touch /home/ec2-user/backend/logs/grocerymate.log
touch /home/ec2-user/backend/logs/grocerymate_error.log
chown ec2-user:ec2-user /home/ec2-user/backend/logs/grocerymate.log
chown ec2-user:ec2-user /home/ec2-user/backend/logs/grocerymate_error.log
chmod 644 /home/ec2-user/backend/logs/grocerymate.log
chmod 644 /home/ec2-user/backend/logs/grocerymate_error.log

# Configure systemd service for backend (without hardcoded credentials)
cat << EOT > /etc/systemd/system/grocerymate.service
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
EOT

# Configure Nginx to serve frontend and proxy to backend
cat << EOT > /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    server {
        listen 80 default_server;
        server_name _;

        root /var/www/html/build;
        index index.html index.htm;

        location / {
            try_files \$uri \$uri/ /index.html;
        }

        location /static/ {
            alias /var/www/html/build/static/;
            try_files \$uri \$uri/ =404;
        }

        location /api/ {
            proxy_pass http://localhost:8000;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOT

# Start and enable services
systemctl enable grocerymate.service
systemctl start grocerymate.service
systemctl enable nginx
systemctl start nginx
EOF
)

tags = {
  Name = "GroceryAppLaunchTemplate"
}
}