# outputs.tf - Single Instance
output "node_ip" {
  description = "Private IP der HashiCorp Node"
  value       = aws_instance.hashicorp.private_ip
}

output "instance_id" {
  description = "Instance ID für SSM Session Manager"
  value       = aws_instance.hashicorp.id
}

output "ssm_command" {
  description = "SSM Session Manager Command"
  value       = "aws ssm start-session --target ${aws_instance.hashicorp.id}"
}

# SSH Command (optional, da wir SSM haben)
output "ssh_command" {
  description = "SSH Command zur Node (fallback)"
  value       = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.hashicorp.private_ip}"
}

# Direkte UI Access
output "consul_ui" {
  description = "Consul UI"
  value       = "http://${aws_instance.hashicorp.private_ip}:8500"
}

output "vault_ui" {
  description = "Vault UI"  
  value       = "http://${aws_instance.hashicorp.private_ip}:8200"
}

output "nomad_ui" {
  description = "Nomad UI"
  value       = "http://${aws_instance.hashicorp.private_ip}:4646"
}

# AWS Console Link
output "aws_console_link" {
  description = "Direkter Link zur AWS Console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/ec2/v2/home?region=${var.aws_region}#InstanceDetails:instanceId=${aws_instance.hashicorp.id}"
}