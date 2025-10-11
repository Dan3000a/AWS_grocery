# GroceryMate 🛒 – Cloud Infrastructure & E-Commerce Platform

## 🏆 GroceryMate – A Scalable Cloud E-Commerce Solution

![Python](https://img.shields.io/badge/Language-Python%2C%20JavaScript-blue?style=flat-square&logo=python)  
![OS](https://img.shields.io/badge/OS-Linux%2C%20Windows%2C%20macOS-green?style=flat-square&logo=linux)  
![Database](https://img.shields.io/badge/Database-PostgreSQL-336791?style=flat-square&logo=postgresql)  
![AWS](https://img.shields.io/badge/Cloud-AWS-orange?style=flat-square&logo=amazonaws)  
![Terraform](https://img.shields.io/badge/IaC-Terraform-purple?style=flat-square&logo=terraform)  
![GitHub Release](https://img.shields.io/github/v/release/Dan3000a/AWS_grocery?style=flat-square)  

⭐ **Star this repo** if you find it useful – it motivates us a lot! 🚀  

---

## 📌 Table of Contents

- [Overview](#-overview)  
- [Infrastructure Architecture](#-infrastructure-architecture)  
- [Deployment & Automation](#-deployment--automation)  
- [Application Features](#-application-features)  
- [Screenshots & Demo](#-screenshots--demo)  
- [Prerequisites](#-prerequisites)  
- [Installation & Deployment](#-installation--deployment)  
- [Contributing](#-contributing)  
- [License](#-license)  

---

## 🚀 Overview

**GroceryMate** is a modern **cloud-hosted e-commerce platform** designed for seamless online grocery shopping.  
The project integrates:
- **Scalable cloud infrastructure** built with **Terraform & AWS**  
- **A secure and efficient e-commerce application** powered by **Python, JavaScript, and PostgreSQL**  

This repository contains **both the application and the AWS infrastructure**, making it a complete cloud-native solution.

---

## 🏗️ Infrastructure Architecture

The infrastructure follows a **multi-tier AWS architecture**, ensuring **scalability, security, and automation**:

### 🌐 **Networking & Security**
- **VPC (Virtual Private Cloud)** with **public & private subnets**  
- **Internet Gateway & NAT Gateway** for controlled internet access  
- **Security Groups & IAM roles** enforcing **least-privilege access**  

### ⚖️ **Compute & Load Balancing**
- **Auto Scaling Group (ASG)** for dynamic scaling of EC2 instances  
- **Application Load Balancer (ALB)** for distributing traffic across multiple servers  
- **Bastion Host** for secure SSH access  

### 🗄️ **Database & Storage**
- **Amazon RDS (PostgreSQL) in a private subnet** for secure data storage  
- **S3 Bucket** for Terraform state management and static assets  

### 📡 **DNS & Monitoring**
- **AWS Route 53** for domain management  
- **AWS CloudWatch & SNS Alerts** for real-time monitoring and alerts  

---

## 🔄 Deployment & Automation

### ✅ **Infrastructure as Code (IaC)**
- Built entirely with **Terraform** for **repeatability & automation**  
- Uses **S3 + DynamoDB for remote state management**  
- Supports **incremental updates & rollback capabilities**  

### 📊 **Monitoring & Security**
- **CloudWatch Metrics & Alarms** for monitoring resource health  
- **IAM Policies** enforcing **role-based access control**  
- **CloudTrail Logging** for tracking AWS API calls  

---

## 🛒 Application Features

- **🛡️ User Authentication**: Secure registration, login, and session management  
- **🔒 Protected Routes**: Role-based access control  
- **🔎 Product Search & Filtering**: Advanced search with categories and filters  
- **⭐ Favorites Management**: Save preferred products  
- **🛍️ Shopping Basket & Checkout**: Secure order processing  
- **📈 Scalable Cloud Hosting**: **Auto-scaling & high availability** via AWS  

---

## 📸 Screenshots & Demo

![Screenshot 1](https://github.com/user-attachments/assets/ea039195-67a2-4bf2-9613-2ee1e666231a)  
![Screenshot 2](https://github.com/user-attachments/assets/a87e5c50-5a9e-45b8-ad16-2dbff41acd00)  
🎥 **Demo Video**: [Watch Now](https://github.com/user-attachments/assets/d1c5c8e4-5b16-486a-b709-4cf6e6cce6bc)  

---

## 📋 Prerequisites

Ensure you have the following installed:

- **🐍 Python (>=3.11)** – For backend services  
- **🐘 PostgreSQL** – Database  
- **🌩 AWS CLI** – For cloud authentication  
- **🛠️ Terraform** – Infrastructure automation  

---

## ⚙️ Installation & Deployment

### **1️⃣ Clone Repository**
```bash
git clone https://github.com/Dan3000a/AWS_grocery.git
cd AWS_grocery
```

### **2️⃣ Deploy Cloud Infrastructure**
```bash
cd infrastructure
terraform init
terraform plan
terraform apply -auto-approve
```
### **3️⃣ Configure Database**
```bash
psql -U postgres -c "CREATE DATABASE grocerymate_db;"
psql -U postgres -c "CREATE USER grocery_user WITH ENCRYPTED PASSWORD '<your_secure_password>';"
psql -U postgres -c "ALTER USER grocery_user WITH SUPERUSER;"
```
### **4️⃣ Set Up Backend**
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```
### **5️⃣ Set Environment Variables**
```bash
JWT_SECRET_KEY=<your_secure_key>
POSTGRES_USER=grocery_user
POSTGRES_PASSWORD=<your_secure_password>
POSTGRES_DB=grocerymate_db
POSTGRES_HOST=localhost
POSTGRES_URI=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/${POSTGRES_DB}
```
### **6️⃣ Start the Backend**
```bash
python3 run.py
```
### **7️⃣ Deploy the Frontend**
```bash
cd frontend
npm install
npm start
```
### **🔥 Infrastructure Testing**

On February 27, 2025, I tested:
- **SSH Access** – Secure login to EC2 bastion 
- **Database Connectivity** – Verified RDS PostgreSQL connections
- **Storage Access** – Uploaded & retrieved files from S3
- **Web Availability** – Verified website through ALB DNS
- **Auto Scaling** – Terminated an instance, ASG replaced it

✅ All tests passed successfully!

### **🤝 Contributing**

We welcome contributions! Follow these steps:
- **Fork** the repository
- **Create a feature branch**: git checkout -b feature/your-feature
- **Implement changes & commit**
- **Push & create a Pull Request (PR)**

### **📜 License**

This project is licensed under the MIT License and is free for non-commercial use.

🚀 Built with passion by Daniel Siebert & Alejandro Roman Ibanez
Empowering cloud-native e-commerce solutions 🌎

