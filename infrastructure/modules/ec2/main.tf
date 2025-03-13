# Data source for existing SSH Key Pair
data "aws_key_pair" "existing" {
  key_name = "grocerymate-key"
}

resource "aws_key_pair" "generated" {
  key_name   = "bastion-key"
  public_key = file("~/.ssh/id_rsa.pub") # Ensure you have an SSH key
}

# Data source for existing IAM Instance Profile
data "aws_iam_instance_profile" "existing" {
  name = "grocerymate-ec2-profile"
}

resource "aws_launch_template" "grocery_app" {
  name_prefix   = "grocery-app-"
  image_id      = var.ami
  instance_type = "t2.micro"
  key_name      = var.key_pair_name

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.security_group]
  }

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

    # Create logs directory and files
    mkdir -p /home/ec2-user/backend/logs
    touch /home/ec2-user/backend/logs/grocerymate.log
    touch /home/ec2-user/backend/logs/grocerymate_error.log
    chown ec2-user:ec2-user /home/ec2-user/backend/logs/grocerymate.log
    chown ec2-user:ec2-user /home/ec2-user/backend/logs/grocerymate_error.log
    chmod 644 /home/ec2-user/backend/logs/grocerymate.log
    chmod 644 /home/ec2-user/backend/logs/grocerymate_error.log

    # Set environment variables
    export DB_HOST="grocerymate.cp6kci4uaepj.eu-central-1.rds.amazonaws.com"
    export DB_USER="grocerymate_admin"
    export DB_PASS="%31T2mfoPo?4RUbX"
    export DB_NAME="grocerymate"
    export S3_BUCKET_NAME="grocerymate-avatars"
    export S3_REGION="eu-central-1"
    export USE_S3_STORAGE="true"

    # Configure systemd service for backend
    cat << EOT > /etc/systemd/system/grocerymate.service
    [Unit]
    Description=GroceryMate Application
    After=network.target

    [Service]
    User=ec2-user
    WorkingDirectory=/home/ec2-user/backend
    ExecStart=/home/ec2-user/backend/venv/bin/gunicorn --bind 0.0.0.0:8000 --access-logfile /home/ec2-user/backend/logs/grocerymate.log --error-logfile /home/ec2-user/backend/logs/grocerymate_error.log run:app
    Restart=always
    Environment="DB_HOST=grocerymate.cp6kci4uaepj.eu-central-1.rds.amazonaws.com"
    Environment="DB_USER=grocerymate_admin"
    Environment="DB_PASS=%31T2mfoPo?4RUbX"
    Environment="DB_NAME=grocerymate"
    Environment="S3_BUCKET_NAME=grocerymate-avatars"
    Environment="S3_REGION=eu-central-1"
    Environment="USE_S3_STORAGE=true"
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

            root /var/www/html;
            index index.html index.htm;

            location / {
                try_files \$uri \$uri/ /index.html;
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

resource "aws_instance" "bastion" {
  ami                    = var.ami
  instance_type          = "t3.micro"
  subnet_id              = element(var.public_subnets, 0)
  vpc_security_group_ids = [var.bastion_security_group_id]
  key_name               = aws_key_pair.generated.key_name
  iam_instance_profile   = data.aws_iam_instance_profile.existing.name

  associate_public_ip_address = true # Ensures a public IP

  tags = {
    Name = "BastionHost"
  }
}