variable "region" {
  description = "The AWS region to deploy the resources"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "subnet_ids" {
  description = "List of subnet IDs in different availability zones"
  type        = list(string)
  default     = ["subnet-0af4abb170dfe5d37", "subnet-0d44d9fd36a571855", "subnet-0411526bc70211453"]
}

variable "subnet_group_name" {
  description = "The name of the subnet group"
  type        = string
}

variable "db_name" {
  description = "The name of the database"
  type        = string
}

variable "db_master_username" {
  description = "The master username for the database"
  type        = string
}

variable "db_master_password" {
  description = "The master password for the database"
  type        = string
  sensitive   = true
}

