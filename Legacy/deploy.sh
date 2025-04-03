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
BASTION_INSTANCE_ID=$(aws ec2 describe-instances --region eu-central-1 --filters "Name=tag:Name,Values=BastionHost" --query "Reservations[*].Instances[*].[InstanceId]" --output text --max-items 1) || { echo "Error: Failed to fetch Bastion instance ID"; exit 1; }
[ -n "$BASTION_INSTANCE_ID" ] || { echo "Error: No Bastion instance found"; exit 1; }
BASTION_IP=$(aws ec2 describe-instances --region eu-central-1 --instance-ids "$BASTION_INSTANCE_ID" --query "Reservations[*].Instances[*].[PublicIpAddress]" --output text) || { echo "Error: Failed to fetch Bastion IP"; exit 1; }
[ -n "$BASTION_IP" ] || { echo "Error: Could not fetch Bastion IP"; exit 1; }
echo "Step 3: Bastion IP fetched: $BASTION_IP"

echo "Step 4: Setting variables in terraform.tfvars..."
cd infrastructure || { echo "Error: Failed to change to infrastructure directory"; exit 1; }
DB_ARN=$(aws rds describe-db-instances --region eu-central-1 --query "DBInstances[?DBInstanceIdentifier=='grocerymate'].DBInstanceArn" --output text 2>/dev/null || echo "arn:aws:rds:eu-central-1:324037288022:db:grocerymate")
DB_SECRET_ARN=$(aws secretsmanager describe-secret --secret-id grocerymate-db-credentials --region eu-central-1 --query ARN --output text 2>/dev/null || echo "arn:aws:secretsmanager:eu-central-1:324037288022:secret:grocerymate-db-credentials-rFVLQ4")
cat << EOT > terraform.tfvars
ami = "ami-0adc89df9108a6d24"
db_arn = "$DB_ARN"
db_identifier = "grocerymate"
db_credentials_secret_name = "grocerymate-db-credentials"
db_credentials_secret_arn = "$DB_SECRET_ARN"
instance_name = "grocerymate-ec2"
launch_template_id = "" # Leer lassen, wenn nicht benötigt
launch_template_version = "" # Leer lassen, wenn nicht benötigt
EOT
echo "Step 4: Variables set in terraform.tfvars."

echo "Step 5: Cleaning up ALB listener..."
ALB_ARN=$(aws elbv2 describe-load-balancers --names grocerymate-alb --region eu-central-1 --query "LoadBalancers[0].LoadBalancerArn" --output text)
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region eu-central-1 --query "Listeners[?Port==\`80\`].ListenerArn" --output text 2>/dev/null)
if [ -n "$LISTENER_ARN" ]; then
    echo "Deleting existing listener: $LISTENER_ARN"
    aws elbv2 delete-listener --listener-arn "$LISTENER_ARN" --region eu-central-1 || { echo "Error: Failed to delete listener"; exit 1; }
    sleep 30
fi
echo "Step 5: ALB cleanup complete."

echo "Step 6: Starting or recreating RDS instance..."
RDS_STATUS=$(aws rds describe-db-instances --region eu-central-1 --query "DBInstances[?DBInstanceIdentifier=='grocerymate'].DBInstanceStatus" --output text 2>/dev/null || echo "not_found")
if [ "$RDS_STATUS" = "not_found" ] || [ "$RDS_STATUS" = "stopped" ]; then
    [ "$RDS_STATUS" = "stopped" ] && aws rds start-db-instance --db-instance-identifier "grocerymate" --region eu-central-1
    until [ "$(aws rds describe-db-instances --region eu-central-1 --db-instance-identifier "grocerymate" --query "DBInstances[0].DBInstanceStatus" --output text 2>/dev/null)" = "available" ]; do
        echo "RDS status: $(aws rds describe-db-instances --region eu-central-1 --db-instance-identifier "grocerymate" --query "DBInstances[0].DBInstanceStatus" --output text)"
        sleep 30
    done
else
    echo "RDS instance already running: $RDS_STATUS"
fi
echo "Step 6: RDS setup complete."

echo "Step 7: Applying Terraform updates..."
terraform init || { echo "Error: Terraform init failed"; exit 1; }
terraform plan -out=tfplan || { echo "Error: Terraform plan failed. Check variables in terraform.tfvars or Terraform code."; exit 1; }
terraform apply tfplan || { echo "Error: Terraform apply failed"; exit 1; }
echo "Step 7: Terraform updates complete."

# Rest des Skripts bleibt gleich (Frontend-Update, Gunicorn, RDS-Population, etc.)
# Hier abgekürzt, um den Fokus auf das Problem zu legen
echo "Step 7.1: Fetching ALB DNS and updating frontend..."
ALB_DNS=$(terraform output -raw alb_dns_name) || { echo "Error: Failed to get ALB DNS"; exit 1; }
cd ../frontend
tar -xzf frontend-build.tar.gz
sed -i '' "s|{{ backend_url }}|http://$ALB_DNS|g" build/index.html
tar -czf frontend-build.tar.gz build
aws s3 cp frontend-build.tar.gz s3://grocerymate-app-bucket/frontend-build.tar.gz --region eu-central-1
cd ../infrastructure
echo "Step 7.1: Frontend updated."

echo "Deploy.sh execution complete!"