output "api_public_ip" {
  description = "Public IP address of the API gateway instance"
  value       = aws_instance.api.public_ip
}

output "worker_a_private_ip" {
  description = "Private IP of Worker A"
  value       = aws_instance.worker_a.private_ip
}

output "worker_b_private_ip" {
  description = "Private IP of Worker B"
  value       = aws_instance.worker_b.private_ip
}
