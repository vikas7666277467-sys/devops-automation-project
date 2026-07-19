# Installation and configuration runbook

## 1. Prepare the workstation

Install Git, Terraform 1.7 or newer, AWS CLI v2, OpenSSH, and Ansible Core. Docker is needed only for local image testing. Authenticate the AWS CLI with IAM Identity Center or another short-lived credential mechanism.

Confirm access:

```bash
aws sts get-caller-identity
terraform version
ansible --version
ssh -V
```

The provisioning identity needs permission to manage EC2 instances, security groups, instance profiles and inline role policies, ECR repositories, and resource tags in the selected account and Region.

## 2. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Set `key_pair_name` to an existing EC2 key-pair name in `aws_region`. Set `trusted_cidr` to your public IPv4 address followed by `/32`; obtain the address using an organization-approved method. The example documentation CIDR will not grant access from your machine.

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

Terraform creates the ECR repository, two IAM roles and profiles, one security group, an Ansible controller, and a Jenkins server. Wait for cloud-init on both hosts:

```bash
ssh -i ~/.ssh/devops-project.pem ubuntu@$(terraform output -raw ansible_controller_public_ip) \
  'cloud-init status --wait'
ssh -i ~/.ssh/devops-project.pem ubuntu@$(terraform output -raw jenkins_server_public_ip) \
  'cloud-init status --wait'
```

## 3. Configure SSH and Ansible

Load the matching private key locally and forward the agent for the controlled hop. Agent forwarding should be used only to a trusted, dedicated controller.

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/devops-project.pem
ANSIBLE_PUBLIC_IP=$(terraform output -raw ansible_controller_public_ip)
JENKINS_PRIVATE_IP=$(terraform output -raw jenkins_server_private_ip)
scp -A -r ../ansible ubuntu@${ANSIBLE_PUBLIC_IP}:~/ansible
ssh -A ubuntu@${ANSIBLE_PUBLIC_IP}
```

On the controller:

```bash
cd ~/ansible
export JENKINS_HOST=JENKINS_PRIVATE_IP_FROM_TERRAFORM
ssh-keyscan -H "$JENKINS_HOST" >> ~/.ssh/known_hosts
ansible-galaxy collection install -r requirements.yml
ansible-inventory --graph
ansible jenkins -m ping
ansible-playbook install_jenkins.yml
```

`JENKINS_PRIVATE_IP_FROM_TERRAFORM` means the literal private-IP value printed by Terraform. It is runtime infrastructure data, not a secret and cannot be known before provisioning. Alternatively run Ansible from the workstation with `JENKINS_HOST` set to the Jenkins public IP.

## 4. Unlock and configure Jenkins

Open the `jenkins_url` Terraform output from a browser whose address is inside `trusted_cidr`.

Read the one-time administrator password:

```bash
ssh -i ~/.ssh/devops-project.pem ubuntu@$(terraform output -raw jenkins_server_public_ip) \
  'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'
```

Choose **Install suggested plugins**, create a named administrator account, and set the Jenkins URL. In **Manage Jenkins > Plugins**, confirm **Git** and **GitHub** are installed. Apply Jenkins and plugin updates in a tested maintenance window.

## 5. Build and test Docker locally

From the repository root:

```bash
docker build --pull -t demoproject-nginx:local docker/
docker run --rm -d --name demoproject-nginx-local -p 8081:80 demoproject-nginx:local
curl --fail http://127.0.0.1:8081/ | grep 'Welcome to DEMO Project'
docker stop demoproject-nginx-local
```

## 6. Create the GitHub repository

```bash
git init
git add .
git commit -m "Build end-to-end DevOps automation project"
git branch -M main
git remote add origin https://github.com/YOUR_ORGANIZATION/demoproject_devops_project1.git
git push -u origin main
```

Create the destination repository in GitHub first. Substitute the organization that owns the repository; repository ownership is external runtime information. Protect `main`, require pull requests, enable secret scanning and Dependabot, and never commit `terraform.tfvars`, state, `.pem` files, or Jenkins secrets.

## 7. Build and push to ECR manually

Terraform creates `demoproject_ecr_repo1`; no separate console action is required.

```bash
AWS_REGION=ap-south-1
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/demoproject_ecr_repo1
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "${ECR_URL%/*}"
docker build -t demoproject-nginx:local docker/
docker tag demoproject-nginx:local "$ECR_URL:manual"
docker push "$ECR_URL:manual"
docker pull "$ECR_URL:manual"
```

On an EC2 host with the Terraform role, the same login command uses instance-profile credentials automatically.

## 8. Configure and run Jenkins

Follow `jenkins/freestyle-job.md`. The only Execute Shell content required is:

```bash
chmod +x jenkins/build_commands.sh
AWS_REGION=ap-south-1 ECR_REPOSITORY_NAME=demoproject_ecr_repo1 ./jenkins/build_commands.sh
```

Select **Build Now**, open **Console Output**, and confirm the final result is `SUCCESS`. The job publishes both `BUILD_NUMBER` and `latest` tags and deploys the immutable build tag.

## 9. Deploy through Ansible

The Jenkins build already deploys to the Jenkins host. To practice configuration-driven deployment from the Ansible controller:

```bash
export JENKINS_HOST=JENKINS_PRIVATE_IP_FROM_TERRAFORM
export ECR_REPOSITORY_URL=ECR_URL_FROM_TERRAFORM
export AWS_REGION=ap-south-1
export IMAGE_TAG=latest
ansible-playbook deploy_nginx_container.yml
```

## 10. Verify and record evidence

```bash
curl --fail "$(terraform output -raw application_url)"
aws ecr describe-images --repository-name demoproject_ecr_repo1 \
  --region ap-south-1 --query 'sort_by(imageDetails,& imagePushedAt)[-1]'
ssh -i ~/.ssh/devops-project.pem ubuntu@$(terraform output -raw jenkins_server_public_ip) \
  'sudo docker ps --filter name=demoproject-nginx && systemctl is-active jenkins docker'
```

Capture these three screenshots for a portfolio submission: Terraform outputs with account identifiers redacted, the Jenkins `SUCCESS` console result, and the browser showing **Welcome to DEMO Project**. Do not capture credentials, session tokens, the unlock password, or private key material.
