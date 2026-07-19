# Jenkins FreeStyle job

## Before creating the job

1. Run `ansible-playbook install_jenkins.yml` and complete the Jenkins setup wizard.
2. Confirm the EC2 instance has the Terraform-managed Jenkins instance profile. Do **not** add AWS access keys to Jenkins.
3. In **Manage Jenkins > Plugins**, install **Git** and **GitHub** (plus **Credentials Binding** for a private repository).
4. Restart Jenkins after plugin installation and verify `sudo -u jenkins docker version` on the host.

## Create the job

1. Select **New Item**, enter `demoproject-devops-build`, choose **Freestyle project**, and select **OK**.
2. Under **Source Code Management**, choose **Git** and enter the GitHub HTTPS repository URL.
3. For a private repository, create a GitHub fine-grained personal access token with read-only Contents permission and store it as a Jenkins **Username with password** credential. Select that credential in the job. Public repositories need no credential.
4. Set the branch specifier to `*/main`.
5. Under **Build Triggers**, choose **GitHub hook trigger for GITScm polling** after configuring the webhook, or use **Poll SCM** with `H/5 * * * *` for a lab without inbound webhooks.
6. Under **Build Environment**, enable timestamped console output if the Timestamper plugin is installed.
7. Add **Build step > Execute shell** with:

```bash
chmod +x jenkins/build_commands.sh
AWS_REGION=ap-south-1 \
ECR_REPOSITORY_NAME=demoproject_ecr_repo1 \
./jenkins/build_commands.sh
```

The script performs ECR login, Docker build, immutable and `latest` tagging, both pushes, local deployment, and an HTTP content check. `BUILD_NUMBER` becomes the immutable image tag.

## IAM role authentication

The AWS CLI resolves temporary credentials from the EC2 Instance Metadata Service. Terraform requires IMDSv2 and attaches a repository-scoped role. Never create an IAM user for this job and never place `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` in Jenkins.

Verify the identity from the host:

```bash
sudo -u jenkins aws sts get-caller-identity
sudo -u jenkins aws ecr describe-repositories \
  --repository-names demoproject_ecr_repo1 \
  --region ap-south-1
```

## GitHub webhook

Set the webhook payload URL to `http://JENKINS_PUBLIC_IP:8080/github-webhook/`, content type `application/json`, and the **push** event. Because the supplied security group restricts port 8080 to `trusted_cidr`, GitHub cannot reach it by default. For a public webhook, put Jenkins behind HTTPS with authentication and narrowly allow GitHub's published hook CIDRs; do not expose the raw port broadly.

## Expected console milestones

```text
Authenticating Docker to ACCOUNT.dkr.ecr.REGION.amazonaws.com
Building demoproject-nginx:BUILD_NUMBER
Pushing images to Amazon ECR
Deployment verified: ACCOUNT.dkr.ecr.REGION.amazonaws.com/demoproject_ecr_repo1:BUILD_NUMBER
Finished: SUCCESS
```
