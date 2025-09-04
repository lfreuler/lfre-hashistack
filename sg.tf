# security_groups.tf

# HashiCorp Services Security Group
resource "aws_security_group" "hashicorp" {
  name_prefix = "${var.cluster_name}-hashicorp-"
  vpc_id      = var.vpc_id

  # Consul
  ingress {
    from_port = 8300
    to_port   = 8302
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 8301
    to_port   = 8302
    protocol  = "udp"
    self      = true
  }

  ingress {
    from_port = 8500
    to_port   = 8500
    protocol  = "tcp"
    self      = true
  }

  # Vault
  ingress {
    from_port = 8200
    to_port   = 8200
    protocol  = "tcp"
    self      = true
  }

  # Nomad
  ingress {
    from_port = 4646
    to_port   = 4648
    protocol  = "tcp"
    self      = true
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.existing.cidr_block]
  }

  # HTTP/HTTPS für Apps
  ingress {
    from_port   = 8080
    to_port     = 8090
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.existing.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-hashicorp-sg"
  }
}