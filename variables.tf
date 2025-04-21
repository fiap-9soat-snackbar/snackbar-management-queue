variable "max_receive_count" {
  description = "Maximum number of times a message can be received before being sent to the DLQ"
  type        = number
  default     = 5
}

variable "message_retention_seconds" {
  description = "The number of seconds SQS retains a message"
  type        = number
  default     = 345600  # 4 days
}

variable "visibility_timeout_seconds" {
  description = "The visibility timeout for the queue"
  type        = number
  default     = 30
}

variable "delay_seconds" {
  description = "The time in seconds that the delivery of all messages in the queue will be delayed"
  type        = number
  default     = 0
}

variable "receive_wait_time_seconds" {
  description = "The time for which a ReceiveMessage call will wait for a message to arrive"
  type        = number
  default     = 0
}

variable "max_message_size" {
  description = "The limit of how many bytes a message can contain"
  type        = number
  default     = 262144  # 256 KiB
}

variable "use_localstack" {
  description = "Whether to use LocalStack for local development"
  type        = bool
  default     = false
}

# Remote state configuration
variable "remote_state_bucket" {
  description = "S3 bucket containing remote state"
  type        = string
  default     = "terraform-state"
}

variable "remote_state_key" {
  description = "Path to the global remote state file"
  type        = string
  default     = "global/terraform.tfstate"
}

variable "remote_state_region" {
  description = "Region of the remote state bucket"
  type        = string
  default     = "us-east-1"
}
