```markdown
# GroceryMate 🛒

## 🏆 GroceryMate E-Commerce Platform

![Python](https://img.shields.io/badge/Language-Python%2C%20JavaScript-blue?style=flat-square&logo=python)  
![OS](https://img.shields.io/badge/OS-Linux%2C%20Windows%2C%20macOS-green?style=flat-square&logo=linux)  
![Database](https://img.shields.io/badge/Database-PostgreSQL-336791?style=flat-square&logo=postgresql)  
![GitHub Release](https://img.shields.io/github/v/release/AlejandroRomanIbanez/AWS_grocery?style=flat-square)  
![Free](https://img.shields.io/badge/Free_for_Non_Commercial_Use-brightgreen?style=flat-square)  

⭐ **Star us on GitHub** — it motivates us a lot!  

---

## 📌 Table of Contents

- [Overview](#-overview)  
- [Features](#-features)  
- [Screenshots & Demo](#-screenshots--demo)  
- [Prerequisites](#-prerequisites)  
- [Installation](#-installation)  
  - [Clone Repository](#-clone-repository)  
  - [Configure PostgreSQL](#-configure-postgresql)  
  - [Populate Database](#-populate-database)  
  - [Set Up Python Environment](#-set-up-python-environment)  
  - [Set Environment Variables](#-set-environment-variables)  
  - [Start the Application](#-start-the-application)  
- [Usage](#-usage)  
- [Contributing](#-contributing)  
- [License](#-license)  

---

## 🚀 Overview

**GroceryMate** is a modern, full-featured e-commerce platform designed for seamless online grocery shopping. Developed by **Alejandro Roman Ibanez** as part of the Masterschools program, it offers an intuitive user interface and a secure backend. Users can browse products, manage their shopping basket, and complete purchases efficiently.

---

## 🛒 Features

- **🛡️ User Authentication**: Secure registration, login, and session management.  
- **🔒 Protected Routes**: Access control for authenticated users.  
- **🔎 Product Search & Filtering**: Browse products, apply filters, and sort by category or price.  
- **⭐ Favorites Management**: Save preferred products.  
- **🛍️ Shopping Basket**: Add, view, modify, and remove items.  
- **💳 Checkout Process**:  
  - Secure billing and shipping information handling.  
  - Multiple payment options.  
  - Automatic total price calculation.  

---

## 📸 Screenshots & Demo

Explore GroceryMate in action:  

![Screenshot 1](https://github.com/user-attachments/assets/ea039195-67a2-4bf2-9613-2ee1e666231a)  
![Screenshot 2](https://github.com/user-attachments/assets/a87e5c50-5a9e-45b8-ad16-2dbff41acd00)  
![Screenshot 3](https://github.com/user-attachments/assets/589aae62-67ef-4496-bd3b-772cd32ca386)  
![Screenshot 4](https://github.com/user-attachments/assets/2772b85e-81f7-446a-9296-4fdc2b652cb7)  

🎥 **Demo Video**:  
[Watch the Demo](https://github.com/user-attachments/assets/d1c5c8e4-5b16-486a-b709-4cf6e6cce6bc)

---

## 📋 Prerequisites

Before running GroceryMate, ensure you have:  

- **🐍 Python (>=3.11)** – Backend runtime.  
- **🐘 PostgreSQL** – Database for storing product and user data.  
- **🛠️ Git** – Version control system.  

---

## ⚙️ Installation

### 🔹 Clone Repository
Get the code from the `version2` branch:

```bash
git clone --branch version2 https://github.com/AlejandroRomanIbanez/AWS_grocery.git && cd AWS_grocery
```

### 🔹 Configure PostgreSQL
Set up the database with a secure user. Replace `<your_secure_password>` with a strong password of your choice.

```bash
psql -U postgres -c "CREATE DATABASE grocerymate_db;"
psql -U postgres -c "CREATE USER grocery_user WITH ENCRYPTED PASSWORD '<your_secure_password>';"
psql -U postgres -c "ALTER USER grocery_user WITH SUPERUSER;"
```

### 🔹 Populate Database
Load the initial data:

```bash
psql -U grocery_user -d grocerymate_db -f backend/app/sqlite_dump_clean.sql
```

Verify the insertion:

```bash
psql -U grocery_user -d grocerymate_db -c "SELECT * FROM users;"
psql -U grocery_user -d grocerymate_db -c "SELECT * FROM products;"
```

### 🔹 Set Up Python Environment
Install dependencies in a virtual environment:

```bash
cd backend
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
venv\Scripts\activate     # Windows
pip install -r requirements.txt
```

### 🔹 Set Environment Variables
Create a `.env` file in the `backend` directory:

```bash
touch .env  # macOS/Linux
ni .env -Force  # Windows PowerShell
```

Generate a secure JWT key:

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

Add the following to `.env` (replace `<your_generated_key>` with the output from above):

```ini
JWT_SECRET_KEY=<your_generated_key>
POSTGRES_USER=grocery_user
POSTGRES_PASSWORD=<your_secure_password>
POSTGRES_DB=grocerymate_db
POSTGRES_HOST=localhost
POSTGRES_URI=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/${POSTGRES_DB}
```

### 🔹 Start the Application
Launch GroceryMate:

```bash
python3 run.py
```

---

## 📖 Usage

- Open your browser and go to [http://localhost:5000](http://localhost:5000).  
- **Register/Login** to your account.  
- **Browse/Search** for products.  
- Manage your **favorites** and **shopping basket**.  
- Complete the **checkout process**.  

---

## 🤝 Contributing

We welcome contributions! Follow these steps:

1. Fork the repository.  
2. Create a new branch: `git checkout -b feature/your-feature`.  
3. Implement your changes and commit them.  
4. Push your branch and submit a pull request.  

---

## 📜 License

This project is licensed under the **[MIT License](#-license)** and is free for non-commercial use.

---

✨ **Built with passion by Alejandro Roman Ibanez + Daniel Siebert**  
Happy shopping with GroceryMate! 🛍️
```