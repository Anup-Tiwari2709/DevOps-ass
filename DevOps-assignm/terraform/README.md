# Terraform infrastructure

This module provisions the AWS VPC, subnets, NAT gateway, security groups, and three EC2 instances for the quickstart deployment.

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars`.
2. Set `aws_region`, `owner_cidr`, and `public_key_path`.
3. Run:
   ```bash
   terraform init
   terraform apply
   ```

## Notes

- The API gateway instance receives a public IP and listens on port 8080.
- Worker A and Worker B are launched in a private subnet without public IPs.
- The workers are only accessible from the API gateway security group and the configured operator CIDR for SSH.
