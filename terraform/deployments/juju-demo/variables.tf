variable "model_name" {
  description = "Juju model for deployment"
  type        = string
  default     = "hackathon-infra-interactions-ps7-staging"
}

variable "environment" {
  description = "Environment name (staging/production)"
  type        = string
  default     = "staging"
}
