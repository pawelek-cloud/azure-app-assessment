# Azure App Deployment Assessment

This repository contains a simple web application deployed on Azure using Terraform, Docker, and GitHub Actions.

## Tech Stack

- Python (Flask)
- PostgreSQL 
- Docker
- Azure Container Registry
- Terraform
- Azure App Service
- GitHub Actions

## Features

- Basic UI to store and retrieve data from a database
- Dockerized application
- Infrastructure as Code with Terraform
- CI/CD pipeline with GitHub Actions
- Azure deployment with private endpoint to database

## 📁 Project Structure

```text
azure-app-assessment/
├── app/
│   ├── app.py
│   ├── requirements.txt
│   └── templates/
│       └── index.html
├── tests/
│   └── test_db_connection.py
├── terraform/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── dev.tfvars
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── staging.tfvars
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── prod.tfvars
├── Dockerfile
├── .gitignore
├── .github/
│   └── workflows/
│       └── deploy.yml
└── README.md

```

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/azure-app-assessment.git
cd azure-app-assessment
```

### 2. Run Locally with Docker (optional)

```bash
docker build -t azure-app .
docker run -p 8081:8081 azure-app
```
Check the running app:

```bash
http://localhost:8081/
```

### 3. Azure Credentials & GitHub Secrets Setup

To deploy infrastructure using Terraform via GitHub Actions, you need to:

#### a) Create an Azure Service Principal
  
  ```bash
   az ad sp create-for-rbac \
  --name "terraform-sp" \
  --role="Contributor" \
  --scopes="/subscriptions/<your-subscription-id>" \
  --sdk-auth
  ```
```bash
{
  "clientId": "...",
  "clientSecret": "...",
  "subscriptionId": "...",
  "tenantId": "...",
  ...
}
```
Do not commit this JSON to source control.

#### b) Assign the correct roles

To allow Terraform to assign the AcrPull role to your App Service, the Service Principal must also have:

User Access Administrator or Owner role on the ACR scope

Assign it using:

```bash
az role assignment create \
  --assignee <clientId> \
  --role "User Access Administrator" \
  --scope "/subscriptions/<subscription-id>"
```

This ensures Terraform can grant your App Service permission to pull container images from Azure Container Registry (ACR).

#### c) Store credentials securely in GitHub Secrets

In your GitHub repository:

Go to Settings → Secrets and variables → Actions → New repository secret, and add:

| Secret Name           | Value from JSON output |
|-----------------------|------------------------|
| `ARM_CLIENT_ID`       | `clientId`             |
| `ARM_CLIENT_SECRET`   | `clientSecret`         |
| `ARM_SUBSCRIPTION_ID` | `subscriptionId`       |
| `ARM_TENANT_ID`       | `tenantId`             |

Add App-Specific Secrets
Also add the following secrets required by your Terraform and application:

| Secret Name   | Description                                      |
|---------------|--------------------------------------------------|
| `DB_PASSWORD` | Admin password for PostgreSQL Flexible Server    |
| `DB_ADMIN`    | Admin username for PostgreSQL Flexible Server    |


### 4. CI/CD Pipeline

On push to `main`, GitHub Actions will:

- Build and push Docker image to Docker Hub
- Deploy infrastructure with Terraform
- Deploy app to Azure App Service
- Run database connection test

You can specify environment, database name (PostgreSQL) and and Docker image name with tag.

## Environments

- `dev`, `staging`, and `prod` configurations are available in `Github Actions` workflow run.

## Test

Github Actions as last step runs the test to verify DB connection:


