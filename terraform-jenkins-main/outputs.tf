output "jenkins_url" {
  description = "HTTPS URL for the Jenkins controller."
  value       = "https://${var.domain_name}"
}

output "jenkins_instance_id" {
  description = "EC2 instance ID for the Jenkins controller."
  value       = module.jenkins.jenkins_ec2_instance_ip
}
