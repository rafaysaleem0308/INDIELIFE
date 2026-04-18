<div align="center">

# 🏠 IndieLife

### Your All-in-One Independent Living Companion

*A mobile application for students and professionals living away from home*

[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=flat-square&logo=android&logoColor=white)](https://www.android.com/)
[![Flutter](https://img.shields.io/badge/Built%20With-Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev/)
[![AI Powered](https://img.shields.io/badge/AI-Powered-FF6F00?style=flat-square&logo=tensorflow&logoColor=white)]()
[![University](https://img.shields.io/badge/FAST--NUCES-Chiniot--Faisalabad-003366?style=flat-square)]()
[![Status](https://img.shields.io/badge/Status-In%20Development-yellow?style=flat-square)]()

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Problem Statement](#-problem-statement)
- [Key Features](#-key-features)
- [System Architecture](#-system-architecture)
- [Functional Requirements](#-functional-requirements)
- [Non-Functional Requirements](#-non-functional-requirements)
- [User Roles](#-user-roles)
- [Use Cases](#-use-cases)
- [Team](#-team)
- [Supervision](#-supervision)

---

## 🌟 Overview

**IndieLife** is a comprehensive mobile application designed to simplify the daily lives of students and young professionals living independently away from home. Instead of juggling multiple apps for different needs, IndieLife consolidates everything into a single, intelligent platform — from meal ordering and expense tracking to emergency safety alerts and family communication.

> *"One app. Every need. Anywhere you live."*

---

## 🔍 Problem Statement

Students and professionals living away from home face a fragmented ecosystem of daily challenges:

| Challenge | Impact |
|---|---|
| No single integrated platform for daily management | Time wasted switching between multiple apps |
| Difficulty finding reliable meals, services & accommodation | Increased stress and financial burden |
| No real-time safety alerts | Families and users remain worried |
| Unverified service providers | Trust and reliability issues |
| Poor expense management tools | Reduced productivity and financial strain |

**IndieLife addresses all of these in one place.**

---

## ✨ Key Features

### 🍽️ Meal & Mess Management
Browse verified food providers with menus, pricing, delivery options, and user reviews. Order meals and communicate with providers directly through the app.

### 💸 Expense & Bill Tracking
Log, categorize, and visualize daily expenses. AI-powered bill splitting among roommates, automated reminders for rent and utilities, and monthly spending summaries.

### 🔧 Service Requests
Book laundry, cleaning, plumbing, and maintenance services with real-time status tracking (`Pending → In Progress → Completed`) and post-service ratings.

### 🏡 Accommodation Finder
Browse hostel and flat listings with detailed descriptions, filters, verified owner profiles, and direct booking options.

### 🆘 Safety & Emergency Alerts
Instant SOS alerts with live GPS location shared to family or emergency contacts via SMS, email, or WhatsApp — triggered with a double press of the power button.

### 👨‍👩‍👧 Family Communication
Real-time notifications and activity updates keep families informed about bills, service updates, and emergency situations.

### 🤖 AI-Powered Expense Recommendations
An embedded AI engine analyzes spending patterns and generates personalized financial recommendations to optimize the user's budget.

### 🏘️ Community & Marketplace
Connect with peers, find roommates, buy/sell used items, and use the Lost & Found section — all within a moderated community space.

### 🛡️ Admin Panel
Comprehensive dashboard for user and service provider verification, fraud prevention, content moderation, analytics, and dispute management.

---

## 🏗️ System Architecture

IndieLife follows a multi-role, service-oriented architecture with the following design artifacts:

- **Use Case Diagram** — 13 primary use cases across User, Service Provider, and Admin actors
- **Activity Diagram** — Full application workflow
- **Domain Model** — Core entity relationships
- **Class Diagram** — Object-oriented structure
- **State Machine Diagram** — Lifecycle of key entities
- **Sequence & System Sequence Diagrams** — Interaction flows for all 13 use cases
- **Data Flow Diagrams** — Level 0, 1, and 2 DFDs
- **Component Diagram** — Modular system components
- **Schema Diagram** — Database structure

---

## ⚙️ Functional Requirements

### Meal & Mess Management
- Display verified providers with menus, pricing, and delivery options
- Allow meal ordering, in-app chat with providers, and reviews/ratings
- Provider dashboard for menu and order management

### Expense & Bill Tracking
- Add, edit, and categorize daily expenses
- AI-based automatic bill splitting among roommates
- Reminders for rent/bills with visual monthly summaries

### Service Requests
- Request home services (laundry, cleaning, plumbing, maintenance)
- Auto-assignment to nearest verified provider
- Real-time status updates and post-service ratings

### Safety & Emergency Alerts
- Instant SOS with live location to emergency contacts
- Configurable contacts for SMS, email, or WhatsApp alerts
- Power button double-press trigger

### Family Communication
- Real-time notifications for bills, orders, and emergencies
- Secure messaging between users and family members
- SOS alerts for unusual situations

### Community & Marketplace
- Post and browse items for sale or exchange
- Roommate search with filters (budget, location, preferences)
- Lost & Found section

### Admin Panel
- User and service provider verification
- Community and listing moderation
- Analytics dashboard with user activity and dispute management

---

## 🔒 Non-Functional Requirements

| Requirement | Description |
|---|---|
| **Security** | Strong authentication, end-to-end encryption, secure data storage |
| **Performance** | Fast loading and smooth navigation under high user load |
| **Privacy** | Personal and financial data used strictly for intended purposes |
| **Scalability** | Handles growing users, data, and services without performance degradation |
| **Reliability** | Minimal downtime, accurate real-time updates and notifications |
| **Maintainability** | Modular architecture for easy updates, debugging, and enhancements |
| **Usability** | Intuitive interface accessible to all user types |

---

## 👥 User Roles

```
IndieLife
├── User (Student / Professional)
│   ├── Meal ordering & tracking
│   ├── Expense management
│   ├── Service requests
│   ├── Safety alerts
│   ├── Community access
│   └── AI recommendations
│
├── Service Provider
│   ├── Register & manage services
│   ├── Process & update orders
│   └── View dashboard & analytics
│
└── Admin
    ├── Verify users & providers
    ├── Moderate content
    └── Manage system configuration
```

---

## 📌 Use Cases

| ID | Use Case | Actor |
|---|---|---|
| UC-01 | Login & Authentication | User, Service Provider, Admin |
| UC-02 | Track Order | User |
| UC-03 | Get AI Based Expense Recommendation | User, AI System |
| UC-04 | Receive Alerts | User |
| UC-05 | Manage Service Requests | User |
| UC-06 | Get Recommendations | User |
| UC-07 | Access Community | User |
| UC-08 | Manage Orders | Service Provider |
| UC-09 | View Dashboard | User, Service Provider |
| UC-10 | Register Services | Service Provider |
| UC-11 | Provide Services | Service Provider |
| UC-12 | Manage User | Admin |
| UC-13 | Manage System | Admin |

---

## 👨‍💻 Team

| Name | Roll Number | Role |
|---|---|---|
| **Rafey Saleem** | 22F-3351 | Developer & Requirements Engineer |
| **Isfar Akbar** | 21F-9201 | Developer & Requirements Engineer |
| **Manahil Pakeeza** | 22F-3420 | Developer & Requirements Engineer |

**Department of Computer Science**
FAST – National University of Computer & Emerging Sciences
Chiniot-Faisalabad Campus · 2024

---

## 🎓 Supervision

| Role | Name |
|---|---|
| **Supervisor** | Ms. Mahzaib Younus |
| **Co-Supervisor** | Dr. Umer Aftab |

---

## 📎 References

- [Personal Budget Transactions Dataset — Kaggle](https://www.kaggle.com/datasets/ismetsemedov/personal-budget-transactions-dataset)
- [Income/Expenditure Dataset — Kaggle](https://www.kaggle.com/datasets/saurav9786/incomeexpenditure-dataset)
- [Personal Expense Data — Kaggle](https://www.kaggle.com/datasets/sanjay3454chauhan/personal-expense-data)

---

<div align="center">

*Built with ❤️ at FAST-NUCES, Chiniot-Faisalabad · 2024*

</div>
