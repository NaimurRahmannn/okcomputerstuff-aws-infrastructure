# AWS infrastructure

This repository contains the Jenkins platform and the `okcomputerstuff` application infrastructure:

- `terraform-jenkins-main/` provisions Jenkins, its load balancer, DNS, and TLS certificate.
- `okcomputerstuff-infra/` provisions the application VPC, load balancer, EC2 host, RDS database, IAM role, and Secrets Manager resources.

## Repository safety

`D:\aws` is the only Git repository. Do not initialize another repository inside either project directory.

Terraform state, plans, local variable files, `.terraform` directories, virtual environments, environment files, private keys, and generated SSM payloads are ignored. Commit `.terraform.lock.hcl` files and `*.tfvars.example` templates; never commit real `*.tfvars`, state, or plan files.

Before staging changes:

```powershell
git status --short --ignored
git add --dry-run .
```

Review the staged paths before every commit:

```powershell
git diff --cached --name-only
git diff --cached
```

## Production requirements

- The S3 state bucket must have Block Public Access enabled, versioning enabled, server-side encryption enabled, and an IAM policy scoped to the two configured state keys.
- Jenkins AWS credentials must use least privilege for the required Terraform and SSM operations. Do not use an account administrator credential.
- Store the production Terraform variable file in Jenkins as a secret-file credential named `okcomputerstuff-prod-tfvars`; the infrastructure pipeline never expects it in Git.
- Store the application instance ID, RDS endpoint, and the two Secrets Manager ARNs as Jenkins string credentials named `okcomputerstuff-app-instance-id`, `okcomputerstuff-rds-host`, `okcomputerstuff-rds-secret-arn`, and `okcomputerstuff-app-secret-arn`; build users cannot override deployment targets.
- Direct SSH is disabled by default. If emergency SSH access is required, set `admin_cidr_blocks` locally to trusted `/32` addresses and remove them after use.
- Jenkins port 8080 accepts traffic only from the Application Load Balancer security group. Public HTTP redirects to HTTPS.
- Protect the application repository's `main` branch. Deployments require the full reviewed commit SHA and reject other repositories or branches.
- Application and database credentials stay in AWS Secrets Manager and must never be copied into Terraform variables or Jenkins parameters.
- Production RDS deletion protection and final snapshots remain enabled.

## Local configuration

Create ignored local variable files from the templates:

```powershell
Copy-Item terraform-jenkins-main/terraform.tfvars.example terraform-jenkins-main/terraform.tfvars
Copy-Item okcomputerstuff-infra/environments/prod/prod.tfvars.example okcomputerstuff-infra/environments/prod/prod.tfvars
```

Replace every example value before planning. Run Terraform separately from each stack directory and review every saved plan before applying it.
