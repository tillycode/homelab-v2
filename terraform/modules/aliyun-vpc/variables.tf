variable "vpc_name" {
  type    = string
  default = "TF-VPC"
}

variable "vpc_description" {
  type    = string
  default = "VPC managed by Terraform"
}

variable "vpc_cidr" {
  type = string
}

variable "vpc_enable_ipv6" {
  type    = bool
  default = true

}

variable "vswitches" {
  type = list(object({
    name                 = optional(string, "TF-VSwitch")
    description          = optional(string, "VSwitch managed by Terraform")
    cidr                 = string
    zone_id              = string
    enable_ipv6          = optional(bool, true)
    ipv6_cidr_block_mask = optional(number, 64)
  }))
  default = []
}
