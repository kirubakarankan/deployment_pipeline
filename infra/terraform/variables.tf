variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1" # Ireland, closest to NL
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "canary-pipeline"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.20.0.0/16"
}

variable "node_instance_types" {
  description = "Instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_count" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}
