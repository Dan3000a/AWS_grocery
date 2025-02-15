📌 Updated Plan: Week-by-Week AWS Infrastructure Deployment (Including ALB & ASG)

✅ Week 1: Core Infrastructure (VPC, EC2, RDS, Security Groups)

🔹 Goals
	•	Set up a networking environment (VPC, subnets, and route tables).
	•	Create security groups to define access rules.
	•	Deploy an EC2 instance in a private subnet.
	•	Deploy an RDS PostgreSQL database in a private subnet.

🛠️ Tasks

1️⃣ Create a Virtual Private Cloud (VPC)
	•	Define a VPC CIDR block.
	•	Create two public subnets and two private subnets.
	•	Deploy an Internet Gateway (IGW) for public subnets.
	•	Set up route tables to control traffic.

2️⃣ Create Security Groups
	•	EC2 Security Group:
	•	Allow SSH (port 22) access only from a specific IP.
	•	Allow HTTP (port 80) access from anywhere.
	•	RDS Security Group:
	•	Allow PostgreSQL (port 5432) traffic only from EC2.

3️⃣ Deploy an EC2 Web Server in a Private Subnet
	•	Launch an EC2 instance in a private subnet.
	•	Use user_data to install Docker & dependencies.
	•	Attach a security group to control inbound/outbound access.

4️⃣ Deploy an RDS PostgreSQL Database in a Private Subnet
	•	Create an RDS instance (PostgreSQL).
	•	Deploy in a private subnet (not publicly accessible).
	•	Ensure EC2 can connect to RDS.

✅ Week 2: S3 & File Storage

🔹 Goals
	•	Deploy S3 storage for storing avatars/files.
	•	Modify the application to retrieve avatars from S3.
	•	Set up IAM permissions to allow EC2 to access S3.

🛠️ Tasks

1️⃣ Deploy an S3 Bucket
	•	Define an S3 bucket using Terraform.
	•	Configure access permissions (e.g., public/private access).
	•	Set up lifecycle policies if needed.

2️⃣ Upload Content to S3 via AWS CLI
	•	Use AWS CLI to upload avatars/images.
	•	Verify access and permissions.

3️⃣ Modify the Application to Use S3
	•	Change the app to pull avatars from S3 instead of local storage.
	•	Test the integration.

✅ Week 3: IAM & Scaling

🔹 Goals
	•	Define IAM Roles & Policies for access control.
	•	Attach IAM roles to EC2, allowing it to access S3 & RDS.
	•	Prepare for Auto Scaling by ensuring permissions are set.

🛠️ Tasks

1️⃣ Create IAM Roles & Policies
	•	Define an IAM role for EC2 to access S3 & RDS.
	•	Attach necessary IAM policies.

2️⃣ Attach IAM Role to EC2
	•	Update Terraform to attach the IAM role to EC2.
	•	Verify access by running AWS CLI commands from the instance.

✅ Week 4: Application Load Balancer & Auto Scaling

🔹 Goals
	•	Deploy an Application Load Balancer (ALB) to handle traffic.
	•	Set up an Auto Scaling Group (ASG) to dynamically adjust the number of instances.
	•	Implement health checks to replace unhealthy instances.

🛠️ Tasks

1️⃣ Deploy an Application Load Balancer (ALB)
	•	Create an ALB with a listener on port 80.
	•	Attach a security group to control traffic.
	•	Register EC2 instances in a target group.

2️⃣ Create an Auto Scaling Group (ASG)
	•	Define an ASG with a launch template.
	•	Configure min, max, and desired instance counts.
	•	Attach the ASG to the ALB target group.

3️⃣ Enable Health Checks
	•	Ensure ALB removes unhealthy instances.
	•	Configure ASG to replace failed instances automatically.

🚀 Let’s Start: Week 1

The first step is VPC, Security Groups, EC2, and RDS.

✅ Shall we create the Terraform modules and files for this first, or do you want to work directly within the existing infrastructure folder? 🚀