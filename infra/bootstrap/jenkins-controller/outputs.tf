output "instance_id" {
  value = aws_instance.jenkins.id
}

output "public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "public_dns" {
  value = aws_instance.jenkins.public_dns
}

output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_dns}:${var.jenkins_port}"
}

output "security_group_id" {
  value = aws_security_group.jenkins.id
}

output "instance_role_name" {
  value = aws_iam_role.jenkins.name
}
