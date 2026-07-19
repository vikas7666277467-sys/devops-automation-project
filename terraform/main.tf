data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "devops" {
  name_prefix = "${var.project_name}-"
  description = "Restricted access to the DevOps project hosts"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from trusted administrator network"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_cidr]
  }

  ingress {
    description = "HTTP application from trusted network"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.trusted_cidr]
  }

  ingress {
    description = "Jenkins UI from trusted network"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.trusted_cidr]
  }

  ingress {
    description = "SSH between project instances"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Outbound access for package repositories and AWS APIs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = var.ecr_repository_name }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain the 20 newest images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "${var.project_name}-jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

data "aws_iam_policy_document" "jenkins_ecr" {
  statement {
    sid       = "ECRAuthentication"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "RepositoryPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:DescribeRepositories",
      "ecr:UploadLayerPart"
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "jenkins_ecr" {
  name   = "ECRPushPull"
  role   = aws_iam_role.jenkins.id
  policy = data.aws_iam_policy_document.jenkins_ecr.json
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project_name}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}

resource "aws_iam_role" "ansible" {
  name               = "${var.project_name}-ansible-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

data "aws_iam_policy_document" "ansible_read" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ecr:DescribeRepositories"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ansible_read" {
  name   = "DiscoveryReadOnly"
  role   = aws_iam_role.ansible.id
  policy = data.aws_iam_policy_document.ansible_read.json
}

resource "aws_iam_instance_profile" "ansible" {
  name = "${var.project_name}-ansible-profile"
  role = aws_iam_role.ansible.name
}

locals {
  create_users_script = file("${path.module}/../bash_scripts/create_users.sh")
  common_instance = {
    ami                         = data.aws_ami.ubuntu.id
    instance_type               = var.instance_type
    key_name                    = var.key_pair_name
    subnet_id                   = sort(data.aws_subnets.default.ids)[0]
    vpc_security_group_ids      = [aws_security_group.devops.id]
    associate_public_ip_address = true
  }
}

resource "aws_instance" "ansible_controller" {
  ami                         = local.common_instance.ami
  instance_type               = local.common_instance.instance_type
  key_name                    = local.common_instance.key_name
  subnet_id                   = local.common_instance.subnet_id
  vpc_security_group_ids      = local.common_instance.vpc_security_group_ids
  associate_public_ip_address = local.common_instance.associate_public_ip_address
  iam_instance_profile        = aws_iam_instance_profile.ansible.name

  user_data = <<-CLOUD_INIT
    #!/usr/bin/env bash
    set -euo pipefail
    ${local.create_users_script}
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y ansible git python3-pip
  CLOUD_INIT

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = var.root_volume_size
  }

  tags = {
    Name = "${var.project_name}-ansible-controller"
    Role = "AnsibleController"
  }
}

resource "aws_instance" "jenkins_server" {
  ami                         = local.common_instance.ami
  instance_type               = local.common_instance.instance_type
  key_name                    = local.common_instance.key_name
  subnet_id                   = local.common_instance.subnet_id
  vpc_security_group_ids      = local.common_instance.vpc_security_group_ids
  associate_public_ip_address = local.common_instance.associate_public_ip_address
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name

  user_data = <<-CLOUD_INIT
    #!/usr/bin/env bash
    set -euo pipefail
    ${local.create_users_script}
  CLOUD_INIT

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = var.root_volume_size
  }

  tags = {
    Name = "${var.project_name}-jenkins-server"
    Role = "JenkinsServer"
  }
}
