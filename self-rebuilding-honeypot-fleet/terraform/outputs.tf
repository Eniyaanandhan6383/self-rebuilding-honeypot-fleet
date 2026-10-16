output "nlb_dns_name" {
  value = aws_lb.honeypot.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.honeypot.repository_url
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "task_security_group_id" {
  value = aws_security_group.task.id
}

output "cluster_name" {
  value = aws_ecs_cluster.honeypot.name
}
