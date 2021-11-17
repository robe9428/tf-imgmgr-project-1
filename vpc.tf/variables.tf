variable "region" {}
variable "vpc_cidr" {
  type        = string
  default     = "192.168.0.0/21"
  description = "Please enter the IP range (CIDR notation)"
}

variable "public-subnets" {
  type    = list
  default = ["192.168.1.0/24" , "192.168.2.0/24"]
}

variable "private-subnets" {
  type    = list
  default = ["192.168.3.0/24" , "192.168.4.0/24"]
}

variable "azs" {
  type    = list
  default = ["eu-west-2a" , "eu-west-2b"]
}

variable "public-subnet-1" {
  type = string
  default = "192.168.1.0/24"
}

variable "public-subnet-2" {
  type = string
  default = "192.168.2.0/24"
}

variable "private-subnet-1" {
  type = string
  default = "192.168.3.0/24"
}

variable "private-subnet-2" {
  type = string
  default = "192.168.4.0/24"
}

variable "nat-gw-1" {
  type = string
  default = "nat-001181da23cd8a677"
}

variable "nat-gw-2" {
  type = string
  default = "nat-01de1dedf0a7a4d3e"
}
