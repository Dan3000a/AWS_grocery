
## 📚 Table of Contents

- [Introduction to the task](#introduction-to-the-task)
- [📦 GroceryMate – AWS Infrastructure Overview](#grocerymate--aws-infrastructure-overview)
  - [🗺️ High-Level Infrastructure Overview](#high-level-infrastructure-overview)
  - [🧩 Detailed Infrastructure Topology](#detailed-infrastructure-topology)
- [🔢 Reference Explanations](#reference-explanations)
- [📐 Architecture Diagrams Explanation](#architecture-diagrams-explanation)
- [🌐 Network & Access](#network--access)
- [💡 Application Layer: EC2, ASG & Load Balancing](#application-layer-ec2-asg--load-balancing)
  - [🛠️ EC2 Configuration via Script (Mutable Infrastructure)](#ec2-configuration-via-script-mutable-infrastructure)
  - [🧠 Background: Mutable vs. Immutable Infrastructure](#background-mutable-vs-immutable-infrastructure)
  - [✅ Immutable Infrastructure: Best Practice Insight](#immutable-infrastructure-best-practice-insight)
- [🗄️ Data Layer: RDS PostgreSQL + Secrets Manager](#data-layer-rds-postgresql--secrets-manager)
- [📊 Monitoring & Alerts with CloudWatch](#monitoring--alerts-with-cloudwatch)
- [⚙️ Terraform State Management: S3 Bucket & DynamoDB](#terraform-state-management-s3-bucket--dynamodb)
- [🧩 Summary & Extensibility](#summary--extensibility)
- [🧠 Conclusion](#conclusion)


# Introduction to the task
This project is part of the Cloud Track in the Software Engineering bootcamp at Masterschool. The application was 
originally developed by Alejandro Román. Our task was to design and deploy its AWS infrastructure step by step, 
implementing each component individually.

For details about the application's features, functionality, and local installation as well as a bit of infrastructure, 
refer to the original APP_README.md.

This document focuses exclusively on the AWS infrastructure in deep detail.


# 📦 GroceryMate – AWS Infrastructure Overview

> **Level:** Advanced Cloud/DevOps Engineer  
> **Project Goal:** Provisioning a highly available, modular cloud infrastructure on AWS using Terraform for a 
> production-ready web application with a React frontend and Python backend.


<a name="high-level-infrastructure-overview"></a>
## 🗺️ High-Level Infrastructure Overview
Focuses on logical layers (DNS → ALB → EC2 → RDS → S3).

This diagram provides a layered view of the core AWS infrastructure behind the application. It visualizes the logical 
flow of traffic from DNS resolution through load balancing, compute, and database services, down to supporting components 
like S3, CloudWatch, and IAM.

Each layer is cleanly separated to show how components interact:
	•	Route 53 routes traffic to a regional Application Load Balancer (ALB).
	•	The ALB distributes requests to EC2 instances within a high-availability setup across two Availability Zones.
	•	A managed PostgreSQL RDS serves as the backend database, supplemented by a read replica.
	•	Core services like Secrets Manager, S3, and CloudWatch support observability, security, and deployment automation.

This high-level layout helps understand the system from the top down without diving into networking details like route 
tables or ACLs. For that, refer to the Detailed Infrastructure Topology.

                        ► DNS Layer
                                            ┌────────────────────────────┐
                                            │ Route 53 A Record [R13]   │
                                            └─────────────┬─────────────┘
                                                          ▼
                        ► Load Balancer Layer (regional)
                                            ┌───────────────────────────┐
                                            │ Application Load Balancer │
                                            │ (ALB, regional) [R2]      │
                                            │ ENIs in Public Subnets    │
                                            └─────────────┬─────────────┘
                                                          ▼
                        ► Network Layer (AZs, Subnets)
                            ┌────────────────────────────────────────────────────────────────────┐
                            │                         [R1] VPC                                   │
                            │                   CIDR: 10.0.0.0/16                                │
                            └────────────────────────────┬───────────────────────────────────────┘
                                                         ▼
                            ┌────────────────────────────┬────────────────────────────┐
                            │      Availability Zone A   │      Availability Zone B   │
                            ├────────────────────────────┼────────────────────────────┤
                            │      Public Subnet A       │      Public Subnet B       │
                            │    10.0.1.0/24             │    10.0.2.0/24             │
                            │    ┌────────────────────┐  │    ┌────────────────────┐  │
                            │    │ ENI: ALB [R2]      │  │    │ ENI: ALB [R2]      │  │
                            │    │ NAT Gateway [R6]   │  │    │                    │  │
                            │    │ (physisch hier)    │  │    │                    │  │
                            │    │ Bastion Host [R5]  │  │    │                    │  │
                            │    └────────────────────┘  │    └────────────────────┘  │
                            ├────────────────────────────┼────────────────────────────┤
                            │     Private Subnet A       │     Private Subnet B       │
                            │    10.0.3.0/24             │    10.0.4.0/24             │
                            │    ┌────────────────────┐  │    ┌────────────────────┐  │
                            │    │ EC2 [R4]           │  │    │ EC2 [R4]           │  │
                            │    └────────────────────┘  │    └────────────────────┘  │
                            └────────────────────────────┴────────────────────────────┘
                        ► Compute Layer
                                                         ▼
                          ┌─────────────────────────────────────────────────────────────┐
                          │                  Auto Scaling Group (ASG)                   │
                          │                 ┌────────────────────────────┐              │
                          │                 │ Launch Template [R7]       │              │
                          │                 └────────────────────────────┘              │
                          │                 ┌────────────────────────────┐              │
                          │                 │ IAM Instance Profile [R8]  │              │
                          │                 └────────────────────────────┘              │
                          └─────────────────────────────────────────────────────────────┘
                        ► Database layer
                                                        ▼
                                          ┌────────────────────────────┐
                                          │ Primary RDS [R9]           │
                                          └─────────────┬──────────────┘
                                                        ▼
                                          ┌────────────────────────────┐
                                          │ Read Replica [R10]         │
                                          └─────────────┬──────────────┘
                                                        ▲
                                                        │
                                          ┌────────────────────────────┐
                                          │ DB Subnet Group [R11]      │
                                          └────────────────────────────┘
                        ► Infrastructure Layer (other services)
                    
                                ┌────────────────────────────┐
                                │  S3 Buckets [R15]          │◄───────┐
                                └────────────────────────────┘        │
                                ┌────────────────────────────┐        │
                                │  CloudWatch [R14]          │◄───────┤
                                └────────────────────────────┘        │
                                ┌────────────────────────────┐        │
                                │  IAM & Terraform Backend   │◄───────┘
                                │  [R16], DynamoDB [R17]    │
                                └────────────────────────────┘

### ℹ️ Notes
- The ALB is a **regional service** with ENIs in both Public Subnets (A/B) and is logically positioned **above the subnets**.
- The **NAT Gateway** is physically located in **Public Subnet A**.
- The **Bastion Host** is explicitly placed in **Public Subnet A**.
- **Route 53 (DNS)** is at the top of the stack and points to the ALB.
- All **subnet boxes are equally sized**, and the **Availability Zones (AZs) are arranged side by side**.
- **S3**, **CloudWatch**, and **IAM** are placed at the bottom and connected by reference lines to **ASG/EC2/DB**.

<a name="detailed-infrastructure-topology"></a>
## 🧩 Detailed Infrastructure Topology
Shows every AWS component, subnet, and dependency — useful for engineers and Terraform context.

This diagram presents a comprehensive, engineer-focused view of the entire AWS infrastructure — covering every relevant 
component, subnet, and dependency involved in the deployment.

Unlike the high-level view, this layout is Terraform-centric and includes:
	•	Subnet CIDRs and Availability Zones
	•	Explicit resource references (e.g., [R4] EC2, [R6] NAT Gateway)
	•	Connectivity paths and dependency chains
	•	Supporting services such as Secrets Manager, CloudWatch, and IAM

It is designed to help cloud engineers, DevOps teams, and reviewers quickly understand how all pieces fit together at a 
granular level — down to which subnet a resource lives in and how traffic flows between layers.

Ideal for debugging, Terraform planning, and security reviews.

                
                                       AWS Region: eu-central-1
                                       ───────────────────────────
                                                Terraform
                
                                         [R13] Route 53 A Record
                                                    ▼
                
                                       ┌──────────────────────────┐
                                       │        [R1] VPC          │
                                       │   CIDR: 10.0.0.0/16      │
                                       └────────────┬─────────────┘
                                                    ▼
                        ┌──────────────────────────┬──────────────────────────┐
                        │                          │                          │
                        ▼                          ▼                          ▼
                ┌──────────────────────────┐ ┌──────────────────────────┐ ┌──────────────────────────┐
                │   Public Subnet A        │ │   Public Subnet B        │ │   Bastion Host [R5]      │
                │   AZ: eu-central-1a      │ │   AZ: eu-central-1b      │ │   (Jump Host, A only)    │
                │   CIDR: 10.0.1.0/24      │ │   CIDR: 10.0.2.0/24      │ │   Public Subnet A        │
                │   • ALB [R2]             │ │   • ALB [R2]             │ └──────────────────────────┘
                │   • NAT Gateway [R6]     │ │   • NAT Gateway [R6]     │
                └────────────┬─────────────┘ └────────────┬─────────────┘
                             ▼                            ▼
                     ┌──────────────────────────┐ ┌──────────────────────────┐
                     │ Target Group [R3]        │ │ Target Group [R3]        │
                     └────────────┬─────────────┘ └────────────┬─────────────┘
                                  ▼                            ▼
                        ┌──────────────────────────┐ ┌──────────────────────────┐
                        │ Private Subnet A         │ │ Private Subnet B         │
                        │ AZ: eu-central-1a        │ │ AZ: eu-central-1b        │
                        │ CIDR: 10.0.3.0/24        │ │ CIDR: 10.0.4.0/24        │
                        └────────────┬─────────────┘ └────────────┬─────────────┘
                                     ▼                            ▼
                        ┌──────────────────────────┐ ┌──────────────────────────┐
                        │ EC2 Instance [R4]        │ │ EC2 Instance [R4]        │
                        └────────────┬─────────────┘ └────────────┬─────────────┘
                                     \                          /
                                      ▼                        ▼
                                  ┌───────────────────────────────────────────────┐
                                  │           Auto Scaling Group (ASG)            │
                                  │  ┌──────────────────────────┐                 │
                                  │  │  Launch Template [R7]    │                 │
                                  │  └──────────────────────────┘                 │
                                  │                │                              │
                                  │  ──────────────┘                              │
                                  │  ┌──────────────────────────┐                 │
                                  │  │ IAM Instance Profile [R8] │                │
                                  │  └──────────────────────────┘                 │
                                  └───────────────────────────────────────────────┘
                                                    │
                                                    ▼
                                       ┌──────────────────────────┐
                                       │     Primary RDS [R9]     │
                                       └────────────┬─────────────┘
                                                    ▼
                                       ┌──────────────────────────┐
                                       │   Read Replica [R10]     │
                                       └────────────┬─────────────┘
                                                    ▲
                                                    │
                                       ┌──────────────────────────┐
                                       │ DB Subnet Group [R11]    │
                                       └──────────────────────────┘

           [→ R15] S3 Buckets                [→ R14] CloudWatch           [→ R16] IAM + Terraform Backend           [→ R12] Secrets Manager
     ┌──────────────────────────────────────────────┐        ┌──────────────────────────┐  ┌───────────────────────────────┐        ┌────────────────────────────┐
     │ S3 Buckets [R15] (App + TF State)           │        │ CloudWatch [R14]         │  │ IAM Roles & Policies [R16]    │        │ Secrets Manager [R12]      │
     └──────────────────────────────────────────────┘        └──────────────────────────┘  └───────────────────────────────┘        └────────────────────────────┘
         ▲         ▲                                         ▲       ▲       ▲                 ▲           ▲
         │         │                                       [ASG]   [RDS]   [R10]             [R4]       [Terraform]
        [ASG]     [R4]
    ┌───────────────────────────────┐
    │ DynamoDB Lock Table [R17]     │
    └───────────────────────────────┘


⸻
### 🔢 Reference Explanations

| Ref | Explanation |
|-----|-------------|
| `R1` | **VPC (Virtual Private Cloud)** – Logically isolated virtual network in AWS that contains subnets, route tables and gateways. |
| `R2` | **ALB (Application Load Balancer)** – Regional service that distributes HTTP(S) traffic to healthy targets across multiple AZs. |
| `R3` | **Target Group** – Collection of targets (EC2 instances) that receive traffic from the ALB; health checks determine routing. |
| `R4` | **EC2** – Elastic Compute Cloud instances (virtual servers) running the application. |
| `R5` | **Bastion Host** – SSH jump host placed in a public subnet for administrative access to private instances. |
| `R6` | **NAT Gateway** – Provides outbound internet access to private subnets using an Elastic IP (no inbound). |
| `R7` | **Launch Template** – Template for EC2 instance creation (AMI, user-data, instance type, security groups). |
| `R8` | **IAM Instance Profile** – Binds an IAM role to an EC2 instance, enabling API access to AWS services. |
| `R9` | **RDS Primary** – Managed PostgreSQL instance (primary) for persistent relational storage. |
| `R10` | **Read Replica** – Replica of the primary RDS used to scale read traffic. |
| `R11` | **DB Subnet Group** – Defines which private subnets RDS instances can run in. |
| `R12` | **Secrets Manager** – Secure storage for credentials (username/password), retrievable via SDK/CLI. |
| `R13` | **Route 53** – DNS service; an A-record maps the domain to the ALB (alias). |
| `R14` | **CloudWatch** – Monitoring and alerting service (metrics, alarms, logs, dashboards). |
| `R15` | **S3** – Object storage; used for application assets and as Terraform backend (versioned). |
| `R16` | **IAM / Terraform Backend Role** – Roles & policies used by EC2 and Terraform to access resources. |
| `R17` | **DynamoDB** – Lock table for Terraform state to prevent concurrent `apply` operations. |

---
<a name="architecture-diagrams-explanation"></a>
## 📐 Architecture Diagrams Explanation
## 🌐 Network & Access

The infrastructure follows a highly available, security-focused design according to AWS best practices.  
The central component is the **VPC (R1)**, which logically isolates all resources.  
The VPC uses the CIDR block `10.0.0.0/16`, providing a total of 65,536 IPv4 addresses in the internal address space (calculated as 2^(32-16)).  
An **Internet Gateway (IGW)** is also provided, enabling outbound internet access for public subnets.

Through **Route 53 [R13]**, a public DNS record maps the domain `my-tennistrainer-24.de` directly to the **Application Load Balancer (ALB)**.  
This makes the application accessible under a user-friendly domain name while leveraging ALB’s health checks and intelligent routing.

Two public subnets across different Availability Zones (`eu-central-1a/b`) form the outer high-availability network layer.  
They serve as anchor points for external access and host three key components:

- The **Application Load Balancer (ALB) [R2]** is a regionally managed AWS service (not an EC2 instance).  
  It attaches **ENIs** to both public subnets to receive incoming HTTP(S) traffic and route it to healthy EC2 instances.  
  Functionally, it sits “above” the subnets but uses them for regional anchoring.

- The **NAT Gateway [R6]** is physically located in one of the public subnets and assigned an **Elastic IP**.  
  It enables instances in private subnets to make outbound internet connections (e.g., `yum update`, API calls)  
  without being directly reachable from the public internet.  
  It is defined as the target for `0.0.0.0/0` in the route tables of private subnets.

- The **Bastion Host [R5]** is a dedicated EC2 instance serving as a secure entry point within a public subnet.  
  It has a **public IP** and a restrictive **Security Group** allowing only SSH access from trusted networks (e.g., your office or home).  
  From there, administrators can access EC2 instances in private subnets via a **jump host** principle —  
  allowing maintenance or debugging without exposing private resources to the public.

---

<a name="application-layer-ec2-asg-load-balancing"></a>
## 💡 Application Layer: EC2, ASG & Load Balancing

The **ALB** routes HTTP(S) traffic to a **Target Group [R3]** that references **EC2 instances [R4]** within private subnets.  
These instances are dynamically managed by an **Auto Scaling Group (ASG)**, which uses a **Launch Template [R7]**  
containing parameters such as AMI, instance type, and (optionally) user data.  
Each EC2 instance gains AWS service access via an **IAM Instance Profile [R8]**.

<a name="ec2-configuration-via-script-mutable-infrastructure"></a>
### 🛠️ EC2 Configuration via Script (Mutable Infrastructure)

In the current setup, no `user_data` is defined within the Launch Template.  
Instead, configuration occurs **after boot** using the shell script `update-grocery-instances.sh`,  
executed from the Bastion Host.

The script performs the following tasks:

- Copies backend and frontend files via `scp`
- Sets environment variables such as `JWT_SECRET` and `DATABASE_URL` (using `aws secretsmanager get-secret-value`)
- Runs `collectstatic` and restarts `gunicorn`
- Serves static content through Nginx
- Adjusts permissions on `/home/ubuntu/app/static`

> 🔒 Authentication is performed via SSH from the Bastion Host using the `.pem` key file.

---

<a name="background-mutable-vs-immutable-infrastructure"></a>
### 🧠 Background: Mutable vs. Immutable Infrastructure

This setup represents a **mutable infrastructure**,  
where running instances are modified after launch.  
While functional and ideal for learning, it introduces challenges in scalability and reproducibility.

| Mutable Infrastructure            | Immutable Infrastructure             |
|----------------------------------|--------------------------------------|
| Changes after launch              | Preconfigured before launch          |
| Harder to reproduce               | Easily reproducible                  |
| Prone to scaling inconsistencies  | Stable and scalable                  |
| Low CI/CD integration             | Fully CI/CD-integrated               |

Over time, transitioning to an **immutable** approach using prebuilt AMIs,  
Launch Templates with `user_data`, or automated CI/CD pipelines is recommended.

---

<a name="immutable-infrastructure-best-practice-insight"></a>
### ✅ Immutable Infrastructure: Best Practice Insight

This infrastructure currently follows a **mutable model** —  
EC2 instances are configured via SSH and a deployment script after boot.  
For smaller projects or educational setups, this is acceptable.

**Why immutable setups are better for production:**

- No configuration drift  
- No manual SSH access  
- Seamless CI/CD integration  
- Simplified rollbacks  

**Recommendation:**  
An automated build pipeline should:

1. Create an AMI or Docker image  
2. Update the Launch Template  
3. Trigger an instance refresh in the ASG  

**Suggested tools:**  
_Packer_, _EC2 Image Builder_, _Docker_, _ECS/Fargate_

---

<a name="data-layer-rds-postgresql--secrets-manager"></a>
## 🗄️ Data Layer: RDS PostgreSQL + Secrets Manager

Persistent data is stored in a highly available, managed **RDS PostgreSQL [R9]** instance.  
It resides in a **DB Subnet Group [R11]** spanning private subnets and is not publicly accessible.  
For read-heavy operations, a synchronized **Read Replica [R10]** is used.

The **AWS Secrets Manager [R12]** acts as a central, encrypted credential backend,  
storing parameters such as username, password, host, and port.  
Secrets are not hardcoded; instead, they are retrieved at runtime via **AWS SDK (boto3)** on each EC2 instance.

Each EC2 instance has an attached **IAM Role** (e.g., `grocerymate-ec2-secrets-role`)  
that grants read-only access to the specific secret — adhering to the **principle of least privilege**.

> 🔐 **Note:** IAM token-based authentication is not enabled due to its higher complexity (e.g., `pgcli` with SSL).  
> Instead, the system relies on password-based access managed securely through Secrets Manager.

---

## 📊 Monitoring & Alerts with CloudWatch

**Amazon CloudWatch [R14]** handles both metric collection and alerting.  
It continuously monitors EC2, ASG, RDS, and replica instances.  
When thresholds are exceeded (e.g., CPU > 80% or low RDS storage),  
CloudWatch triggers **alarms** that send notifications via **SNS** to predefined recipients (e.g., email).

### Additional Components:

- **CloudWatch Alarms + SNS Topics:** Automated notifications & escalation  
- **CloudWatch Logs:** Collect and analyze system & application logs  
- **CloudWatch Dashboards:** Visual summaries of key metrics  
- *(Planned)*: EventBridge & OpsCenter integration for self-healing automation  

This makes CloudWatch a vital part of the monitoring and DevSecOps toolkit.

---

<a name="terraform-state-management-s3-bucket--dynamodb"></a>
## ⚙️ Terraform State Management: S3 Bucket & DynamoDB

Terraform state is stored in a **versioned Amazon S3 bucket [R15]**,  
serving as a centralized backend for the `terraform.tfstate` file.  
Versioning enables disaster recovery and rollback of infrastructure state.

A **DynamoDB Lock Table [R17]** is used to manage state locking,  
ensuring that no concurrent `terraform apply` runs occur.

> 🔒 This prevents race conditions and infrastructure drift  
> during parallel deployments (e.g., by multiple developers or CI/CD pipelines).

### Benefits:

- **Team-safe:** Shared, synchronized state  
- **Rollback-ready:** Previous states restorable via S3 versioning  
- **CI/CD-compatible:** Same backend for automated pipelines  

This design represents a well-established best practice for production Terraform environments.

---

## 🧩 Summary & Extensibility

- Modular structure allows for easy future extensions (e.g., Lambda automation)  
- Secrets Manager enables secure credential management and rotation  
- NAT Gateway + route tables ensure proper network isolation  
- ASG + RDS Replica provide scalable performance  
- Terraform 1.x syntax with typed variables ensures maintainability  

A dedicated versioned S3 bucket handles persistent app data, protected via IAM policies.  
CloudWatch completes the system with real-time operational insights and alerting.

> ✅ **The infrastructure is ready for near-production use — secure, automated, and scalable.**

---

## 🧠 Conclusion

This Terraform-based infrastructure combines **best practices**, **modularity**, and **strong security**.  
It serves as both a robust foundation for production-grade cloud deployments  
and a learning platform for Infrastructure-as-Code, FinOps, and DevOps automation.
  