output "ansible_controller_public_ip" {
  description = "Public IPv4 address of the Ansible controller."
  value       = aws_instance.ansible_controller.public_ip
}

output "ansible_controller_private_ip" {
  description = "Private IPv4 address of the Ansible controller."
  value       = aws_instance.ansible_controller.private_ip
}

output "ansible_controller_instance_id" {
  description = "EC2 instance ID of the Ansible controller."
  value       = aws_instance.ansible_controller.id
}

output "jenkins_server_public_ip" {
  description = "Public IPv4 address of the Jenkins server."
  value       = aws_instance.jenkins_server.public_ip
}

output "jenkins_server_private_ip" {
  description = "Private IPv4 address of the Jenkins server."
  value       = aws_instance.jenkins_server.private_ip
}

output "jenkins_server_instance_id" {
  description = "EC2 instance ID of the Jenkins server."
  value       = aws_instance.jenkins_server.id
}

output "ecr_repository_url" {
  description = "URI used to tag, push, and pull the application image."
  value       = aws_ecr_repository.app.repository_url
}

output "jenkins_url" {
  description = "Jenkins setup URL (reachable only from trusted_cidr)."
  value       = "http://${aws_instance.jenkins_server.public_ip}:8080"
}

output "application_url" {
  description = "NGINX application URL (reachable only from trusted_cidr)."
  value       = "http://${aws_instance.jenkins_server.public_ip}"
}

output "ansible_environment" {
  description = "Environment exports for running Ansible from the controller or workstation."
  value       = <<-EOT
    export JENKINS_HOST=${aws_instance.jenkins_server.private_ip}
    export ECR_REPOSITORY_URL=${aws_ecr_repository.app.repository_url}
    export AWS_REGION=${var.aws_region}
  EOT
}
