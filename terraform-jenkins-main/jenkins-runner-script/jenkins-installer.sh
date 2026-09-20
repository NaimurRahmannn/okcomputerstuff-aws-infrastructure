#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y openjdk-21-jdk-headless unzip wget snapd awscli git python3 python3-venv python3-pip nodejs npm

if ! snap list amazon-ssm-agent >/dev/null 2>&1; then
  sudo snap install amazon-ssm-agent --classic
fi
sudo systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service

echo "Waiting for 30 seconds before installing the jenkins package..."
sleep 30
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
yes | sudo apt-get install jenkins
sleep 30
echo "Waiting for 30 seconds before installing the Terraform..."
TERRAFORM_VERSION="1.6.5"
TERRAFORM_ARCH="amd64"
TERRAFORM_ZIP="terraform_$${TERRAFORM_VERSION}_linux_$${TERRAFORM_ARCH}.zip"
if ! command -v terraform >/dev/null 2>&1; then
  wget "https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/$${TERRAFORM_ZIP}"
  wget "https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/terraform_$${TERRAFORM_VERSION}_SHA256SUMS"
  grep " $${TERRAFORM_ZIP}$" "terraform_$${TERRAFORM_VERSION}_SHA256SUMS" | sha256sum -c -
  unzip -o "$${TERRAFORM_ZIP}"
  sudo install -m 0755 terraform /usr/local/bin/terraform
  rm -f "$${TERRAFORM_ZIP}" "terraform_$${TERRAFORM_VERSION}_SHA256SUMS" terraform
fi
