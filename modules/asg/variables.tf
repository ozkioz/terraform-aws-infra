variable "name" {}
variable "security_group_id" {}
variable "instance_profile_name" {}
variable "subnet_ids" {
  type = list(string)
}
variable "target_group_arn" {}
