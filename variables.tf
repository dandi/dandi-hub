# Derived from Data On EKS under Apache License 2.0.
# Source: https://github.com/awslabs/data-on-eks/tree/main/ai-ml/jupyterhub
# See LICENSE file in the root directory of this source code or at http://www.apache.org/licenses/LICENSE-2.0.html.

variable "name" {
  description = "Name of the VPC and EKS Cluster"
  default     = "jupyterhub-on-eks"
  type        = string
}

variable "region" {
  description = "Region"
  type        = string
  default     = "us-west-1"
}

variable "eks_cluster_version" {
  description = "EKS Cluster version"
  default     = "1.27"
  type        = string
}

# VPC with 2046 IPs (10.1.0.0/21) and 2 AZs
variable "vpc_cidr" {
  description = "VPC CIDR. This should be a valid private (RFC 1918) CIDR range"
  default     = "10.1.0.0/21"
  type        = string
}

# RFC6598 range 100.64.0.0/10
# Note you can only /16 range to VPC. You can add multiples of /16 if required
variable "secondary_cidr_blocks" {
  description = "Secondary CIDR blocks to be attached to VPC"
  default     = ["100.64.0.0/16"]
  type        = list(string)
}

# NOTE: You need to use private domain or public domain name with ACM certificate
# Data-on-EKS website docs will show you how to create free public domain name with ACM certificate for testing purpose only
# Example of public domain name(<subdomain-name>.<domain-name>.com): eks.jupyter-doeks.dynamic-dns.com
variable "jupyter_hub_auth_mechanism" {
  type        = string
  description = "Allowed values: oauth. cognito, dummy are not hooked up"
  default     = "oauth"
}

#  Domain name is public so make sure you use a unique while deploying, Only needed if auth mechanism is set to cognito
variable "cognito_custom_domain" {
  description = "Cognito domain prefix for Hosted UI authentication endpoints"
  type        = string
  default     = "eks"
}

# Only needed if auth mechanism is set to cognito
variable "acm_certificate_domain" {
  type        = string
  description = "Enter domain name with wildcard and ensure ACM certificate is created for this domain name, e.g. *.example.com"
  default     = ""
}
variable "jupyterhub_domain" {
  type        = string
  description = "sub-domain name for jupyterhub to be hosted."
}
variable "github_client_id" {
  type        = string
  description = "encrypted client id"
}

variable "github_client_secret" {
  type        = string
  description = "encrypted client secret"
}

variable "singleuser_image_repo" {
  type = string
  description = "OCI repo(TODO or is docker hardcoded?) for single user Jupyterhub image"
}
variable "singleuser_image_tag" {
  type = string
  description = "tag of the container image"
}

variable "dandi_authenticator" {
  type = string
  description = "jupyterhub extraConfig python, implements custom auth"
  default = ""
}

variable "danditoken" {
  type = string
  description = "DANDI API token"
}

variable "aws_certificate_arn" {
  type = string
  description = "AWS certificate for the domain."
  default = ""
}

variable "admin_users" {
  description = "List of admin users"
  type        = list(string)
}

variable "dandi_api_domain" {
  description = "Domain of DANDI API used to check user registration"
  type = string
}

variable "profile_list_path" {
  description = "Path to the profile list file"
  type = string
}