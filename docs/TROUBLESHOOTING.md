# Troubleshooting guide

Start with the narrowest verification command and inspect logs before changing infrastructure.

| Symptom | Diagnosis | Resolution |
|---|---|---|
| Terraform cannot find the default VPC | `aws ec2 describe-vpcs --filters Name=is-default,Values=true` | Recreate a default VPC in the selected Region or adapt the module to an explicitly managed VPC. |
| `InvalidKeyPair.NotFound` | `aws ec2 describe-key-pairs --region REGION` | Set `key_pair_name` to a key that exists in exactly that Region. |
| SSH times out | Compare your current public IP with `trusted_cidr`; inspect instance status checks. | Update `terraform.tfvars`, apply, and confirm the default subnet has a route to an internet gateway. |
| SSH reports host-key verification failure | `ssh-keygen -F HOST` | Verify the EC2 address changed legitimately, then remove only the stale host entry with `ssh-keygen -R HOST` and rescan it. |
| Ansible inventory has an empty host | `echo "$JENKINS_HOST"` | Export the private IP on the controller or public IP on the trusted workstation. |
| Ansible permission denied | `ssh-add -l` and `ssh -v ubuntu@HOST` | Load the correct key into `ssh-agent`; use `-A` only for the trusted controller hop. |
| Jenkins fails to start | `sudo journalctl -u jenkins -n 200 --no-pager` | Confirm Java 21 is selected, port 8080 is free, then run the install playbook again. |
| Jenkins cannot use Docker | `id jenkins`; `sudo -u jenkins docker version` | Ensure `jenkins` belongs to `docker`, then restart Jenkins so its process receives new group membership. |
| ECR login returns `AccessDenied` | `aws sts get-caller-identity`; inspect the instance profile in EC2 | Attach the Terraform-created Jenkins profile and confirm the repository is the Terraform-created repository. Do not add access keys. |
| Docker push says repository does not exist | Compare `AWS_REGION` and repository URI | Build and push in the same account and Region where Terraform created ECR. |
| Browser cannot reach port 80/8080 | `curl http://127.0.0.1` on the host and inspect security-group rules | Verify service/container state, current public IP, and that the client is inside `trusted_cidr`. |
| Container exits or health is unhealthy | `sudo docker ps -a`; `sudo docker logs demoproject-nginx`; `sudo docker inspect demoproject-nginx` | Correct the image or port conflict, then rebuild and rerun the job/playbook. |
| `terraform destroy` cannot delete ECR | `aws ecr list-images --repository-name demoproject_ecr_repo1` | Delete ECR images after confirming retention requirements, then destroy again. |

## Useful host checks

```bash
cloud-init status --long
sudo tail -n 200 /var/log/cloud-init-output.log
systemctl status jenkins docker --no-pager
journalctl -u jenkins -u docker --since '30 minutes ago' --no-pager
sudo ss -lntp | grep -E ':80|:8080'
sudo docker system df
df -h
```

## ECR and IAM checks

```bash
aws sts get-caller-identity
aws configure list
aws ecr describe-repositories --repository-names demoproject_ecr_repo1 --region ap-south-1
aws ecr describe-images --repository-name demoproject_ecr_repo1 --region ap-south-1
```

On EC2, `aws configure list` should identify instance-role credentials. Never print environment variables or metadata credentials into a Jenkins console log.

## Safe recovery order

1. Preserve the Jenkins console output and relevant service/container logs.
2. Re-run idempotent Ansible configuration.
3. Re-run the Jenkins build to replace the container.
4. Use `terraform plan` to detect infrastructure drift.
5. Recreate infrastructure only after deciding how to retain Jenkins configuration and ECR images.
