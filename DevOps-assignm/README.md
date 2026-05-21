# DevOps Internship Assignment

This repository contains a reproducible AWS-based deployment for a simple cross-language inference mesh:
- `api` gateway service on a public EC2 instance
- `worker-a` Python worker on a private EC2 instance
- `worker-b` TypeScript worker on a private EC2 instance

The private workers are only reachable from the API gateway VM inside a VPC private subnet.

## Architecture

```
                    Internet
                       |
               +----------------+
               | API VM (public)|
               | 10.0.1.10      |
               | port 8080      |
               +----------------+
                        |
                    private
                       |
               +----------------+
               | Worker A (py)  |
               | 10.0.2.10      |
               | port 5000      |
               +----------------+
                        |
                    private
                       |
               +----------------+
               | Worker B (ts)  |
               | 10.0.2.11      |
               | port 5001      |
               +----------------+
```

RPC flow:
1. API VM receives JSON request
2. API forwards to Worker A over private subnet
3. Worker A forwards to Worker B over private subnet
4. Worker B returns inference result back through Worker A to API

## JSON API contract

Request:
```json
{
  "prompt": "Hello world"
}
```

Response:
```json
{
  "result": "echo:Hello world",
  "trace": ["api","worker-a","worker-b"]
}
```

### Sample curl command

```bash
curl -X POST http://<api-public-ip>:8080/infer \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Hello from DevOps"}'
```

## Terraform deployment

1. Install Terraform and configure AWS credentials.
2. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars`.
3. Edit `terraform/terraform.tfvars` with your AWS region, SSH public key path, and your IP CIDR for SSH access.
4. Run:
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```
5. After apply completes, note `api_public_ip` from Terraform output.

## What is included

- `terraform/`: AWS VPC, public/private subnets, NAT gateway, security groups, and EC2 instances.
- `systemd/`: service unit templates for each worker and the API gateway.
- `deploy.sh`: convenience wrapper for Terraform apply.
- `destroy.sh`: convenience wrapper for Terraform destroy.

## Hardening notes

Before production, I would:
- use private AMI builders and immutable images instead of user data scripting
- put the API endpoint behind an Application Load Balancer and AWS ALB/WAF
- use IAM roles and AWS Secrets Manager for credentials
- enable VPC flow logs, CloudWatch monitoring, and strict egress controls

If the model were 100x larger, I would:
- move inference into GPU-enabled managed instances or ECS/EKS with autoscaling
- use model sharding or batching for throughput
- store model weights in a shared file system or an artifact repository, not baked into the instance user data
- separate compute from stateful storage and add caching layers
