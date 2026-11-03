variable "config_dir" {
  default = "../../../config"
}
variable "credentials_dir" {
  default = "../../../credentials"
}
variable "ansible_inventory_dir" {
  default = "../../../ansible/inventory"
}
variable "local_ssh_config_dir" {   # можливо, непотрібно
  default = "~/.ssh/vm_config"
}
variable "local_ssh_keys_dir" {   # можливо, непотрібно
  default = "~/.ssh/external_keys"
}
