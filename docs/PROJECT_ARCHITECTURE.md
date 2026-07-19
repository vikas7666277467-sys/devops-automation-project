# Project architecture

## Delivery flow

```text
                         GitHub
                            |
              clone / webhook / SCM checkout
                            |
                            v
                    Terraform apply
                            |
             +--------------+--------------+
             |                             |
             v                             v
   Ansible Controller                 Jenkins Server
   Ubuntu 24.04                       Ubuntu 24.04
   Ansible + Git                      Java 21 + Jenkins
             |                        Git + Docker + AWS CLI
             | SSH (private IP)             |
             +----------------------------->| build and tag
                                            |
                                            v
                                    Amazon ECR (private)
                                      scan on push
                                            |
                                            | pull with IAM role
                                            v
                                     NGINX container :80
                                            |
                                            v
                                      User's browser
```

## Trust boundaries

```text
Internet / trusted_cidr
        | 22, 80, 8080 only
        v
+------------------------- Default VPC --------------------------+
|  shared project security group                                 |
|                                                                |
|  +----------------------+     SSH/22      +------------------+  |
|  | Ansible controller   | --------------> | Jenkins server   |  |
|  | discovery IAM role   |                 | ECR IAM role     |  |
|  +----------------------+                 +--------+---------+  |
+---------------------------------------------------|------------+
                                                    | TLS/443
                                                    v
                                          AWS ECR API/registry
```

The security group allows unrestricted outbound traffic because package repositories, GitHub, Jenkins packages, Docker image registries, and regional AWS endpoints use changing public addresses. Production environments should use private subnets, NAT or VPC endpoints, an Application Load Balancer with TLS, and a dedicated management channel such as AWS Systems Manager Session Manager.

## Component responsibilities

| Component | Responsibility | Persistent data |
|---|---|---|
| Terraform | Creates and removes AWS infrastructure and access policy. | Local state unless a remote backend is configured. |
| Ansible controller | Applies repeatable operating-system configuration over SSH. | Repository checkout and Ansible collections. |
| Jenkins server | Checks out Git, builds images, publishes to ECR, and runs the demo. | `/var/lib/jenkins`, Docker layers, job workspace. |
| ECR | Stores tagged images and scans them on push. | Up to 20 newest images under the lifecycle policy. |
| NGINX container | Serves the static application on host port 80. | None; the container is replaceable. |

## Security design

- No AWS access keys are created or stored. Jenkins receives temporary credentials through its EC2 instance profile.
- ECR data permissions are restricted to `demoproject_ecr_repo1`; only token acquisition uses `*`, as required by ECR.
- IMDSv2 is mandatory and its response hop limit is one.
- Root volumes are encrypted; ECR encryption and scan-on-push are enabled.
- Public ingress is limited to the operator-supplied `trusted_cidr`; `0.0.0.0/0` is rejected.
- SSH private key material stays with the operator and should be loaded into `ssh-agent`.

## Availability and production evolution

This is a two-node teaching architecture, not a highly available Jenkins service. A production evolution would use a private Jenkins controller, ephemeral build agents, an ALB with ACM TLS, S3/DynamoDB-backed Terraform state, regular Jenkins backups, CloudWatch alarms, VPC endpoints, and immutable AMIs.
