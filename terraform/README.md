# Terraform infrastructure

This module provisions the complete AWS foundation in the account's default VPC. It uses the latest Canonical Ubuntu 24.04 LTS amd64 AMI available in the selected Region.

## Resources

| Resource | Purpose |
|---|---|
| `data.aws_vpc.default` | Locates the account's default VPC. |
| `data.aws_subnets.default` | Locates its subnets; the first stable sorted ID is used. |
| `data.aws_ami.ubuntu` | Resolves the latest official Ubuntu 24.04 gp3 AMI. |
| `aws_security_group.devops` | Allows ports 22, 80, and 8080 only from `trusted_cidr`, plus SSH between members. |
| `aws_instance.ansible_controller` | Runs Ansible and Git; bootstrap also creates the required users. |
| `aws_instance.jenkins_server` | Runs Jenkins, Docker, AWS CLI, and the NGINX container after Ansible configuration. |
| `aws_ecr_repository.app` | Stores encrypted images and scans every pushed image. |
| `aws_ecr_lifecycle_policy.app` | Retains the 20 most recent images to control storage cost. |
| IAM roles and instance profiles | Give Jenkins repository-scoped ECR push/pull access and Ansible read-only discovery access. No access keys are stored. |

Both instances enforce IMDSv2 and use encrypted gp3 root volumes. The project intentionally does not create or copy a private key.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Set key_pair_name to an existing key and trusted_cidr to your public IP/32.
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

Use an S3 backend with DynamoDB-compatible locking for shared or production use; backend identifiers are account-specific and therefore are not hard-coded in this teaching repository.

## Important behavior

- The default VPC must exist and have a subnet capable of assigning public routes.
- `trusted_cidr = "0.0.0.0/0"` is rejected.
- ECR deletion is protected while images remain (`force_delete = false`). Delete images before `terraform destroy`.
- EC2 public addresses are ephemeral. Re-run `terraform output` after stopping and starting instances.
