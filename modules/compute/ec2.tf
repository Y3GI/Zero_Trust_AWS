# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
    most_recent = true
    owners      = ["amazon"]
        filter {
            name   = "name"
            values = ["al2023-ami-2023.*-x86_64"]
        }
}

# ---------------------------------------------------------
# 1. BASTION HOST (Public Subnet)
# ---------------------------------------------------------

# Security Group: Allow SSH from YOUR IP only
resource "aws_security_group" "bastion_sg" {
    name        = "${var.env}-bastion-sg"
    description = "Allow SSH to Bastion"
    vpc_id      = var.vpc_id

    ingress {
        description = "SSH from Admin IP"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [var.bastion_allowed_cidr] # RESTRICT THIS! 0.0.0.0/0 is unsafe
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "bastion" {
    ami           = data.aws_ami.amazon_linux.id
    instance_type = "t3.micro"

    # Deploy to the first PUBLIC subnet
    subnet_id                   = var.public_subnet_ids[0]
    associate_public_ip_address = true
    vpc_security_group_ids      = [aws_security_group.bastion_sg.id]

    # Encrypt Root Volume with KMS
    root_block_device {
    encrypted   = true
    kms_key_id  = var.kms_key_arn
    }

    tags = {
        Name = "${var.env}-Bastion-Host"
        Role = "Bastion"
    }
}

# ---------------------------------------------------------
# 2. APPLICATION SERVER (Private Subnet)
# ---------------------------------------------------------

# Security Group: Allow SSH ONLY from Bastion SG
resource "aws_security_group" "app_sg" {
    name        = "${var.env}-app-sg"
    description = "Security group for private app server"
    vpc_id      = var.vpc_id

    # Microsegmentation Rule: Only accept SSH from the Bastion Security Group
    ingress {
        description     = "SSH from Bastion"
        from_port       = 22
        to_port         = 22
        protocol        = "tcp"
        security_groups = [aws_security_group.bastion_sg.id]
    }

    # Allow outbound traffic (via NAT Gateway) for updates
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "app_server" {
    ami           = data.aws_ami.amazon_linux.id
    instance_type = var.instance_type

    # Deploy to the first PRIVATE subnet
    subnet_id              = var.private_subnet_ids[0]
    vpc_security_group_ids = [aws_security_group.app_sg.id]

    # Attach the IAM Identity created in the Security Module
    iam_instance_profile = var.app_instance_profile_name

    # ZTNA Requirement: Encrypt Data at Rest
    root_block_device {
        volume_type = "gp3"
        encrypted   = true
        kms_key_id  = var.kms_key_arn
    }

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello Zero Trust" > /home/ec2-user/welcome.txt
                EOF

    tags = {
        Name = "${var.env}-App-Server"
        Role = "Workload"
    }
}