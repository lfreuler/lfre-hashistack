# iam.tf - Separate Datei für IAM Ressourcen erstellen!

# IAM Role für EC2 mit SSM Zugriff
resource "aws_iam_role" "hashicorp_instance_role" {
  name = "${var.cluster_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-instance-role"
  }
}

# SSM Policy für Session Manager
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.hashicorp_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile
resource "aws_iam_instance_profile" "hashicorp_profile" {
  name = "${var.cluster_name}-instance-profile"
  role = aws_iam_role.hashicorp_instance_role.name

  tags = {
    Name = "${var.cluster_name}-instance-profile"
  }
}