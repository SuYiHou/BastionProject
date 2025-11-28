variable "name" {
  type        = string
  description = "Base name used for tagging and naming network resources"
}

variable "name_prefix" {
  type        = string
  description = "Equal to network module"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block assigned to the VPC"
}

# 当前环境，用于标签（dev/prod 等）
variable "environment" {
  type        = string
  description = "Environment identifier for tagging"
}

variable "vpc_id" {
  type        = string
  description = "Target VPC security group"
}

# 额外的自定义标签，按需传入
variable "tags" {
  type = map(string)
  description = "Additional tags to merge onto every resource"
  default = {}
}

/*
  security_groups 采用 map，让你可以在 root module 中按需堆出任意数量的策略。
  sg_sources 用于引用同模块内的其他 SG，写 key 名即可。
*/
variable "security_groups" {
  type = map(object({
    description = string

    ingress = list(object({
      description = string
      protocol    = string
      from_port   = number
      to_port     = number
      cidr_blocks = optional(list(string), [])
      sg_sources  = optional(list(string), [])
    }))

    egress = list(object({
      description = string
      protocol    = string
      from_port   = number
      to_port     = number
      cidr_blocks = optional(list(string), [])
      sg_sources  = optional(list(string), [])
    }))
  }))
  description = "Declarative definition of all security groups and their rules"
}