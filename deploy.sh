#!/bin/bash
set -e

ROOT_DIRECTORY="/Users/siebert/Documents"
AWS_GROCERY_DIR="$ROOT_DIRECTORY/AWS_grocery"

echo "Step 1: Ensuring script runs from AWS_grocery directory..."
cd "$AWS_GROCERY_DIR" || { echo "Error: Failed to change directory to $AWS_GROCERY_DIR"; exit 1; }
echo "Step 1: Directory change complete."

echo "Step 2: Authenticating with AWS..."
/Users/siebert/bin/aws-auth.sh || { echo "Error: AWS authentication failed"; exit 1; }
echo "Step 2: AWS authentication complete."

echo "Step 3: Dynamically fetching Bastion IP..."
BASTION_INSTANCE_ID=$(aws ec2 describe-instances --region eu-central-1 --filters "Name=tag:Name,Values=BastionHost" --query "Reservations[*].Instances[*].[InstanceId]" --output text --max-items 1) || { echo "Error: AWS CLI failed to fetch Bastion instance ID"; exit 1; }
if [ -z "$BASTION_INSTANCE_ID" ]; then
  echo "Error: Could not find Bastion instance with tag Name=BastionHost"
  exit 1
fi
BASTION_IP=$(aws ec2 describe-instances --region eu-central-1 --instance-ids "$BASTION_INSTANCE_ID" --query "Reservations[*].Instances[*].[PublicIpAddress]" --output text) || { echo "Error: AWS CLI failed to fetch Bastion IP"; exit 1; }
if [ -z "$BASTION_IP" ]; then
  echo "Error: Could not fetch Bastion IP for instance $BASTION_INSTANCE_ID"
  exit 1
fi
echo "Step 3: Bastion IP fetched: $BASTION_IP (Instance ID: $BASTION_INSTANCE_ID)"

echo "Step 4: Setting variables in terraform.tfvars..."
cd infrastructure || { echo "Error: Failed to change directory to infrastructure"; exit 1; }
DB_ARN=$(aws rds describe-db-instances --region eu-central-1 --query "DBInstances[?DBInstanceIdentifier=='grocerymate'].DBInstanceArn" --output text 2>/dev/null || echo "arn:aws:rds:eu-central-1:324037288022:db:grocerymate")
DB_SECRET_ARN=$(aws secretsmanager describe-secret --secret-id grocerymate-db-credentials --region eu-central-1 --query ARN --output text 2>/dev/null || echo "arn:aws:secretsmanager:eu-central-1:324037288022:secret:grocerymate-db-credentials-rFVLQ4")
cat << EOT2 > terraform.tfvars.tmp
ami = "ami-0adc89df9108a6d24"
db_arn = "$DB_ARN"
db_identifier = "grocerymate"
db_credentials_secret_name = "grocerymate-db-credentials"
db_credentials_secret_arn = "$DB_SECRET_ARN"
instance_name = "grocerymate-ec2"
EOT2
if [ -f terraform.tfvars ]; then
  cp terraform.tfvars terraform.tfvars.bak
  grep -v -E '^(ami|db_arn|db_identifier|db_credentials_secret_name|db_credentials_secret_arn|instance_name)\s*=' terraform.tfvars > terraform.tfvars.tmp2 || true
  cat terraform.tfvars.tmp >> terraform.tfvars.tmp2
  mv terraform.tfvars.tmp2 terraform.tfvars
  rm terraform.tfvars.tmp
else
  mv terraform.tfvars.tmp terraform.tfvars
fi
echo "Step 4: Variables set in terraform.tfvars."

echo "Step 5: Cleaning up ALB listener..."
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn arn:aws:elasticloadbalancing:eu-central-1:324037288022:loadbalancer/app/grocerymate-alb/fdb4aa76d655811b --region eu-central-1 --query "Listeners[?Port==\`80\`].ListenerArn" --output text 2>/dev/null) || { echo "Error: Failed to query ALB listeners"; exit 1; }
if [ -n "$LISTENER_ARN" ]; then
  echo "Deleting existing listener: $LISTENER_ARN"
  aws elbv2 delete-listener --listener-arn "$LISTENER_ARN" --region eu-central-1 || { echo "Error: Failed to delete listener $LISTENER_ARN"; exit 1; }
  echo "Waiting 30 seconds for listener deletion to complete..."
  sleep 30
fi
echo "Skipping target group deletion to maintain ASG attachment."
echo "Step 5: ALB cleanup complete."

echo "Step 6: Starting or recreating RDS instance..."
RDS_STATUS=$(aws rds describe-db-instances --region eu-central-1 --query "DBInstances[?DBInstanceIdentifier=='grocerymate'].DBInstanceStatus" --output text 2>/dev/null || echo "not_found")
if [ "$RDS_STATUS" = "not_found" ]; then
  echo "RDS instance not found with identifier 'grocerymate'. Will recreate with Terraform..."
elif [ "$RDS_STATUS" = "stopped" ]; then
  echo "RDS instance (grocerymate) is stopped. Starting it..."
  aws rds start-db-instance --db-instance-identifier "grocerymate" --region eu-central-1 || { echo "Error: Failed to start RDS instance"; exit 1; }
  echo "Waiting for RDS to become available..."
  until [ "$(aws rds describe-db-instances --region eu-central-1 --db-instance-identifier "grocerymate" --query "DBInstances[0].DBInstanceStatus" --output text 2>/dev/null)" = "available" ]; do
    echo "RDS status: $(aws rds describe-db-instances --region eu-central-1 --db-instance-identifier "grocerymate" --query "DBInstances[0].DBInstanceStatus" --output text 2>/dev/null || echo "unknown")"
    sleep 30
  done
else
  echo "RDS instance (grocerymate) is already running or in state: $RDS_STATUS. Proceeding..."
fi
echo "Step 6: RDS setup complete."

echo "Step 7: Applying Terraform updates..."
terraform init || { echo "Error: Terraform init failed"; exit 1; }
if ! terraform plan -detailed-exitcode | grep -q "No changes"; then
  terraform apply -auto-approve || { echo "Error: Terraform apply failed"; exit 1; }
else
  echo "No changes detected in Terraform plan. Skipping apply."
fi
echo "Step 7: Terraform updates complete."

echo "Step 7.5: Updating grocerymate.service on instances..."
# Fetch GroceryASG instance IPs
INSTANCE_IPS=$(aws ec2 describe-instances --region eu-central-1 --filters "Name=tag:aws:autoscaling:groupName,Values=grocery-asg" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text) || { echo "Error: Failed to fetch GroceryASG instance IPs"; exit 1; }
if [ -z "$INSTANCE_IPS" ]; then
  echo "Error: No running instances found in GroceryASG"
  exit 1
fi
for IP in $INSTANCE_IPS; do
  echo "Updating grocerymate.service on instance $IP..."
  ssh -i ~/.ssh/id_rsa -o BatchMode=yes -J ec2-user@"$BASTION_IP" ec2-user@"$IP" << 'EOT3'
    echo "Removing hardcoded credentials from grocerymate.service..."
    sudo sed -i '/Environment="DB_USER=/d' /etc/systemd/system/grocerymate.service || { echo "Error: Failed to remove DB_USER"; exit 1; }
    sudo sed -i '/Environment="DB_PASS=/d' /etc/systemd/system/grocerymate.service || { echo "Error: Failed to remove DB_PASS"; exit 1; }
    sudo systemctl daemon-reload || { echo "Error: Failed to reload systemd"; exit 1; }
    sudo systemctl restart grocerymate.service || { echo "Error: Failed to restart grocerymate.service"; exit 1; }
    sleep 5
    sudo systemctl status grocerymate.service || { echo "Error: Failed to check service status"; exit 1; }
EOT3
  if [ $? -ne 0 ]; then
    echo "Error: Failed to update grocerymate.service on instance $IP"
    exit 1
  fi
done
echo "Step 7.5: grocerymate.service updated on all instances."

echo "Step 8: Populating RDS database via Bastion..."
# Download the CA certificate
wget -q https://truststore.pki.rds.amazonaws.com/eu-central-1/eu-central-1-bundle.pem -O /tmp/rds-ca.pem || { echo "Error: Failed to download RDS CA certificate"; exit 1; }
scp -i ~/.ssh/id_rsa -o BatchMode=yes /tmp/rds-ca.pem ec2-user@"$BASTION_IP":~/rds-ca.pem || { echo "Error: SCP of CA certificate to Bastion failed"; exit 1; }
scp -i ~/.ssh/id_rsa -o BatchMode=yes ../backend/app/postgres_dump.sql ec2-user@"$BASTION_IP":~ || { echo "Error: SCP to Bastion failed"; exit 1; }
ssh -i ~/.ssh/id_rsa -o BatchMode=yes ec2-user@"$BASTION_IP" << 'EOT2'
  echo "Installing PostgreSQL on Bastion..."
  sudo yum install -y postgresql15 || { echo "Error: Failed to install postgresql15"; exit 1; }
  echo "Fetching RDS credentials from Secrets Manager..."
  SECRET=$(aws secretsmanager get-secret-value --secret-id arn:aws:secretsmanager:eu-central-1:324037288022:secret:grocerymate-db-credentials-rFVLQ4 --region eu-central-1 --query SecretString --output text) || { echo "Error: Failed to fetch RDS credentials"; exit 1; }
  PGUSER=$(echo $SECRET | jq -r '.username') || { echo "Error: Failed to parse username from secret"; exit 1; }
  PGPASSWORD=$(echo $SECRET | jq -r '.password') || { echo "Error: Failed to parse password from secret"; exit 1; }
  export PGUSER
  export PGPASSWORD
  export PGHOST="grocerymate.cp6kci4uaepj.eu-central-1.rds.amazonaws.com"
  export PGDATABASE="grocerymate"
  echo "Dropping existing tables if they exist..."
  psql --set=sslmode=verify-ca --set=sslrootcert=/home/ec2-user/rds-ca.pem << 'EOSQL'
    DROP TABLE IF EXISTS basket_items CASCADE;
    DROP TABLE IF EXISTS products CASCADE;
    DROP TABLE IF EXISTS users CASCADE;
    DROP TABLE IF EXISTS reviews CASCADE;
EOSQL
  if [ $? -ne 0 ]; then
    echo "Error: Failed to drop existing tables."
    exit 1
  fi
  echo "Populating RDS database..."
  psql -f postgres_dump.sql --set=sslmode=verify-ca --set=sslrootcert=/home/ec2-user/rds-ca.pem || { echo "Error: Failed to populate RDS database"; exit 1; }
  echo "Verifying RDS population..."
  psql -c "SELECT COUNT(*) FROM users;" --set=sslmode=verify-ca --set=sslrootcert=/home/ec2-user/rds-ca.pem || { echo "Error: Failed to verify users table"; exit 1; }
  psql -c "SELECT COUNT(*) FROM products;" --set=sslmode=verify-ca --set=sslrootcert=/home/ec2-user/rds-ca.pem || { echo "Error: Failed to verify products table"; exit 1; }
  psql -c "SELECT COUNT(*) FROM basket_items;" --set=sslmode=verify-ca --set=sslrootcert=/home/ec2-user/rds-ca.pem || { echo "Error: Failed to verify basket_items table"; exit 1; }
  psql -c "SELECT COUNT(*) FROM reviews;" --set=sslmode=verify-ca --set=sslrootcert=/home/ec2-user/rds-ca.pem || { echo "Error: Failed to verify reviews table"; exit 1; }
  rm -f /home/ec2-user/rds-ca.pem  # Clean up CA certificate
EOT2
if [ $? -ne 0 ]; then
  echo "Error: Step 8 failed during RDS population or verification."
  exit 1
fi
rm -f /tmp/rds-ca.pem  # Clean up local CA certificate
echo "Step 8: RDS database populated via Bastion."

echo "Step 9: Uploading avatar images to S3..."
rm -rf assets
mkdir -p assets
cp ../backend/avatar/*.png assets/ 2>/dev/null || true
aws s3 cp assets/ s3://grocerymate-avatars-324037288022/avatars/ --recursive || { echo "Error: S3 upload to grocerymate-avatars-324037288022 failed"; exit 1; }
echo "Step 9: Avatar images uploaded to S3."

echo "Step 10: Packaging and uploading backend and frontend to S3..."
cd ..
if [ ! -f backend/app/__init__.py ]; then
  echo "Error: backend/app/__init__.py not found"
  exit 1
fi
tar -czf infrastructure/backend.tar.gz backend || { echo "Error: Failed to package backend"; exit 1; }
tar -czf infrastructure/frontend.tar.gz frontend || { echo "Error: Failed to package frontend"; exit 1; }
cd infrastructure
aws s3 cp backend.tar.gz s3://grocerymate-app-bucket/ || { echo "Error: S3 upload of backend failed"; exit 1; }
aws s3 cp frontend.tar.gz s3://grocerymate-app-bucket/ || { echo "Error: S3 upload of frontend failed"; exit 1; }
echo "Step 10: Backend and frontend packaged and uploaded to S3."

echo "Step 11: Triggering instance refresh..."
REFRESH_ID=$(aws autoscaling start-instance-refresh --auto-scaling-group-name grocery-asg --region eu-central-1 --query "InstanceRefreshId" --output text) || { echo "Error: Failed to start instance refresh"; exit 1; }
echo "Waiting for instance refresh to complete..."
while true; do
  STATUS=$(aws autoscaling describe-instance-refreshes --auto-scaling-group-name grocery-asg --instance-refresh-ids "$REFRESH_ID" --region eu-central-1 --query "InstanceRefreshes[0].Status" --output text) || { echo "Error: Failed to check instance refresh status"; exit 1; }
  echo "Instance refresh status: $STATUS"
  if [ "$STATUS" = "Successful" ]; then
    echo "Instance refresh completed successfully."
    break
  elif [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Cancelling" ] || [ "$STATUS" = "Cancelled" ]; then
    echo "Error: Instance refresh failed or was cancelled: $STATUS"
    exit 1
  fi
  sleep 30
done
echo "Step 11: Instance refresh complete."

echo "Step 12: Verifying deployment..."
ALB_DNS=$(terraform output -raw alb_dns_name) || { echo "Error: Failed to get ALB DNS"; exit 1; }
echo "Checking target health..."
HEALTH_STATUS=$(aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:eu-central-1:324037288022:targetgroup/grocerymate-target-group/0d6a977f46009f87 --region eu-central-1 --query "TargetHealthDescriptions[*].TargetHealth.State" --output text) || { echo "Error: Failed to check target health"; exit 1; }
echo "Target health states: $HEALTH_STATUS"
if echo "$HEALTH_STATUS" | grep -q "unhealthy"; then
  echo "Error: Some targets are unhealthy"
  exit 1
fi
echo "Testing frontend..."
FRONTEND_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://my-tennistrainer-24.de/) || { echo "Error: Frontend test failed"; exit 1; }
if [ "$FRONTEND_RESPONSE" != "200" ]; then
  echo "Error: Frontend returned HTTP status $FRONTEND_RESPONSE, expected 200"
  exit 1
fi
echo "Testing backend API..."
HEALTH_RESPONSE=$(curl -s http://my-tennistrainer-24.de/api/health) || { echo "Error: Backend API test failed"; exit 1; }
if ! echo "$HEALTH_RESPONSE" | grep -q '"status":"ok"'; then
  echo "Error: Backend API health check failed: $HEALTH_RESPONSE"
  exit 1
fi
echo "Step 12: Verification complete."

echo "Step 13: Outputting ALB DNS..."
echo "Website live at: http://$ALB_DNS"
echo "Also accessible at: http://my-tennistrainer-24.de"
echo "Step 13: ALB DNS output complete."

echo "Deploy.sh execution complete!"