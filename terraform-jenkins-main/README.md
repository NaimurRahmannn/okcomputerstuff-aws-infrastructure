# terraform-jenkins
# Jenkins infrastructure

This stack provisions the Jenkins controller and its public Application Load
Balancer. Direct SSH is disabled by default; provide temporary trusted CIDRs
through the ignored `terraform.tfvars` file only when required.

Create local variables from the checked-in template:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Before applying, confirm that the state bucket is private, encrypted, versioned,
and restricted to the Jenkins state key. The port-80 listener redirects to HTTPS
and the controller's port 8080 is reachable only from the load balancer security
group.

The effective backend bucket is the literal configured in
`remote_backend_s3.tf`; the legacy `bucket_name` input is retained only for
compatibility and does not change backend initialization.
