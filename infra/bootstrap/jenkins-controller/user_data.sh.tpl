#!/bin/bash
set -euxo pipefail

dnf update -y
dnf install -y curl git docker unzip wget fontconfig java-21-amazon-corretto-headless nodejs npm

wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/rpm-stable/jenkins.repo
dnf upgrade -y
dnf install -y jenkins

wget -O /tmp/terraform.zip https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_amd64.zip
unzip -o /tmp/terraform.zip -d /usr/local/bin
chmod +x /usr/local/bin/terraform
rm -f /tmp/terraform.zip

systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user
usermod -aG docker jenkins

mkdir -p /etc/systemd/system/jenkins.service.d
cat <<EOF >/etc/systemd/system/jenkins.service.d/override.conf
[Service]
Environment="JENKINS_OPTS=--httpPort=${jenkins_port}"
EOF

systemctl daemon-reload
systemctl enable jenkins
systemctl restart jenkins
