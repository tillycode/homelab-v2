variable "vpc_id" {
  type    = string
  default = null
}

variable "name" {
  type    = string
  default = ""
}

variable "description" {
  type    = string
  default = "Security Group managed by Terraform"
}

variable "ingress_rules" {
  type = list(object({
    protocol    = string
    cidrs       = list(string)
    ports       = optional(list(number), [])
    port_ranges = optional(list(tuple([number, number])), [])
  }))
  default = []
}
