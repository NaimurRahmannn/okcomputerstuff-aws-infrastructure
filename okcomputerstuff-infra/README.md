# okcomputerstuff-infra

Terraform infrastructure for the `okcomputerstuff` blog.

The application repository is separate:

```text
D:\okcomputerstuff
https://github.com/NaimurRahmannn/okcomputerstuff.git
```

This repository creates the AWS foundation for:

- a configurable public domain through an Application Load Balancer
- an EC2 application host running Apache and Gunicorn
- a private MySQL RDS instance
- a separate VPC with public and private subnets
- ACM DNS validation using the configured Route 53 zone

The existing Jenkins infrastructure is not managed here. It remains in
`D:\aws\terraform-jenkins-main`.

## Local validation

Run Terraform from the `infra` directory:

```powershell
cd D:\aws\okcomputerstuff-infra\infra
terraform init
terraform fmt -recursive
terraform validate
terraform plan -var-file=../environments/prod/prod.tfvars
```

The backend uses the existing Jenkins state bucket but a different state key:

```text
okcomputerstuff-infra/prod/terraform.tfstate
```

Confirm the bucket name in `infra/backend.tf` before the first `terraform init`.

## Apply

Do not apply until the plan has been reviewed:

```powershell
terraform apply -var-file=../environments/prod/prod.tfvars
```

The EC2 instance is bootstrapped for Apache, Python, Gunicorn, and SSM. The
application repository and production environment file are deployed by the
separate `Jenkinsfile.blog` pipeline after the infrastructure is applied.

## Application secret

Terraform creates an empty Secrets Manager secret and does not store its value
in Git or Terraform variables. After `terraform apply`, get the ARN with:

```powershell
terraform output -raw app_secret_arn
```

Create a JSON value for that secret in AWS Secrets Manager with these keys:

```json
{
  "secret_key": "generate-a-long-random-value",
  "admin_email": "admin@example.com",
  "admin_password": "set-a-strong-password",
  "admin_display_name": "Blog administrator"
}
```

The RDS master secret is generated and managed automatically by RDS. Do not
copy its password into `prod.tfvars`.

## Blog Jenkins pipeline

Create a second Jenkins Pipeline job for the application. Configure it to use
this repository and set the script path to `Jenkinsfile.blog`. Install the Git,
Pipeline, AWS Credentials, and Credentials Binding plugins, and configure a
least-privilege AWS credential with ID `okcomputerstuff-aws`.

For the infrastructure pipeline, store the ignored production variable file as
a Jenkins secret-file credential with ID `okcomputerstuff-prod-tfvars`. The
pipeline reads it directly from the temporary credentials location and removes
the generated Terraform plan after every run.

After applying Terraform, collect these outputs:

```powershell
terraform output -raw app_instance_id
terraform output -raw rds_master_secret_arn
terraform output -raw app_secret_arn
```

Store them as Jenkins string credentials named `okcomputerstuff-app-instance-id`,
`okcomputerstuff-rds-secret-arn`, and `okcomputerstuff-app-secret-arn`. The only
build parameter is the full reviewed commit SHA from the protected `main`
branch. The repository URL, branch, deployment targets, and Jenkins AWS
credential ID are fixed by reviewed configuration. The pipeline runs the blog tests,
sends `infra/deploy-app.sh` to the private EC2 instance using Systems Manager,
verifies the selected commit, writes the runtime environment file, initializes
the database, seeds the admin user, and restarts Gunicorn and Apache.
