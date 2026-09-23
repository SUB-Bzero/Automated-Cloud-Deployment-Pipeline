# Automated Cloud Deployment Pipeline

Capstone project: a containerized **Node.js/Express + PostgreSQL** web application, deployed to **AWS** with **Terraform** for infrastructure provisioning and **GitHub Actions** for automated CI/CD, including health monitoring with **CloudWatch alarms**.

```
Internet ──▶ Application Load Balancer ──▶ EC2 (Docker container) ──▶ RDS PostgreSQL
                    (public subnets)        (public subnet)             (private subnets)
```

- **Application:** Express web app with a `/health` endpoint, a small items REST API backed by PostgreSQL, and a status home page that shows the running version and database connectivity.
- **Infrastructure (Terraform, modular):** VPC with public/private subnets + security groups, EC2 instance (Docker host), Application Load Balancer with `/health` health checks, RDS PostgreSQL in private subnets, ECR repository, S3 backend bucket + DynamoDB lock table, CloudWatch alarms + SNS email alerts + dashboard.
- **CI/CD (GitHub Actions):** lint → tests → terraform validate → docker build + compose integration test → `terraform apply` → build & push to ECR → SSH deploy to EC2 → ALB health verification with **automatic rollback** on failure.

---

## Repository structure

```
├── app/                        # Node.js/Express application
│   ├── Dockerfile              # multi-stage build (builder -> slim runtime)
│   ├── server.js               # entry point (waits for DB, migrates, serves)
│   ├── src/
│   │   ├── app.js              # express app factory + routes (/health, /api/items)
│   │   ├── config.js           # environment-based configuration
│   │   └── db.js               # PostgreSQL pool, migrations, queries
│   └── test/                   # node:test unit + integration tests (supertest)
├── docker-compose.yml          # local test stack: Web App + PostgreSQL
├── scripts/
│   └── deploy.sh               # runs on EC2: pull, swap container, health check, rollback
├── terraform/
│   ├── bootstrap/              # one-time: S3 state bucket + DynamoDB lock table
│   ├── modules/
│   │   ├── network/            # VPC, subnets, IGW, security groups
│   │   ├── ecr/                # container registry (+ lifecycle policy)
│   │   ├── database/           # RDS PostgreSQL + SSM SecureString connection URL
│   │   ├── compute/            # EC2 (Docker, via user_data) + ALB + target group
│   │   └── monitoring/         # CloudWatch alarms + SNS email + dashboard
│   └── envs/dev/               # environment root module wiring everything together
├── .github/workflows/
│   ├── deploy.yml              # full CI/CD pipeline (all stages)
│   └── bootstrap.yml           # one-time Terraform backend creation
├── docs/                       # architecture diagram, evidence screenshots, report
└── Makefile                    # convenience targets (make test, make run-local, ...)
```

## The application

| Endpoint | Description |
|---|---|
| `GET /health` | Health probe: JSON with app status, version, uptime and a live database check. Returns **200** when healthy, **503** when the database is unreachable. Used by Docker `HEALTHCHECK`, the ALB target group and the CI smoke test. |
| `GET /` | Human-friendly status page showing version, environment and database state. |
| `GET/POST/DELETE /api/items` | Small REST API persisted in PostgreSQL (`items` table). |

The app waits for the database at startup (RDS can take a few minutes to accept connections), runs an idempotent schema migration on boot, and shuts down gracefully on `SIGTERM`.

## Local development & testing

Requirements: Docker (for compose), or Node 22 + a local PostgreSQL for the unit tests.

```bash
# install dependencies
cd app && npm install && cd ..

# lint + unit tests (uses TEST_DATABASE_URL, defaults to localhost PostgreSQL)
cd app && npm run lint && npm test

# run the full local stack (Web App + PostgreSQL) and verify health
docker compose up --build --wait
curl http://localhost:8080/health
docker compose down -v
```

## Deployment to AWS (step by step)

### 0. Prerequisites
- An AWS account (the IAM policy needed by the pipeline is listed in `docs/aws-iam-policy.json`).
- A free-tier friendly setup: `t3.micro` EC2, `db.t3.micro` RDS, 20 GB gp3 volumes. The ALB is the only resource outside the free tier (~US$0.02/hour). Run `make destroy` when finished to avoid charges.

### 1. Create an EC2 key pair
In the AWS console: **EC2 → Key Pairs → Create key pair**, name it `acdp-key` (or change `key_name` in `terraform/envs/dev/terraform.tfvars`), download the `.pem` file.

### 2. Configure repository secrets (GitHub → Settings → Secrets and variables → Actions)

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key of the deployment IAM user |
| `AWS_SECRET_ACCESS_KEY` | Secret key of the deployment IAM user |
| `EC2_SSH_PRIVATE_KEY` | Contents of the `acdp-key.pem` file |

Optional repository variable: `AWS_REGION` (defaults to `us-east-1`).

### 3. Set your alert email
Edit `terraform/envs/dev/terraform.tfvars` and set `alarm_email` to your address. After the first deployment, confirm the SNS subscription email AWS sends you — otherwise alarms can't notify you.

### 4. Bootstrap the Terraform backend (once)
GitHub → **Actions → "Bootstrap Terraform backend" → Run workflow**. This creates the S3 state bucket (versioned, encrypted, public access blocked) and the DynamoDB lock table.

### 5. Deploy
Push to any branch (or to `main`). The pipeline runs:

1. **Lint & Tests** – ESLint + `node:test` against a real PostgreSQL service container.
2. **Terraform fmt & validate** – static validation of every module.
3. **Docker build & compose integration test** – builds the multi-stage image and boots app+DB with `docker compose`, then curls `/health`.
4. **Infrastructure Deploy** – `terraform apply` (VPC, subnets, security groups, EC2, ALB, RDS, ECR, CloudWatch alarms). The first run takes ~10 minutes, mostly RDS creation.
5. **Build & Push to ECR** – image is tagged with the commit SHA and `latest`.
6. **App Deploy** – copies `scripts/deploy.sh` to the EC2 host over SSH, pulls the new image, swaps the container, then verifies `GET /health` through the ALB. If the health check fails, the pipeline **automatically rolls back** to the previous image.

The app URL is printed in the job summary (`http://<alb-dns-name>`) and available via `terraform output app_url`.

> The AWS stages are automatically skipped (pipeline stays green) while the AWS secrets are not configured, so the CI stages can be validated independently.

## Monitoring & rollback

**CloudWatch alarms** (email via SNS, provisioned by `terraform/modules/monitoring`):

| Alarm | Trigger |
|---|---|
| `acdp-dev-ec2-cpu-high` | EC2 CPU utilization > 80% for 10 minutes |
| `acdp-dev-alb-5xx-errors` | More than 5 HTTP 5xx responses in 5 minutes |
| `acdp-dev-alb-unhealthy-hosts` | ALB health check (`/health`) failing for 3 minutes |
| `acdp-dev-rds-cpu-high` | RDS CPU utilization > 80% for 10 minutes |

A CloudWatch dashboard (`acdp-dev-dashboard`) shows all four metrics.

**Rollback options:**
- *Automatic:* a failed post-deploy health check makes the pipeline re-run `deploy.sh previous`, which redeploys the last known-good image tag.
- *Manual:* GitHub → Actions → **CI/CD Deploy** → Run workflow → set `image_tag` to `previous` (or any commit SHA).

## Teardown

```bash
cd terraform/envs/dev && terraform destroy
```

The bootstrap resources (S3 bucket + DynamoDB table) are removed by destroying `terraform/bootstrap` from a machine holding its local state, or manually in the console.

## Documentation

- `docs/architecture.png` — architecture diagram (traffic flow: Internet → ALB → EC2 → RDS, plus CI/CD and state management).
- `docs/Capstone_Report.docx` / `docs/Capstone_Report.pdf` — final capstone report (implementation steps, evidence figures, runbook).
- `docs/aws-iam-policy.json` — IAM policy for the deployment user.
- `docs/evidence/` — raw terminal output behind every evidence figure in the report.
