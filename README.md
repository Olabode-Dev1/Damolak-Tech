# Damolak Technologies DevOps Challenge

This repository contains a complete DevOps workflow for deploying a small Node.js service to AWS in a production-style way. The solution uses Docker for packaging, Terraform for infrastructure, Jenkins for CI/CD, AWS ECS Fargate for compute, and CloudWatch for logging and basic monitoring.

The application itself is intentionally simple. The main goal of the repository is to show infrastructure structure, automation, deployment flow, and operational clarity.

## What This Project Does

This project deploys a small HTTP service with three endpoints:

- `/`
- `/health`
- `/ready`

The service is containerized with Docker, stored in Amazon ECR, and deployed to Amazon ECS Fargate behind an Application Load Balancer. Jenkins is used to pull the source code, run tests, build the image, push it to ECR, and apply Terraform to update the running ECS service.

## Solution Summary

- Application: lightweight Node.js HTTP service
- Container runtime: Docker
- Infrastructure as Code: Terraform
- CI/CD: Jenkins
- Cloud provider: AWS
- Compute target: ECS Fargate
- Load balancing: Application Load Balancer
- Monitoring and logging: CloudWatch Logs and a CloudWatch CPU alarm

## Repository Structure

```text
.
|-- Jenkinsfile
|-- docs/architecture.md
|-- infra/bootstrap/jenkins-controller
|-- infra/bootstrap/state-backend
|-- infra/terraform/
|   |-- environments/prod
|   `-- modules/
|       |-- ecr
|       |-- ecs_service
|       `-- network
|-- src/server.js
|-- test/server.test.js
|-- Dockerfile
`-- README.md
```


<img width="1536" height="1024" alt="ChatGPT Image May 10, 2026 at 01_37_07 AM" src="https://github.com/user-attachments/assets/172513f1-efd0-464c-8d76-cfc5ca0cc696" />


## Architecture Overview

The deployment architecture is:

1. A developer pushes code to GitHub.
2. Jenkins pulls the repository.
3. Jenkins runs the Node.js tests.
4. Jenkins builds a Docker image for the app.
5. Jenkins pushes the image to Amazon ECR using the Git commit SHA as the image tag.
6. Jenkins runs Terraform to update the ECS task definition and ECS service.
7. ECS Fargate runs the container in private subnets.
8. An Application Load Balancer exposes the service publicly over HTTP.
9. CloudWatch stores logs and monitors ECS CPU utilization.

The architecture diagram is in [docs/architecture.md](docs/architecture.md).

## Design Decisions

### Why ECS Fargate

ECS Fargate avoids EC2 worker node management and still gives a realistic production deployment target. It is a good fit for a small stateless service and keeps the infrastructure easy to review.

### Why Jenkins

The assessment explicitly prefers Jenkins, so the CI/CD path is implemented with a Jenkins pipeline. The pipeline performs all important delivery steps in one place:

- test
- build
- push
- deploy

### Why a Minimal Application

The application is intentionally small so the focus stays on DevOps implementation rather than business logic. This keeps the reviewer’s attention on:

- infrastructure quality
- CI/CD automation
- AWS deployment
- operational design

### Why Separate Bootstrap Terraform Stacks

Two resources needed to exist before the main application deployment could work cleanly:

- the Terraform remote state bucket
- the Jenkins controller

Those are created in separate bootstrap Terraform stacks so that the main application stack can stay clean and use remote state correctly.

## Important Files

- Application entrypoint: [src/server.js](src/server.js)
- Tests: [test/server.test.js](test/server.test.js)
- Docker image definition: [Dockerfile](Dockerfile)
- Jenkins pipeline: [Jenkinsfile](Jenkinsfile)
- Main Terraform environment: [infra/terraform/environments/prod/main.tf](infra/terraform/environments/prod/main.tf)
- Jenkins bootstrap Terraform: [infra/bootstrap/jenkins-controller/main.tf](infra/bootstrap/jenkins-controller/main.tf)
- Terraform state bucket bootstrap: [infra/bootstrap/state-backend/main.tf](infra/bootstrap/state-backend/main.tf)

## Prerequisites

Before using this project, you need:

- an AWS account
- an AWS identity with enough permissions to create:
  - S3
  - ECR
  - ECS
  - IAM roles and policy attachments
  - ELBv2 resources
  - CloudWatch logs and alarms
  - VPC networking resources
  - EC2 resources for Jenkins
- a GitHub repository
- an EC2 key pair if you want to SSH into the Jenkins instance

## Deployment Flow

This project has three Terraform layers:

1. `infra/bootstrap/state-backend`
   - creates the S3 bucket used for Terraform remote state
2. `infra/bootstrap/jenkins-controller`
   - creates the Jenkins EC2 server
3. `infra/terraform/environments/prod`
   - creates the actual application infrastructure

That order matters.

## Step-by-Step Deployment Guide

### Step 1: Create the Terraform State Bucket

Terraform cannot use an S3 backend bucket that does not exist yet, so the bucket is created first using the bootstrap stack.

Run:

```bash
terraform -chdir=infra/bootstrap/state-backend init
terraform -chdir=infra/bootstrap/state-backend apply \
  -var="bucket_name=<your-unique-state-bucket-name>"
```

Example:

```bash
terraform -chdir=infra/bootstrap/state-backend apply \
  -var="bucket_name=damolak-bucket"
```

## Step 2: Create the Jenkins EC2 Controller

The Jenkins controller is created with Terraform from the separate bootstrap stack.

There is a committed example file here:

- [infra/bootstrap/jenkins-controller/terraform.tfvars.example](infra/bootstrap/jenkins-controller/terraform.tfvars.example)

Create your real local file:

```bash
cp infra/bootstrap/jenkins-controller/terraform.tfvars.example \
   infra/bootstrap/jenkins-controller/terraform.tfvars
```

Edit the file and set:

- `key_name`
- `admin_cidr_blocks`
- any other values you want to change

Then run:

```bash
terraform -chdir=infra/bootstrap/jenkins-controller init
terraform -chdir=infra/bootstrap/jenkins-controller apply
```

What this stack creates:

- an Amazon Linux 2023 EC2 instance
- an instance role / instance profile
- a security group
- Jenkins installation through EC2 user data
- Docker, Git, Node.js, npm, Terraform, and Java installation

### Jenkins Access Note

The intended secure setup is to keep `admin_cidr_blocks` restricted to your public IP, for example:

```hcl
admin_cidr_blocks = ["203.0.113.10/32"]
```

During testing, Jenkins access may fail if:

- the EC2 instance public IP changes
- your own public IP changes
- the security group is too restrictive while you are still iterating

In my working test run, I temporarily opened the Jenkins security group to all IPs to complete setup:

```hcl
admin_cidr_blocks = ["0.0.0.0/0"]
```

That is acceptable for a short-lived assessment environment, but it is not the right long-term production setting. The better long-term fix would be:

- restrict the CIDR to your own IP
- or assign an Elastic IP to the Jenkins instance so the address stays stable

## Step 3: Unlock Jenkins

After the EC2 instance is up, get the Jenkins URL from Terraform outputs or the EC2 console.

The Jenkins service listens on port `8080`.

Open:

```text
http://<jenkins-public-dns>:8080
```

To get the initial password, SSH into the EC2 instance and run:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Then in the Jenkins web UI:

1. install suggested plugins
2. create the first admin user
3. complete the initial setup

## Step 4: Add the Jenkins Credential

This pipeline needs one Jenkins-stored credential:

- Kind: `Secret text`
- ID: `tf-state-bucket`
- Secret: the name of your Terraform state bucket

Example:

```text
damolak-bucket
```

The pipeline does not use a stored AWS access key. It uses the EC2 instance role attached to the Jenkins controller.

## Step 5: Create the Jenkins Pipeline Job

In Jenkins:

1. click `New Item`
2. choose `Pipeline`
3. give it a name
4. choose `Pipeline script from SCM`
5. choose `Git`
6. set the repository URL to your GitHub repo
7. set branch to `*/main`
8. set script path to:

```text
Jenkinsfile
```

## Step 6: Initialize the Main Terraform Stack

The main application stack uses the state bucket created in step 1.

Run:

```bash
terraform -chdir=infra/terraform/environments/prod init \
  -backend-config="bucket=<your-unique-state-bucket-name>" \
  -backend-config="key=damolak-devops-demo/prod/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -reconfigure
```

You can test it with:

```bash
terraform -chdir=infra/terraform/environments/prod validate
terraform -chdir=infra/terraform/environments/prod plan
```

## Step 7: Run the Jenkins Pipeline

When Jenkins runs the pipeline, it performs these actions:

1. checks out the repository
2. runs `npm test`
3. builds the Docker image
4. runs `terraform fmt -check -recursive`
5. initializes Terraform against the remote backend
6. validates the Terraform configuration
7. applies Terraform to ensure ECR exists
8. logs in to ECR
9. tags and pushes the Docker image using the Git commit SHA
10. runs Terraform again with `image_tag=<git commit sha>`
11. updates the ECS service

## Step 8: Verify the Deployment

After a successful pipeline run, Terraform outputs the Application Load Balancer DNS name.

Test the service with:

```bash
curl http://<alb-dns>/
curl http://<alb-dns>/health
curl http://<alb-dns>/ready
```

Expected behavior:

- `/` returns a simple JSON message
- `/health` returns service health metadata
- `/ready` returns readiness metadata

## Local Verification

Before using AWS, the application can be verified locally:

```bash
npm test
docker build -t damolak-devops-demo:local .
docker run --rm -p 3000:3000 damolak-devops-demo:local
```

Then:

```bash
curl http://localhost:3000/
curl http://localhost:3000/health
curl http://localhost:3000/ready
```

## Terraform Module Notes

- `infra/terraform/modules/network`
  - creates the VPC, public subnets, private subnets, internet gateway, NAT gateway, and route tables
- `infra/terraform/modules/ecr`
  - creates the ECR repository and lifecycle policy
- `infra/terraform/modules/ecs_service`
  - creates the ECS cluster, task definition, ECS service, ALB, listener, target group, security groups, IAM roles, CloudWatch log group, and CPU alarm
- `infra/terraform/environments/prod`
  - wires the modules together into one deployable environment

## Jenkins Controller IAM Permissions

The Jenkins EC2 role needs enough permissions to:

- read and write the Terraform state bucket
- manage ECR
- manage ECS
- manage ELBv2 resources
- manage CloudWatch alarms and logs
- manage IAM roles and pass roles to ECS

The Jenkins bootstrap `terraform.tfvars` used in the working deployment includes:

- `IAMFullAccess`
- `CloudWatchFullAccess`
- `AmazonEC2ContainerRegistryPowerUser`
- `AmazonECS_FullAccess`
- `ElasticLoadBalancingFullAccess`
- `AmazonS3FullAccess`

## Assumptions

- A public GitHub repository is acceptable for review.
- The application is stateless.
- The deployment targets one AWS region.
- One production-style environment is enough for this assessment.
- Jenkins runs on a single EC2 controller rather than a larger controller/agent topology.

## Limitations and Improvements

- The ALB listener is HTTP only. A production version should use ACM and HTTPS.
- The Jenkins controller currently uses a changing public IP. A stronger setup would attach an Elastic IP.
- Jenkins security group access was temporarily opened during setup for ease of access. A production setup should restrict this to trusted IPs or VPN access.
- The Terraform pipeline uses direct `apply`. A team workflow would normally split `plan` and `apply`, with review or approval gates.
- Monitoring is basic. A stronger setup would include dashboards, latency/error alarms, and application metrics.
- The app currently reports `local` as its version unless an application version variable is injected.

## Reviewer Guide

For the fastest review:

1. Read [docs/architecture.md](docs/architecture.md)
2. Read [README.md](README.md)
3. Inspect [Jenkinsfile](Jenkinsfile)
4. Inspect the Terraform modules under `infra/terraform/modules`
5. Inspect the bootstrap Terraform stacks under `infra/bootstrap`
