# terraform-aws-infra

Terraform configuration for a classic three-tier web setup on AWS: an Application Load Balancer in public subnets, an Auto Scaling group of EC2 instances in private subnets, and a private MySQL RDS instance. Remote state is kept in S3 with DynamoDB locking.

Currently there is a single environment, `dev`, deployed to `us-east-1`.

## Architecture

```
                    Internet
                        │
                 ┌──────▼──────┐
                 │     ALB     │  HTTP :80
                 └──────┬──────┘
   ┌────────────────────┼────────────────────┐  VPC 10.0.0.0/16
   │  Public subnets    │  (us-east-1a / 1b) │
   │                    │         NAT GW ◄───┼── Internet Gateway
   ├────────────────────┼────────────────────┤
   │  Private subnets   │  (us-east-1a / 1b) │
   │          ┌─────────▼─────────┐          │
   │          │  ASG: 2–3 × EC2   │          │
   │          │  (Apache httpd)   │          │
   │          └─────────┬─────────┘          │
   │                    │ MySQL :3306        │
   │          ┌─────────▼─────────┐          │
   │          │    RDS MySQL      │          │
   │          └───────────────────┘          │
   └─────────────────────────────────────────┘
```

Traffic rules (security groups):

| Security group | Allows inbound                  |
|----------------|---------------------------------|
| `alb`          | TCP 80 from `0.0.0.0/0`         |
| `ec2`          | TCP 80 from the `alb` SG only   |
| `rds`          | TCP 3306 from the `ec2` SG only |

## Repository structure

```
.
├── bootstrap/        # One-off: S3 bucket + DynamoDB table for remote state
├── envs/
│   └── dev/          # Dev environment, wires the modules together
└── modules/
    ├── vpc/          # VPC, subnets, IGW, NAT, route tables, security groups
    ├── alb/          # Application Load Balancer, target group, HTTP listener
    ├── asg/          # Launch template + Auto Scaling group
    ├── iam/          # EC2 role (SSM access) + instance profile
    ├── rds/          # MySQL instance + DB subnet group
    └── ec2/          # Standalone EC2 instance (not used by envs/dev)
```

## What gets created

**bootstrap**
- S3 bucket for Terraform state (versioning enabled)
- DynamoDB table `terraform-locks` (pay-per-request) for state locking

**envs/dev**
- **VPC**: `10.0.0.0/16` with two public subnets (`10.0.1.0/24`, `10.0.3.0/24`) and two private subnets (`10.0.2.0/24`, `10.0.4.0/24`) across `us-east-1a` and `us-east-1b`; internet gateway, one NAT gateway (in `public_a`) with an Elastic IP, public and private route tables
- **ALB**: internet-facing application load balancer, HTTP listener on port 80 forwarding to a target group (health check on `/`)
- **ASG**: launch template (latest Amazon Linux 2023 AMI, `t2.micro`) and an Auto Scaling group with min 2 / desired 2 / max 3 instances in the private subnets. User data installs Apache and serves a page that says `Hello from <hostname>`
- **IAM**: EC2 role with `AmazonSSMManagedInstanceCore`, so instances can be reached through Session Manager (no SSH or key pair needed)
- **RDS**: MySQL on `db.t3.micro`, 20 GB, in the private subnets, not publicly accessible

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) (no version is pinned in the code; the lock files were generated with AWS provider 6.x)
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials that can create the resources above (`aws configure` or `AWS_PROFILE`)

## Usage

### 1. Bootstrap the remote state backend (once)

The S3 bucket name must be globally unique. The one in the code (`kunda-terraform-state-bucket-12345`) belongs to the original author, so if you are deploying this in your own account, change it in **both** `bootstrap/main.tf` and the `backend "s3"` block in `envs/dev/main.tf`.

```bash
cd bootstrap
terraform init
terraform apply
```

The bootstrap stack uses local state, so keep (or back up) the resulting `terraform.tfstate` if you may need to change or destroy it later.

### 2. Deploy the dev environment

`*.tfvars` is git-ignored, so create your own `envs/dev/terraform.tfvars`:

```hcl
aws_region = "us-east-1"
vpc_cidr   = "10.0.0.0/16"
vpc_name   = "dev-vpc"
```

Then:

```bash
cd envs/dev
terraform init
terraform plan
terraform apply
```

### 3. Check that it works

The environment does not define outputs yet, so grab the ALB DNS name from the AWS console (EC2 → Load Balancers) or with the CLI:

```bash
aws elbv2 describe-load-balancers --names dev-alb \
  --query 'LoadBalancers[0].DNSName' --output text
```

Open `http://<dns-name>` in a browser. Refreshing should show `Hello from ...` with different hostnames as the load balancer rotates between instances. Instances may need a few minutes to pass health checks after the first apply.

### 4. Tear down

```bash
cd envs/dev
terraform destroy
```

Destroy `envs/dev` first. The state bucket is versioned, so removing `bootstrap` requires emptying all object versions from the bucket manually before `terraform destroy` will succeed.

## Inputs

### `envs/dev`

| Name         | Type     | Default | Description                                     |
|--------------|----------|---------|-------------------------------------------------|
| `aws_region` | `any`    | none    | AWS region for the provider                     |
| `vpc_cidr`   | `any`    | none    | VPC CIDR       |
| `vpc_name`   | `string` | none    | Name prefix used in subnet `Name` tags          |

### Module outputs

| Module | Output                                                                                              |
|--------|-----------------------------------------------------------------------------------------------------|
| `vpc`  | `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `alb_sg_id`, `ec2_security_group_id`, `rds_security_group_id` |
| `alb`  | `target_group_arn`, `alb_dns_name`                                                                  |
| `iam`  | `instance_profile_name`                                                                             |
| `ec2`  | `instance_id`, `public_ip`                                                                          |

`asg` and `rds` expose no outputs, and `envs/dev` does not re-export any module outputs.

## Cost

This stack is **not free-tier friendly**. The main recurring costs are the NAT gateway, the Application Load Balancer, two EC2 instances and the RDS instance. Run `terraform destroy` when you are done experimenting, and check current pricing for your region.

## Possible next steps

- Add `envs/staging` / `envs/prod` reusing the same modules
- Expose `alb_dns_name` as an output of `envs/dev`
- Pin `required_version` and provider versions in a `terraform` block
- Add HTTPS (ACM certificate + listener on 443)
- Add a CI workflow running `terraform fmt -check` and `terraform validate`
