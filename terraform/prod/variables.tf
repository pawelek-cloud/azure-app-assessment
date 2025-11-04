variable "subscription_id" {

  description = "Azure subscription ID"
  type        = string
}

variable "client_id" {
  description = "Azure service principal client ID"
  type        = string
}

variable "client_secret" {
  description = "Azure service principal client secret"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "db_admin" {
  description = "Database administrator username"
  type        = string
}

variable "db_password" {
  description = "Database administrator password"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, staging, prod)"
  type        = string
}

variable "location" {
  description = "Azure region for deployment"
  type        = string
}

variable "image_name" {
  description = "Name of the Docker image to deploy"
  type        = string
}

variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
}

