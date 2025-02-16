# 🛠️ Troubleshooting Terraform Setup

## 1️⃣ Problem: Expired Security Token  
### ❌ Issue:
When trying to assume the Terraform Execution Role, the following error appeared:

```
An error occurred (ExpiredToken) when calling the CreateRole operation: The security token included in the request is expired
```

### ✅ Solution:
- **Fix**: Re-authenticate with AWS SSO to get a new session token (start a new session in the terminal).
```bash
aws sso login --profile 324037288022_AdministratorAccess
```
- **Verify the session**:
```bash
aws sts get-caller-identity
```
Response:
```
-------------------------------------------------------------------------------------------------------------------------
|                                                   GetCallerIdentity                                                   |
+---------+-------------------------------------------------------------------------------------------------------------+
|  Account|  324037288022                                                                                               |
|  Arn    |  arn:aws:sts::324037288022:assumed-role/AWSReservedSSO_AdministratorAccess_85c7c2077ee14413/DanielSiebert   |
|  UserId |  AROAUW4RAUBLOIP7EC2NB:DanielSiebert                                                                        |
+---------+-------------------------------------------------------------------------------------------------------------+
```
- **Re-assume the role**:
```bash
aws sts assume-role --role-arn "arn:aws:iam::324037288022:role/TerraformExecutionRole" --role-session-name "TerraformSession"
```
This generates new credentials that must be exported.

## 2️⃣ Problem: IAM Role Trust Policy Was Incorrect  
### ❌ Issue:
Attempting to assume the role failed with:
```
An error occurred (AccessDenied) when calling the AssumeRole operation: User is not authorized to perform: sts:AssumeRole
```

### ✅ Solution:
**Fixed Trusted Policy inside AWS in IAM Roles > TerraformExecutionRole and EDIT TRUST POLICY:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::324037288022:root"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```
After editing in the AWS Console, update it using:
```bash
aws iam update-assume-role-policy --role-name TerraformExecutionRole --policy-document file://trust-policy.json
```

- **Export new credentials**:
```bash
export AWS_ACCESS_KEY_ID="ASIAUW4RAUBLA6FEASWI"
export AWS_SECRET_ACCESS_KEY="axf5/llqNsv3L2x0rF11E4qOv6tPEwyrULBviz2Y"
export AWS_SESSION_TOKEN="IQoJb3JpZ2luX2Vj..."
```

- **Verify the new role:**
```bash
aws sts get-caller-identity
```
Expected output should show TerraformExecutionRole.

## 3️⃣ Problem: S3 Bucket for Terraform Backend Did Not Exist  
### ✅ Solution:
Manually create the S3 bucket:
```bash
aws s3api create-bucket --bucket grocerymate-terraform-state --region eu-central-1 --create-bucket-configuration LocationConstraint=eu-central-1
```

- Verify it exists:
```bash
aws s3 ls | grep grocerymate-terraform-state
```

## 4️⃣ Problem: DynamoDB Lock Table Was Missing  
### ❌ Issue:
Terraform's remote backend configuration **requires a lock table**, but it was missing.

### ✅ Solution:
- Create the table manually:
```bash
aws dynamodb create-table     --table-name terraform-lock     --attribute-definitions AttributeName=LockID,AttributeType=S     --key-schema AttributeName=LockID,KeyType=HASH     --billing-mode PAY_PER_REQUEST     --region eu-central-1
```

- Verify it exists:
```bash
aws dynamodb list-tables | grep terraform-lock
```
