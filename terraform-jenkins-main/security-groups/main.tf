variable "ec2_sg_name" {}
variable "vpc_id" {}
variable "ec2_jenkins_sg_name" {}
variable "admin_cidr_blocks" {
  type    = list(string)
  default = []
}

output "sg_ec2_sg_ssh_http_id" {
  value = aws_security_group.ec2_sg_ssh_http.id
}

output "sg_ec2_jenkins_port_8080" {
  value = aws_security_group.ec2_jenkins_port_8080.id
}

resource "aws_security_group" "ec2_sg_ssh_http" {
  name = var.ec2_sg_name
  # AWS treats the group description as immutable. Keep the deployed value so
  # rule hardening is applied in place without replacing the ALB-attached SG.
  description = "Enable the Port 22(SSH) & Port 80(http)"
  vpc_id      = var.vpc_id

  # enable https
  ingress {
    description = "Allow HTTP request from anywhere"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  # enable http
  ingress {
    description = "Allow HTTP request from anywhere"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }

  #Outgoing request
  egress {
    description = "Allow outgoing request"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Jenkins ALB security group"
  }
}

resource "aws_security_group" "ec2_jenkins_port_8080" {
  name        = var.ec2_jenkins_sg_name
  description = "Enable the Port 8080 for jenkins"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Jenkins traffic from the load balancer only"
    security_groups = [aws_security_group.ec2_sg_ssh_http.id]
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
  }

  dynamic "ingress" {
    for_each = var.admin_cidr_blocks
    content {
      description = "Restricted administrator SSH access"
      cidr_blocks = [ingress.value]
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
    }
  }

  egress {
    description = "Allow Jenkins outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Jenkins instance security group"
  }
}
