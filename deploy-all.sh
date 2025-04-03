#!/bin/bash
set -e

# Configuration variables
ROOT_DIRECTORY="/Users/siebert/Documents"
AWS_GROCERY_DIR="$ROOT_DIRECTORY/AWS_grocery"
REGION="eu-central-1"
ASG_NAME="grocery-asg"
BASTION_USER="ec2-user"
KEY_PATH="~/.ssh/id_rsa"
LOG_FILE="$AWS_GROCERY_DIR/deployment.log"
S3_BUCKET="grocerymate-app-bucket"
FRONTEND_DIR="$AWS_GROCERY_DIR/frontend"
AWS_ACCOUNT_ID="324037288022"
AWS_SSO_PROFILE="324037288022_AdministratorAccess"
TERRAFORM_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/TerraformExecutionRole"
SESSION_NAME="TerraformSession"
STS_DURATION=3600

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

# AWS Authentication function
authenticate_aws() {
    log "Checking AWS authentication..."
    aws sts get-caller-identity &>/dev/null || {
        log "AWS SSO session expired. Logging in..."
        aws sso login --profile "$AWS_SSO_PROFILE" --no-browser || handle_error "SSO login failed. Open https://masterschool.awsapps.com/start/# manually if needed."
        log "SSO login successful. Retrieving credentials..."
    }

    log "Retrieving SSO credentials..."
    ACCESS_TOKEN_FILE=$(ls -t ~/.aws/sso/cache/ | head -n 1)
    [ -f ~/.aws/sso/cache/$ACCESS_TOKEN_FILE ] || handle_error "No SSO token found."
    ACCESS_TOKEN=$(cat ~/.aws/sso/cache/$ACCESS_TOKEN_FILE | jq -r .accessToken)
    [ -n "$ACCESS_TOKEN" ] || handle_error "Failed to retrieve SSO access token."

    ROLE_CREDENTIALS=$(aws sso get-role-credentials --account-id "$AWS_ACCOUNT_ID" --role-name "AdministratorAccess" --access-token "$ACCESS_TOKEN" --output json) || handle_error "Failed to retrieve SSO credentials."
    export AWS_ACCESS_KEY_ID=$(echo "$ROLE_CREDENTIALS" | jq -r '.roleCredentials.accessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$ROLE_CREDENTIALS" | jq -r '.roleCredentials.secretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$ROLE_CREDENTIALS" | jq -r '.roleCredentials.sessionToken')

    log "Assuming Terraform Execution Role..."
    ASSUMED_ROLE=$(aws sts assume-role --role-arn "$TERRAFORM_ROLE_ARN" --role-session-name "$SESSION_NAME" --duration-seconds "$STS_DURATION" --output json) || handle_error "Failed to assume Terraform role."
    export AWS_ACCESS_KEY_ID=$(echo "$ASSUMED_ROLE" | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUMED_ROLE" | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$ASSUMED_ROLE" | jq -r '.Credentials.SessionToken')
    export AWS_SESSION_EXPIRATION=$(echo "$ASSUMED_ROLE" | jq -r '.Credentials.Expiration')

    log "AWS authentication successful."
}

# Main deployment logic
main() {
    log "Starting deployment..."

    # Step 1: Ensure correct directory
    log "Ensuring script runs from AWS_grocery directory..."
    cd "$AWS_GROCERY_DIR" || handle_error "Failed to change directory to $AWS_GROCERY_DIR"

    # Step 2: Authenticate with AWS
    authenticate_aws

    # Step 3: Fetch Bastion IP
    log "Dynamically fetching Bastion IP..."
    BASTION_INSTANCE_ID=$(aws ec2 describe-instances --region "$REGION" --filters "Name=tag:Name,Values=BastionHost" --query "Reservations[*].Instances[*].[InstanceId]" --output text --max-items 1) || handle_error "Failed to fetch Bastion instance ID"
    [ -n "$BASTION_INSTANCE_ID" ] || handle_error "No Bastion instance found with tag Name=BastionHost"
    BASTION_IP=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$BASTION_INSTANCE_ID" --query "Reservations[*].Instances[*].[PublicIpAddress]" --output text) || handle_error "Failed to fetch Bastion IP"
    [ -n "$BASTION_IP" ] || handle_error "Could not fetch Bastion IP for $BASTION_INSTANCE_ID"
    log "Bastion IP fetched: $BASTION_IP (Instance ID: $BASTION_INSTANCE_ID)"

    # Step 3.1: Ensure Nginx is not installed on the Bastion Host
    log "Ensuring Nginx is not installed on the Bastion Host ($BASTION_IP)..."
    ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no "$BASTION_USER@$BASTION_IP" /bin/bash << 'EOF' | tee -a "$LOG_FILE"
        if command -v nginx >/dev/null 2>&1; then
            echo "Nginx is installed on the Bastion Host, which is not required. Removing Nginx..."
            sudo systemctl stop nginx || true
            sudo yum remove -y nginx || true
            sudo rm -rf /etc/nginx || true
            echo "Nginx removed from the Bastion Host."
        else
            echo "Nginx is not installed on the Bastion Host, as expected."
        fi
EOF

    # Step 4: Configure Terraform variables
    log "Setting dynamic variables in terraform.tfvars..."
    cd infrastructure || handle_error "Failed to change to infrastructure directory"
    DB_ARN=$(aws rds describe-db-instances --region "$REGION" --query "DBInstances[?DBInstanceIdentifier=='grocerymate'].DBInstanceArn" --output text 2>/dev/null || echo "arn:aws:rds:$REGION:$AWS_ACCOUNT_ID:db:grocerymate")
    DB_SECRET_ARN=$(aws secretsmanager describe-secret --secret-id grocerymate-db-credentials --region "$REGION" --query ARN --output text 2>/dev/null || echo "arn:aws:secretsmanager:$REGION:$AWS_ACCOUNT_ID:secret:grocerymate-db-credentials-rFVLQ4")

    # Check if terraform.tfvars exists, if not create it with all values
    if [ ! -f terraform.tfvars ]; then
        log "terraform.tfvars does not exist, creating with all values..."
        cat << EOT > terraform.tfvars
ami = "ami-0adc89df9108a6d24"
db_arn = "$DB_ARN"
db_identifier = "grocerymate"
db_credentials_secret_name = "grocerymate-db-credentials"
db_credentials_secret_arn = "$DB_SECRET_ARN"
instance_name = "grocerymate-ec2"
launch_template_id = "lt-083e2148f7457df67"
launch_template_version = "1"
profile = "arn:aws:sts::324037288022:assumed-role/AWSReservedSSO_AdministratorAccess_85c7c2077ee14413/DanielSiebert"
security_group = "sg-0a95162516ad3399f"
subnet_ids = ["subnet-09798ff5a05cb8bb7", "subnet-07a5ef67a7c0e2d58"]
EOT
    else
        log "terraform.tfvars exists, updating only dynamic values..."
        # Update db_arn and db_credentials_secret_arn in terraform.tfvars
        sed -i '' "s|db_arn = \".*\"|db_arn = \"$DB_ARN\"|" terraform.tfvars
        sed -i '' "s|db_credentials_secret_arn = \".*\"|db_credentials_secret_arn = \"$DB_SECRET_ARN\"|" terraform.tfvars
    fi
    log "Terraform variables set."

    # Step 5: Manage RDS instance
    log "Starting or recreating RDS instance..."
    RDS_STATUS=$(aws rds describe-db-instances --region "$REGION" --query "DBInstances[?DBInstanceIdentifier=='grocerymate'].DBInstanceStatus" --output text 2>/dev/null || echo "not_found")
    if [ "$RDS_STATUS" = "not_found" ]; then
        log "RDS instance not found. Will recreate with Terraform..."
    elif [ "$RDS_STATUS" = "stopped" ]; then
        log "RDS instance is stopped. Starting it..."
        aws rds start-db-instance --db-instance-identifier "grocerymate" --region "$REGION" || handle_error "Failed to start RDS"
        until [ "$(aws rds describe-db-instances --region "$REGION" --db-instance-identifier "grocerymate" --query "DBInstances[0].DBInstanceStatus" --output text)" = "available" ]; do
            log "RDS status: $(aws rds describe-db-instances --region "$REGION" --db-instance-identifier "grocerymate" --query "DBInstances[0].DBInstanceStatus" --output text)"
            sleep 30
        done
    else
        log "RDS instance already running or in state: $RDS_STATUS"
    fi

    # Step 6: Apply Terraform updates
    log "Applying Terraform updates..."
    terraform init || handle_error "Terraform init failed"
    log "Terraform init completed successfully."

    # Check for and unlock any existing state lock
    LOCK_INFO=$(terraform state pull 2>&1 | grep "Error acquiring the state lock" || true)
    if echo "$LOCK_INFO" | grep -q "Error acquiring the state lock"; then
        LOCK_ID=$(echo "$LOCK_INFO" | grep "ID:" | awk '{print $2}')
        log "State lock detected with ID: $LOCK_ID. Attempting to unlock..."
        terraform force-unlock "$LOCK_ID" || handle_error "Failed to unlock Terraform state"
    fi

    log "Running terraform plan..."
    terraform plan -detailed-exitcode -out=tfplan 2>&1 | tee /tmp/terraform-plan.log
    PLAN_EXIT_CODE=$?
    log "Terraform plan exit code: $PLAN_EXIT_CODE"
    if [ $PLAN_EXIT_CODE -eq 0 ]; then
        log "No changes detected in Terraform plan. Skipping apply."
    elif [ $PLAN_EXIT_CODE -eq 2 ]; then
        log "Changes detected in Terraform plan. Applying changes..."
        terraform apply -auto-approve tfplan || handle_error "Terraform apply failed"
    else
        log "Terraform plan failed. Check /tmp/terraform-plan.log for details."
        cat /tmp/terraform-plan.log
        handle_error "Terraform plan failed with exit code $PLAN_EXIT_CODE"
    fi

    # Step 7: Update frontend with ALB DNS and patch endpoint
    log "Updating frontend with ALB DNS and patching endpoint..."
    ALB_DNS=$(terraform output -raw alb_dns_name) || handle_error "Failed to get ALB DNS"
    cd "$FRONTEND_DIR" || handle_error "Failed to change to frontend directory"
    PRODUCTS_FILE=$(grep -rl "products/all" src/) || log "No file found with 'products/all'"
    if [ -n "$PRODUCTS_FILE" ]; then
        log "Patching $PRODUCTS_FILE to use /api/products/all_products..."
        sed -i '' 's|products/all|products/all_products|g' "$PRODUCTS_FILE" || handle_error "Failed to patch $PRODUCTS_FILE"
    fi
    npm install && npm run build || handle_error "Frontend build failed"
    sed -i '' "s|{{ backend_url }}|http://$ALB_DNS|g" build/index.html || handle_error "Failed to update ALB DNS in index.html"
    tar -czf frontend-build.tar.gz build || handle_error "Failed to package frontend"
    aws s3 cp frontend-build.tar.gz s3://$S3_BUCKET/frontend-build.tar.gz --region "$REGION" || handle_error "Failed to upload frontend to S3"

    # Step 8: Update instances by calling update-grocery-instances.sh
    log "Updating instances using update-grocery-instances.sh..."
    cd "$AWS_GROCERY_DIR" || handle_error "Failed to change to AWS_grocery directory"
    chmod +x update-grocery-instances.sh
    ./update-grocery-instances.sh || handle_error "Failed to update instances with update-grocery-instances.sh"

    # Step 9: Populate RDS database
    log "Populating RDS database via Bastion..."
    curl -s -o /tmp/rds-ca.pem https://truststore.pki.rds.amazonaws.com/eu-central-1/eu-central-1-bundle.pem || handle_error "Failed to download RDS CA"
    scp -i "$KEY_PATH" -o StrictHostKeyChecking=no /tmp/rds-ca.pem "$BASTION_USER@$BASTION_IP":~/rds-ca.pem || handle_error "Failed to SCP CA to Bastion"
    scp -i "$KEY_PATH" -o StrictHostKeyChecking=no "$AWS_GROCERY_DIR/backend/app/postgres_dump.sql" "$BASTION_USER@$BASTION_IP":~ || handle_error "Failed to SCP SQL dump"
    ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no "$BASTION_USER@$BASTION_IP" << 'EOF'
sudo yum install -y postgresql15
SECRET=$(aws secretsmanager get-secret-value --secret-id grocerymate-db-credentials --region eu-central-1 --query SecretString --output text)
export PGUSER=$(echo $SECRET | jq -r '.username')
export PGPASSWORD=$(echo $SECRET | jq -r '.password')
export PGHOST="grocerymate.cp6kci4uaepj.eu-central-1.rds.amazonaws.com"
export PGDATABASE="grocerymate"
psql -f postgres_dump.sql --set=sslmode=verify-ca --set=sslrootcert=/home/ec2-user/rds-ca.pem || exit 1
rm -f /home/ec2-user/rds-ca.pem
EOF
    [ $? -eq 0 ] || handle_error "Failed to populate RDS database"
    rm -f /tmp/rds-ca.pem

    # Step 10: Upload avatars and backend
    log "Uploading avatars and backend to S3..."
    rm -rf assets && mkdir -p assets
    cp "$AWS_GROCERY_DIR/backend/avatar/"*.png assets/ 2>/dev/null || true
    aws s3 cp assets/ s3://grocerymate-avatars-$AWS_ACCOUNT_ID/avatars/ --recursive --acl public-read --region "$REGION" || handle_error "Failed to upload avatars"
    tar -czf backend.tar.gz -C "$AWS_GROCERY_DIR" backend || handle_error "Failed to package backend"
    aws s3 cp backend.tar.gz s3://$S3_BUCKET/ --region "$REGION" || handle_error "Failed to upload backend"

    # Step 11: Trigger instance refresh
    log "Triggering instance refresh..."
    aws autoscaling describe-instance-refreshes --auto-scaling-group-name "$ASG_NAME" --region "$REGION" --query "InstanceRefreshes[?Status=='InProgress']" --output text | grep -q . || {
        REFRESH_ID=$(aws autoscaling start-instance-refresh --auto-scaling-group-name "$ASG_NAME" --region "$REGION" --query "InstanceRefreshId" --output text) || handle_error "Failed to start instance refresh"
        while true; do
            STATUS=$(aws autoscaling describe-instance-refreshes --auto-scaling-group-name "$ASG_NAME" --instance-refresh-ids "$REFRESH_ID" --region "$REGION" --query "InstanceRefreshes[0].Status" --output text)
            log "Instance refresh status: $STATUS"
            [ "$STATUS" = "Successful" ] && break
            [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Cancelling" ] || [ "$STATUS" = "Cancelled" ] && handle_error "Instance refresh failed: $STATUS"
            sleep 30
        done
    }

    # Step 12: Verify deployment
    log "Verifying deployment..."
    TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --names grocerymate-target-group-v2 --region "$REGION" --query "TargetGroups[0].TargetGroupArn" --output text) || handle_error "Failed to fetch target group ARN"
    HEALTH_STATUS=$(aws elbv2 describe-target-health --target-group-arn "$TARGET_GROUP_ARN" --region "$REGION" --query "TargetHealthDescriptions[*].TargetHealth.State" --output text) || handle_error "Failed to check target health"
    echo "$HEALTH_STATUS" | grep -q "unhealthy" && handle_error "Some targets are unhealthy: $HEALTH_STATUS"
    FRONTEND_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS") || handle_error "Frontend test failed"
    [ "$FRONTEND_RESPONSE" = "200" ] || handle_error "Frontend returned $FRONTEND_RESPONSE, expected 200"
    HEALTH_RESPONSE=$(curl -s "http://$ALB_DNS/api/health") || handle_error "Backend API test failed"
    echo "$HEALTH_RESPONSE" | grep -q '"status":"ok"' || handle_error "Backend API health check failed: $HEALTH_RESPONSE"

    log "Deployment successful!"
    log "Website live at: http://$ALB_DNS"
    log "Also accessible at: http://my-tennistrainer-24.de"
}

# Execute main function
main