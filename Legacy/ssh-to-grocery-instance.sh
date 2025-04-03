#!/bin/bash

# Script to SSH into running instances in the grocery-asg Auto Scaling Group

REGION="eu-central-1"
ASG_NAME="grocery-asg"
BASTION_USER="ec2-user"
BASTION_IP="35.158.32.94"
KEY_PATH="~/.ssh/id_rsa"

# Fetch the private IP addresses of running instances in the ASG
INSTANCE_IPS=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:aws:autoscaling:groupName,Values=$ASG_NAME" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].PrivateIpAddress" \
    --output text)

if [ -z "$INSTANCE_IPS" ]; then
    echo "No running instances found in ASG $ASG_NAME"
    exit 1
fi

# Convert the tab-separated list of IPs into an array
IFS=$'\t' read -r -a IPS_ARRAY <<< "$INSTANCE_IPS"

# Display the list of IPs and let the user choose
echo "Found the following running instances in ASG $ASG_NAME:"
for i in "${!IPS_ARRAY[@]}"; do
    echo "[$i] ${IPS_ARRAY[$i]}"
done

# Prompt the user to select an instance
read -p "Enter the number of the instance to SSH into: " INDEX

if [[ ! "$INDEX" =~ ^[0-9]+$ ]] || [ "$INDEX" -ge "${#IPS_ARRAY[@]}" ]; then
    echo "Invalid selection"
    exit 1
fi

SELECTED_IP=${IPS_ARRAY[$INDEX]}
echo "SSHing into instance with IP: $SELECTED_IP"

# SSH into the selected instance via the bastion host
ssh -i "$KEY_PATH" -J "$BASTION_USER@$BASTION_IP" "$BASTION_USER@$SELECTED_IP"