variable "region" {
    default = "us-central1"
}

variable "vpc_cidr" {
    default = "10.0.0.0/16"
}

variable "subnet_cidr" {
    type = list
    default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "server_count" {
    default = "2"
}

variable "zones" {
    type = list
    default = ["us-central1-a","us-central1-b"]
}