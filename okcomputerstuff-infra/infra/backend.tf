terraform {
  backend "s3" {
    bucket  = "jenkins-tf-state-sg-1234567"
    key     = "okcomputerstuff-infra/prod/terraform.tfstate"
    region  = "ap-southeast-1"
    encrypt = true
  }
}
