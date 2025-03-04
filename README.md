# GroceryMate – AWS Infrastructure Project

## 📌 Project Overview
GroceryMate is an online grocery store application, and this project focuses on building a robust cloud infrastructure to host it on AWS. The infrastructure was developed as **Infrastructure as Code (IaC)** using Terraform, emphasizing **scalability, security, and automation**.

The goal was to create a **highly available** and **secure** environment where the GroceryMate app can run reliably while demonstrating modern **DevOps best practices**. The infrastructure follows a **multi-tier architecture**, including:
- **Web tier** with **Application Load Balancer (ALB)**
- **Auto Scaling Group (ASG)** for dynamic compute resources
- **Private database (RDS PostgreSQL)**
- **Multi-AZ deployment for fault tolerance**
- **Automated provisioning with Terraform**

---

## 🚀 Personal Contributions
As the sole **DevOps Engineer**, I was responsible for **end-to-end** architecture, implementation, and automation. My key contributions include:

### 🏗️ **Cloud Infrastructure Design**
- Designed a **VPC with Public & Private Subnets** across multiple **Availability Zones**.
- Set up **Internet Gateway & NAT Gateway** for internet access in a controlled manner.
- Implemented **tight security group rules** to ensure **least privilege access**.

### 📝 **Terraform Infrastructure as Code**
- Developed **modular Terraform code** for efficient infrastructure management.
- Managed **remote Terraform state** using **S3 backend with DynamoDB locking**.
- Enabled **incremental changes** for smooth updates and rollback.

### 🔄 **Scalability & Reliability**
- Implemented an **Auto Scaling Group (ASG)** to dynamically scale EC2 instances.
- Deployed an **Application Load Balancer (ALB)** for traffic distribution and health checks.
- Ensured **self-healing architecture**, replacing unhealthy instances **automatically**.

### 🔐 **Security & Compliance**
- **Private RDS Database** (PostgreSQL) with **multi-AZ failover**.
- **Bastion host** for secure SSH access to private EC2 instances.
- Enforced **IAM least privilege policies** for instance roles and service access.
- **Encryption at rest & in transit** (S3 bucket policies, SSL for DB connections).

### 📊 **Monitoring & Automation**
- Integrated **CloudWatch metrics & logs** for real-time monitoring.
- Configured **CloudWatch Alarms & SNS notifications** for proactive issue detection.
- Enabled **CloudTrail logging** for AWS API activity tracking.

### 🛠️ **Troubleshooting & Optimization**
- Debugged **Terraform dependency issues** for efficient resource deployment.
- Optimized **security group rules** to allow only necessary access.
- Resolved issues with **EC2 connectivity, ALB routing, and NAT Gateway access**.

---

## ✅ **What I Tested**
On **February 27, 2025**, I conducted a full infrastructure test:
1. **Logged In:** Connected to the bastion host—authentication worked flawlessly.
2. **Database:** Verified RDS PostgreSQL connection—secure and operational.
3. **Storage:** Uploaded a test file to S3, retrieved its URL, and downloaded it—smooth and fast!
4. **Website:** Visited the ALB DNS address—saw the welcome message, confirming accessibility.
5. **Auto Scaling:** Terminated one EC2 instance—Auto Scaling Group replaced it seamlessly.

These tests confirmed **high availability, security, and resilience** of the infrastructure.

---

## 🏛️ **Infrastructure Breakdown**
The GroceryMate AWS Infrastructure consists of the following core components:

### 🌐 **Networking (VPC, Subnets, NAT)**
- **VPC** (10.0.0.0/16) with **Public & Private Subnets** for isolation.
- **Internet Gateway (IGW)** for external access to public-facing resources.
- **NAT Gateway** for private EC2 instances to securely access the internet.
- **Route Tables** with controlled traffic flow between subnets.

### 🖥️ **Compute Layer (EC2 & Auto Scaling)**
- **Auto Scaling Group (ASG)** for self-healing and dynamic scaling.
- **Launch Template** defining **Amazon Linux AMI**, **user-data scripts**, and instance configuration.
- **Bastion Host** in a public subnet for secure SSH access to private instances.

### ⚖️ **Load Balancing (Application Load Balancer)**
- **ALB routes traffic** across multiple EC2 instances.
- Configured **target groups & health checks** for availability.
- Implements **round-robin traffic distribution**.

### 🗄️ **Database (Amazon RDS)**
- **PostgreSQL RDS** in a private subnet for security.
- Configured **multi-AZ failover** for high availability.
- **Automatic backups & encryption** for data protection.

### 📦 **Storage (Amazon S3)**
- **S3 Bucket for static assets** (e.g., product images, user uploads).
- **Terraform state stored in an S3 bucket** with versioning enabled.

### 📡 **DNS & Routing (Route 53)**
- Configured **Route 53 DNS** for a custom domain.
- **A-records pointing to ALB** for application access.

### 🔍 **Monitoring & Alerts (CloudWatch & SNS)**
- **CloudWatch logs** and **alarms** for CPU, memory, and request monitoring.
- **SNS notifications** for critical events like **instance failures or high CPU usage**.

---

## 🛠️ **Technologies Used**
- **Terraform** – Infrastructure as Code (IaC) for AWS resource management.
- **AWS EC2** – Virtual servers running the GroceryMate application.
- **AWS ALB** – Load balancing and fault tolerance for high availability.
- **AWS ASG** – Dynamic scaling for handling traffic spikes.
- **AWS RDS (PostgreSQL)** – Managed database with automated backups.
- **AWS S3** – Object storage for Terraform state and static assets.
- **AWS IAM** – Secure role-based access control (RBAC).
- **AWS CloudWatch & SNS** – Monitoring and alerting system.
- **AWS Route 53** – DNS management for easy domain access.
- **Git & GitHub** – Version control for Terraform configuration.

---

## 📖 **Deployment & Usage Instructions**
### ✅ **Pre-requisites**
- Install **Terraform** and authenticate with **AWS CLI**.
- Clone the repository:
  ```bash
  git clone https://github.com/YourUsername/GroceryMate-Infrastructure.git
  cd GroceryMate-Infrastructure