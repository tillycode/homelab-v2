variable "name" {
  type = string
}

variable "records" {
  type = map(object({
    name     = string
    type     = string
    content  = string
    priority = optional(number, null)
  }))
  default = {}
}
