# instances.tf - Eine Instanz für alle Services

# Key Pair für SSH-Zugriff (optional, da wir SSM haben)
resource "aws_key_pair" "cluster" {
  key_name   = var.cluster_name
  public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
}

# HashiCorp Instanz mit SSM Support
resource "aws_instance" "hashicorp" {
  ami                  = data.aws_ami.amazon_linux.id
  instance_type        = "t3.medium"
  key_name             = aws_key_pair.cluster.key_name
  subnet_id            = var.public_subnet_id
  iam_instance_profile = aws_iam_instance_profile.hashicorp_profile.name
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.hashicorp.id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
  }))

  tags = {
    Name = "${var.cluster_name}-node"
    Role = "hashicorp-server"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}