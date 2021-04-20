variable "nodes" {
  description  = "Number of nodes per zone"
  default = 1
}

variable "machine_type" {
  default = "n2-standard-2"
}

variable "location" {
  default = "europe-west1"
}

variable "name" {
  default = "prog-delivery"
}
