![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-Automated-blue?logo=githubactions)
![Docker](https://img.shields.io/badge/Docker-Containerized-2496ED?logo=docker)
![Jenkins](https://img.shields.io/badge/Jenkins-CI%2FCD-red?logo=jenkins)
![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform)
![Ansible](https://img.shields.io/badge/Ansible-Automation-EE0000?logo=ansible)

# 🚀 DevOps Automation Project

A complete DevOps Automation Project demonstrating Infrastructure as Code, CI/CD, Configuration Management, and Containerization.

## 🚀 Technologies Used

- Git & GitHub
- GitHub Actions
- Jenkins
- Docker
- Docker Compose
- Ansible
- Terraform
- Bash Scripting
- Linux

## 📂 Project Structure
# End-to-End DevOps Automation on AWS

[![Terraform](https://img.shields.io/badge/Terraform-1.7%2B-7B42BC)](https://developer.hashicorp.com/terraform)
[![Ansible](https://img.shields.io/badge/Ansible-Automated-EE0000)](https://docs.ansible.com/)
[![Jenkins](https://img.shields.io/badge/Jenkins-LTS-D24939)](https://www.jenkins.io/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`demoproject_devops_project1` is a complete repository that provisions, configures, builds, publishes, deploys, and verifies an NGINX web application. Terraform creates two Ubuntu EC2 instances and a private ECR repository; Ansible configures Jenkins and its build toolchain; Jenkins builds the Docker image and publishes it to ECR using an EC2 IAM role; the resulting container serves **Welcome to DEMO Project** on port 80.

> **Cost notice:** Applying this project creates billable AWS resources. Review the plan and AWS pricing, use a sandbox account, and run the cleanup procedure when finished.

## Architecture

```text
                GitHub
                   |
                   v
           Terraform Apply
                   |
        +----------+-----------+
        |                      |
        v                      v
Ansible Controller       Jenkins Server :8080
        |                      |
        | SSH (private IP)     | Docker build/tag/push
        +--------------------->|
                               v
                         Amazon ECR
                               |
                               | IAM role pull
                               v
                      NGINX Container :80
                               |
                               v
                            Browser
```

See [the detailed architecture](docs/PROJECT_ARCHITECTURE.md) for trust boundaries, responsibilities, and production evolution.

## What is automated

| Layer | Implementation |
|---|---|
| Infrastructure | Default-VPC discovery, security group, two EC2 instances, encrypted storage, IAM roles/profiles, ECR, lifecycle policy |
| Bootstrap | Idempotent `ansible` and `jenkins` users with validated `NOPASSWD` sudo rules |
| Configuration | Java 21, Jenkins LTS, Git, Docker, AWS CLI v2, enabled services, endpoint verification |
| Build | NGINX image from `nginx:latest`, immutable Jenkins build tag, rolling `latest` tag |
| Registry | Repository-scoped IAM push/pull, short-lived ECR login, scan-on-push, encrypted image storage |
| Deployment | Jenkins local deployment and an independent Ansible ECR deployment playbook |
| Verification | Jenkins HTTP check, container content check, Ansible URI assertion, operator commands |

## Prerequisites

- An AWS account with a **default VPC** in the target Region
- An existing EC2 key pair and its private key
- A restricted public IPv4 CIDR, normally your address with `/32`
- AWS CLI v2 authenticated with permission to manage EC2, IAM roles/profiles, ECR, and tags
- Terraform 1.7+, Git, OpenSSH, and Ansible Core on the operator workstation
- Docker for optional local testing
- A GitHub account and repository for Jenkins SCM integration

The default configuration uses `ap-south-1`, Ubuntu 24.04 LTS amd64, two `t3.medium` instances, and 30 GiB encrypted gp3 volumes. Verify availability, quotas, and cost in your account before applying.

## AWS security requirements

Terraform creates EC2 instance roles, so **AWS access keys must not be placed on either instance or in Jenkins**. The provisioning identity needs broader infrastructure permissions, while the Jenkins runtime role is limited to ECR authentication and push/pull actions for `demoproject_ecr_repo1`.

Inbound ports are restricted to `trusted_cidr`:

| Port | Use |
|---:|---|
| 22 | Operator SSH; also allowed between the two instances |
| 80 | Deployed NGINX application |
| 8080 | Jenkins user interface |

The variable validation rejects `0.0.0.0/0`. This preserves a secure lab default but means a public GitHub webhook cannot reach Jenkins without a separately designed HTTPS ingress path.

## Repository structure

```text
demoproject_devops_project1/
|-- terraform/
|   |-- provider.tf
|   |-- variables.tf
|   |-- terraform.tfvars.example
|   |-- main.tf
|   |-- outputs.tf
|   `-- README.md
|-- bash_scripts/
|   `-- create_users.sh
|-- ansible/
|   |-- inventory.ini
|   |-- ansible.cfg
|   |-- install_jenkins.yml
|   |-- deploy_nginx_container.yml
|   `-- requirements.yml
|-- docker/
|   |-- Dockerfile
|   `-- index.html
|-- jenkins/
|   |-- freestyle-job.md
|   `-- build_commands.sh
|-- docs/
|   |-- INSTALLATION_AND_CONFIGURATION.md
|   |-- TROUBLESHOOTING.md
|   `-- PROJECT_ARCHITECTURE.md
|-- .gitignore
|-- LICENSE
`-- README.md
```

## Quick start

### 1. Provision with Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`: use the real name of your existing regional key pair and your current public IPv4 `/32`. Then run:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

Key outputs include both public and private IPs, both instance IDs, the ECR repository URL, Jenkins URL, and application URL. Every Terraform resource is explained in [terraform/README.md](terraform/README.md).

### 2. Verify bootstrap and run the user script

Terraform executes `bash_scripts/create_users.sh` through EC2 user data on both instances. To run or verify it manually:

```bash
sudo bash bash_scripts/create_users.sh
id ansible
id jenkins
sudo visudo --check --file=/etc/sudoers.d/ansible
sudo visudo --check --file=/etc/sudoers.d/jenkins
```

Repeated runs do not duplicate users, groups, or sudo rules.

### 3. Prepare the Ansible controller

Wait for cloud-init, copy the `ansible/` directory to the controller, and connect with SSH agent forwarding. Keep the private key on the operator workstation.

```bash
ssh-add ~/.ssh/devops-project.pem
scp -A -r ansible ubuntu@ANSIBLE_CONTROLLER_PUBLIC_IP:~/ansible
ssh -A ubuntu@ANSIBLE_CONTROLLER_PUBLIC_IP
cd ~/ansible
export JENKINS_HOST=JENKINS_SERVER_PRIVATE_IP
ssh-keyscan -H "$JENKINS_HOST" >> ~/.ssh/known_hosts
ansible-galaxy collection install -r requirements.yml
ansible jenkins -m ping
```

Replace the uppercase runtime labels with the values from `terraform output`; infrastructure addresses cannot exist before apply. `inventory.ini` reads `JENKINS_HOST`, and SSH obtains the key from `ssh-agent` rather than from the repository.

### 4. Install Jenkins and its toolchain

```bash
ansible-playbook install_jenkins.yml
```

The playbook installs Java 21 before Jenkins LTS, plus Git, Docker, Python Docker bindings, and AWS CLI v2. It enables Docker and Jenkins, waits for port 8080, and verifies each tool.

Open the `jenkins_url` Terraform output. Retrieve the initial unlock password without copying it into a file:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Choose **Install suggested plugins**, create a named administrator, and confirm the **Git** and **GitHub** plugins under **Manage Jenkins > Plugins**.

### 5. Build and test Docker

```bash
docker build --pull -t demoproject-nginx:local docker/
docker run --rm -d --name demoproject-local -p 8081:80 demoproject-nginx:local
curl --fail http://127.0.0.1:8081/ | grep 'Welcome to DEMO Project'
docker stop demoproject-local
```

### 6. Push the repository to GitHub

```bash
git init
git add .
git commit -m "Build end-to-end DevOps automation project"
git branch -M main
git remote add origin "$GITHUB_REPOSITORY_URL"
git push -u origin main
```

Export `GITHUB_REPOSITORY_URL` to the HTTPS URL of the repository you created. Protect `main`, require review, and enable GitHub secret scanning. Git ignores state, variable values, keys, logs, and local environment files.

### 7. Configure the Jenkins FreeStyle project

Follow [jenkins/freestyle-job.md](jenkins/freestyle-job.md). Configure Git SCM with the GitHub repository and `*/main`, then add this **Execute shell** build step:

```bash
chmod +x jenkins/build_commands.sh
AWS_REGION=ap-south-1 \
ECR_REPOSITORY_NAME=demoproject_ecr_repo1 \
./jenkins/build_commands.sh
```

The job executes the complete sequence:

1. Resolve the AWS account from the EC2 IAM role.
2. Log Docker into ECR with a 12-hour temporary authorization token.
3. Build from `docker/Dockerfile`.
4. Tag with the Jenkins `BUILD_NUMBER` and `latest`.
5. Push both tags to ECR.
6. Replace the running container with the immutable build tag.
7. Require HTTP 200 content containing the expected welcome text.

### 8. Deploy with Ansible from ECR

The Jenkins job already deploys its build. The deployment playbook provides a separately repeatable release path:

```bash
export JENKINS_HOST=JENKINS_SERVER_PRIVATE_IP
export ECR_REPOSITORY_URL=ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/demoproject_ecr_repo1
export AWS_REGION=ap-south-1
export IMAGE_TAG=latest
ansible-playbook deploy_nginx_container.yml
```

It obtains ECR credentials through the target host's IAM role, pulls the requested tag, enforces `unless-stopped`, maps host port 80, and verifies the content.

## ECR operations

Terraform is the source of truth for repository creation. These commands explain authentication and image movement:

```bash
AWS_REGION=ap-south-1
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
ECR_URL=${ECR_REGISTRY}/demoproject_ecr_repo1

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"
docker tag demoproject-nginx:local "$ECR_URL:manual"
docker push "$ECR_URL:manual"
docker pull "$ECR_URL:manual"
```

## Verification and expected outputs

```bash
terraform output -raw jenkins_url
terraform output -raw application_url
curl --fail "$(terraform output -raw application_url)"
```

Representative Terraform output:

```text
ansible_controller_instance_id = "i-..."
ansible_controller_private_ip  = "172.31.x.x"
ansible_controller_public_ip   = "x.x.x.x"
jenkins_server_instance_id     = "i-..."
jenkins_server_private_ip      = "172.31.x.x"
jenkins_server_public_ip       = "x.x.x.x"
ecr_repository_url             = "ACCOUNT.dkr.ecr.REGION.amazonaws.com/demoproject_ecr_repo1"
```

Representative Jenkins result:

```text
Pushing images to Amazon ECR
Deployment verified: ACCOUNT.dkr.ecr.REGION.amazonaws.com/demoproject_ecr_repo1:BUILD_NUMBER
Finished: SUCCESS
```

The browser at `application_url` must display **Welcome to DEMO Project**. For portfolio evidence, capture the redacted Terraform outputs, successful Jenkins console, ECR image tags, and application page; never include keys, tokens, account-sensitive data, or the Jenkins unlock secret.

## Troubleshooting

Use [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for a symptom-to-resolution matrix. First-line checks are:

```bash
cloud-init status --long
systemctl status jenkins docker --no-pager
journalctl -u jenkins -u docker -n 200 --no-pager
sudo docker ps -a
aws sts get-caller-identity
```

Frequent causes are a key pair from the wrong Region, an outdated `trusted_cidr`, a missing SSH agent key, Jenkins not yet restarted after Docker group membership changed, or a mismatch between ECR and CLI Regions.

## Best practices

- Store Terraform state remotely with encryption, versioning, and locking before team use.
- Pin the NGINX image by digest in a production fork; `nginx:latest` is used here because it is an explicit project requirement.
- Scan Terraform, Ansible, shell, and container artifacts in pull requests; review ECR scan findings before promotion.
- Deploy immutable build-number or commit-SHA tags; reserve `latest` for convenience.
- Put Jenkins in a private subnet behind authenticated TLS ingress; use ephemeral build agents and back up `/var/lib/jenkins`.
- Prefer Systems Manager Session Manager and VPC endpoints to public SSH and broad egress in production.
- Rotate EC2 keys, patch hosts, update Jenkins/plugins, and test restore procedures regularly.
- Separate development, staging, and production into distinct accounts and state files.

## Cleanup and destroy

ECR uses `force_delete = false` to prevent accidental image loss. Remove the container and images deliberately before destroying infrastructure:

```bash
aws ecr list-images \
  --repository-name demoproject_ecr_repo1 \
  --region ap-south-1 \
  --query 'imageIds[*]' \
  --output json > ecr-image-ids.json

# Review ecr-image-ids.json. If it contains image IDs and retention is not required:
aws ecr batch-delete-image \
  --repository-name demoproject_ecr_repo1 \
  --region ap-south-1 \
  --image-ids file://ecr-image-ids.json

cd terraform
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

Confirm in AWS that EC2 instances, the project security group, IAM roles/profiles, and ECR repository are gone. Remove local plan and image-list files; they are ignored by Git where applicable.

## Learning outcomes

Completing the project demonstrates declarative AWS provisioning, idempotent Linux configuration, secure workload identity, Jenkins FreeStyle automation, Docker image lifecycle management, ECR operations, immutable deployment, layered verification, troubleshooting, and responsible infrastructure cleanup.

## Full runbook and references

- [Installation and configuration](docs/INSTALLATION_AND_CONFIGURATION.md)
- [Jenkins FreeStyle configuration](jenkins/freestyle-job.md)
- [Architecture and security](docs/PROJECT_ARCHITECTURE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Official Jenkins Linux installation](https://www.jenkins.io/doc/book/installing/linux/)
- [AWS ECR registry authentication](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html)
- [AWS ECR push permissions](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-push-iam.html)

## License

Released under the [MIT License](LICENSE).
