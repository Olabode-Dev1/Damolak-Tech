# Damolak Technologies DevOps Challenge

This repository contains a production-oriented sample deployment for the Damolak Technologies DevOps Engineer practical assessment.

## Solution Summary

- Application: lightweight Node.js HTTP service with `/health` and `/ready` endpoints
- Container runtime: Docker
- Infrastructure: Terraform with reusable modules
- Compute platform: AWS ECS Fargate behind an Application Load Balancer
- CI/CD: Jenkins pipeline with automated test, image build, push, and deploy
- Monitoring and logging: CloudWatch Logs and CPU alarm

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

## Architecture Overview

The deployment targets ECS Fargate in a dedicated VPC spread across two availability zones.

1. Jenkins checks out the repository and runs tests.
2. Jenkins builds the Docker image and validates Terraform.
3. Terraform provisions networking, an ECR repository, ECS cluster, ALB, IAM roles, and CloudWatch resources.
4. Jenkins pushes the image to ECR and reapplies Terraform with the Git commit SHA as the running image tag.
5. The ALB routes HTTP traffic to the ECS service running in private subnets.
6. CloudWatch stores container logs and raises a CPU alarm for sustained load.

The architecture diagram is in [docs/architecture.md](docs/architecture.md).

## Design Decisions

### Why ECS Fargate

ECS Fargate keeps the deployment production-relevant while avoiding cluster node management overhead. It is a good fit for a small service and demonstrates infrastructure automation clearly.

### Why Jenkins

The challenge explicitly prefers Jenkins, so the CI/CD path is implemented as a Jenkins pipeline. It still keeps the delivery flow simple: test, build, validate, push, and deploy from a single pipeline definition.

### Why a minimal application

The application is intentionally small so the submission emphasizes infrastructure quality, delivery automation, and operational decisions instead of application complexity.

## Deployment Steps

### 1. Create the Git repository

```bash
git init
git branch -M main
```

### 2. Create AWS prerequisites

- An AWS identity with permissions for:
  - S3
  - ECR
  - ECS
  - IAM pass role
  - ELBv2
  - CloudWatch Logs and Alarms
  - VPC networking resources
- A Terraform state bucket created from the bootstrap stack in `infra/bootstrap/state-backend`
- A Jenkins controller created from the bootstrap stack in `infra/bootstrap/jenkins-controller`

Bootstrap Jenkins on EC2 first if you want the pipeline to run fully on AWS:

```bash
terraform -chdir=infra/bootstrap/jenkins-controller init
terraform -chdir=infra/bootstrap/jenkins-controller apply \
  -var="key_name=<your-ec2-keypair-name>" \
  -var='admin_cidr_blocks=["<your-public-ip>/32"]'
```

That stack creates an Amazon Linux 2023 EC2 instance, installs Jenkins, Docker, Node.js, Terraform, Git, and Java 21 through EC2 user data, and exposes Jenkins on port `8080` only to the CIDRs you provide.

Bootstrap the state bucket first:

```bash
terraform -chdir=infra/bootstrap/state-backend init
terraform -chdir=infra/bootstrap/state-backend apply \
  -var="bucket_name=<your-unique-state-bucket-name>"
```

Then initialize the main stack against that bucket:

```bash
terraform -chdir=infra/terraform/environments/prod init \
  -backend-config="bucket=<your-unique-state-bucket-name>" \
  -backend-config="key=damolak-devops-demo/prod/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -reconfigure
```

- Jenkins should use the same bucket name via the `tf-state-bucket` credential

### 3. Configure Jenkins credentials

- `tf-state-bucket`
  - Secret text credential containing the Terraform state bucket name

The Jenkins controller uses its EC2 instance role for AWS API access. No separate Jenkins-stored AWS access key is required when the controller is launched from `infra/bootstrap/jenkins-controller` with the needed IAM policies attached.

If deploying to a region other than `us-east-1`, update `AWS_REGION` in `Jenkinsfile` and `terraform.tfvars`.

After the Jenkins controller is created, open the output `jenkins_url`, unlock Jenkins with:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Then configure the pipeline job from this repository.

### 4. Optional local verification

```bash
npm test
docker build -t damolak-devops-demo:local .
terraform -chdir=infra/terraform/environments/prod fmt
```

### 5. Push to GitHub and connect Jenkins

```bash
git add .
git commit -m "Initial production-ready deployment"
git remote add origin <your-repository-url>
git push -u origin main
```

Then configure Jenkins as a Pipeline job pointed at this repository. A push to `main` will run the deployment stage automatically when Jenkins is set to build that branch.

## Terraform Notes

- `infra/terraform/modules/network` provisions the VPC, subnets, IGW, and NAT gateway.
- `infra/terraform/modules/ecr` manages the application container registry.
- `infra/terraform/modules/ecs_service` provisions the ALB, ECS cluster/service, IAM roles, log group, and CPU alarm.
- `infra/terraform/environments/prod` composes the modules into a deployable environment.
- `Jenkinsfile` defines the CI/CD workflow.

Remote state is intentionally configured with a partial backend so bucket details can be injected securely during CI. The bucket itself is provisioned separately by `infra/bootstrap/state-backend` to avoid a circular dependency during backend initialization.

## Assumptions

- A public GitHub repository is acceptable for review.
- Jenkins runs on an EC2 instance profile with the required AWS permissions.
- Cost optimization is secondary to clarity for this exercise, although the design still uses a single NAT gateway to stay moderate.

## Limitations and Improvements

- The ALB listener is HTTP only. In a real environment, I would add ACM-backed HTTPS and Route 53.
- There is no database or secret manager because the sample service is stateless.
- The Terraform pipeline uses `apply` directly. In a team setup, I would split plan and apply with approval gates per environment.
- Monitoring is intentionally basic. A stronger production setup would add request latency/error alarms and dashboards.
- The current workflow targets one environment. Adding `dev` and `staging` workspaces would be a natural extension.

## Reviewer Guide

To review quickly:

1. Start with [docs/architecture.md](docs/architecture.md).
2. Inspect `Jenkinsfile` for the delivery flow.
3. Inspect `infra/terraform/modules` for reusable infrastructure design.
4. Run `npm test` locally.
