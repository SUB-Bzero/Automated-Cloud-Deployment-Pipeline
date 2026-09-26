#!/usr/bin/env python3
"""Generates docs/architecture.svg — the system architecture diagram.

Draws the traffic flow required by the capstone brief:
    Internet -> Cloud Host (ALB -> EC2 container) -> Database (RDS)
plus the CI/CD pipeline (GitHub Actions -> ECR/Terraform) and the
monitoring path (CloudWatch -> SNS -> email).
"""
import os

W, H = 1500, 1000
PARTS = []

SLATE = "#334155"
DARK = "#0F172A"
ARROW = "#475569"


def add(x):
    PARTS.append(x)


def rect(x, y, w, h, fill, stroke, rx=10, sw=2, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" '
        f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>')


def text(x, y, s, size=14, fill=DARK, anchor="middle", bold=False, family="Helvetica"):
    weight = ' font-weight="bold"' if bold else ""
    add(f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" '
        f'fill="{fill}" text-anchor="{anchor}"{weight}>{s}</text>')


def multiline(x, y, lines, size=14, fill=DARK, anchor="middle", bold_first=True, gap=None):
    gap = gap or (size + 5)
    for i, ln in enumerate(lines):
        text(x, y + i * gap, ln, size=size, fill=fill, anchor=anchor,
             bold=(bold_first and i == 0))


def box(x, y, w, h, title, lines=None, fill="#fff", stroke=SLATE, rx=10,
        tsize=15, size=12.5, tfill=None, dash=None):
    rect(x, y, w, h, fill, stroke, rx=rx, dash=dash)
    lines = lines or []
    n = len(lines) + 1
    block = (len(lines) * (size + 6)) + tsize
    y0 = y + (h - block) / 2 + tsize - 2
    text(x + w / 2, y0, title, size=tsize, fill=tfill or DARK, bold=True)
    for i, ln in enumerate(lines):
        text(x + w / 2, y0 + (i + 1) * (size + 6), ln, size=size, fill=tfill or "#374151")


def arrow(x1, y1, x2, y2, color=ARROW, label=None, lsize=12.5, dash=None,
          lx=None, ly=None, lfill=None, lanchor="middle"):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    add(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" '
        f'stroke-width="2"{d}/>')
    # arrowhead (explicit polygon — maximises renderer compatibility)
    import math
    ang = math.atan2(y2 - y1, x2 - x1)
    L, Wd = 11, 8
    bx, by = x2 - L * math.cos(ang), y2 - L * math.sin(ang)
    p1 = (x2, y2)
    p2 = (bx + Wd / 2 * math.sin(ang), by - Wd / 2 * math.cos(ang))
    p3 = (bx - Wd / 2 * math.sin(ang), by + Wd / 2 * math.cos(ang))
    add(f'<polygon points="{p1[0]},{p1[1]} {p2[0]},{p2[1]} {p3[0]},{p3[1]}" fill="{color}"/>')
    if label:
        lx = lx if lx is not None else (x1 + x2) / 2
        ly = ly if ly is not None else (y1 + y2) / 2 - 7
        text(lx, ly, label, size=lsize, fill=lfill or "#0F172A", anchor=lanchor, bold=True)


def badge(x, y, n, color="#1D4ED8"):
    r = 13
    add(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{color}"/>')
    add(f'<text x="{x}" y="{y + 4.5}" font-family="Helvetica" font-size="13" '
        f'fill="#ffffff" text-anchor="middle" font-weight="bold">{n}</text>')


# ---------------------------------------------------------------- canvas
add(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
    f'viewBox="0 0 {W} {H}">')
add(f'<rect width="{W}" height="{H}" fill="#F8FAFC"/>')

# Title
text(W / 2, 46, "Automated Cloud Deployment Pipeline — System Architecture", size=25, bold=True)
text(W / 2, 74, "Traffic flow:  Internet  \u2192  Cloud Host (ALB \u2192 EC2 container)  \u2192  Database (RDS PostgreSQL)",
     size=15, fill="#475569")

# ------------------------------------------------------------- top band
box(60, 120, 170, 78, "Developer",
    ["git push"], fill="#FFFFFF", stroke="#334155")
box(300, 110, 230, 92, "GitHub Repository",
    ["app + Terraform +", "CI/CD workflow files"], fill="#24292F", stroke="#24292F",
    tfill="#FFFFFF")

box(600, 100, 560, 200, "", fill="#F0F6FC", stroke="#0969DA")
text(880, 128, "GitHub Actions — CI/CD pipeline (.github/workflows/deploy.yml)",
     size=15, bold=True, fill="#0A306C")
stages = [
    ("1. Lint \u0026 Tests", "ESLint + node:test"),
    ("2. Terraform validate", "fmt + validate modules"),
    ("3. Docker build", "compose integration test"),
    ("4. terraform apply", "provision AWS infra"),
    ("5. Push to ECR", "tag = commit SHA"),
    ("6. App deploy", "SSH + health check"),
]
for i, (t, s) in enumerate(stages):
    cx = 620 + (i % 3) * 180
    cy = 148 + (i // 3) * 74
    rect(cx, cy, 172, 62, "#FFFFFF", "#54AEFF", rx=7, sw=1.5)
    text(cx + 86, cy + 25, t, size=13, bold=True)
    text(cx + 86, cy + 44, s, size=11.5, fill="#57606A")

arrow(230, 159, 300, 159, label="git push", ly=148, lx=265)
arrow(530, 156, 600, 156, label="trigger", ly=145, lx=565)

# ----------------------------------------------------------- AWS cloud
rect(250, 340, 1230, 620, "#FFF7ED", "#FF9900", rx=16, sw=2.5, dash="10 6")
text(270, 372, "AWS Cloud (us-east-1) — provisioned by Terraform",
     size=15, bold=True, fill="#9A3412", anchor="start")

# ECR
box(380, 392, 210, 84, "Amazon ECR",
    ["acdp-dev-app", "images: SHA + latest"], fill="#FDE68A", stroke="#B45309")

# State backend group (kept clear of the Internet -> ALB traffic path)
rect(300, 520, 270, 150, "#ECFDF5", "#059669", rx=10, dash="6 4")
box(320, 540, 230, 56, "S3 bucket — tfstate",
    ["versioned + encrypted"], fill="#DCFCE7", stroke="#16A34A", tsize=13.5, size=11.5)
box(320, 606, 230, 50, "DynamoDB — lock",
    ["state locking"], fill="#FED7AA", stroke="#EA580C", tsize=13.5, size=11.5)

# VPC
rect(700, 395, 750, 490, "#FFFBEB", "#D97706", rx=12, sw=2)
text(715, 422, "VPC 10.0.0.0/16", size=14, bold=True, anchor="start", fill="#92400E")

# Public subnets
rect(720, 435, 710, 205, "#DBEAFE", "#3B82F6", rx=10)
text(1425, 451, "Public subnets — AZ a \u0026 b  (10.0.1.0/24, 10.0.2.0/24) \u00b7 IGW + route to Internet",
     size=12.5, anchor="end", fill="#1E40AF")
box(740, 480, 260, 110, "Application Load Balancer",
    ["Internet-facing :80", "health check: GET /health", "forward to target :8080"],
    fill="#FDE68A", stroke="#B45309", tsize=14, size=12)
# EC2 host: title + details in the upper part, container box below
rect(1080, 470, 320, 145, "#FED7AA", "#EA580C")
text(1240, 494, "EC2 t3.micro (Ubuntu) — cloud host", size=13.5, bold=True)
text(1240, 513, "IAM role: ECR pull + SSM read", size=11.5, fill="#374151")
text(1240, 530, "user_data installs Docker", size=11.5, fill="#374151")
rect(1100, 545, 280, 56, "#FFFFFF", "#C2410C", rx=7)
text(1240, 566, "Docker container: acdp-app", size=12.5, bold=True)
text(1240, 585, "Node.js/Express on :8080", size=11.5, fill="#374151")

# Private subnets
rect(720, 675, 710, 195, "#DCFCE7", "#22C55E", rx=10)
text(735, 698, "Private subnets — AZ a \u0026 b  (10.0.11.0/24, 10.0.12.0/24) \u00b7 no Internet route",
     size=12.5, anchor="start", fill="#166534")
box(1080, 720, 320, 115, "Amazon RDS PostgreSQL",
    ["db.t3.micro \u00b7 encrypted", "username/password generated", "URL in SSM SecureString"],
    fill="#DBEAFE", stroke="#2563EB", tsize=14, size=12)
text(950, 790, "Security group: PostgreSQL :5432",
     size=11.5, fill="#374151")

# Internet
box(55, 452, 165, 96, "Internet",
    ["users / browsers", "HTTP requests"], fill="#FFFFFF", stroke="#334155")

# CloudWatch + SNS
box(310, 690, 260, 130, "Amazon CloudWatch",
    ["alarms: EC2 CPU >=80%", "ALB HTTP 5xx spike,", "unhealthy hosts, RDS CPU", "+ dashboard"],
    fill="#EDE9FE", stroke="#7C3AED", tsize=14, size=11.5)
box(310, 845, 260, 72, "Amazon SNS",
    ["email alert", "(subscription confirmed)"], fill="#FCE7F3", stroke="#DB2777", tsize=14, size=12)

# ------------------------------------------------------------- arrows
# pipeline -> AWS edge (terraform apply)
arrow(760, 300, 760, 338, label="", color="#B45309")
text(770, 322, "terraform apply \u2014 VPC \u00b7 EC2 \u00b7 ALB \u00b7 RDS \u00b7 ECR \u00b7 alarms",
     size=12.5, anchor="start", fill="#9A3412", bold=True)
badge(745, 320, "3", "#B45309")

# pipeline -> ECR (docker push)
arrow(490, 300, 490, 390, color="#B45309")
text(500, 350, "docker push (build \u0026 push stage)", size=12.5, anchor="start",
     fill="#9A3412", bold=True)
badge(475, 348, "4", "#B45309")

# pipeline -> state backend
arrow(655, 300, 655, 555, color="#059669")
arrow(655, 555, 572, 555, color="#059669")
text(665, 480, "Terraform remote state", size=12.5, anchor="start", fill="#065F46", bold=True)
badge(640, 470, "5", "#059669")

# pipeline -> EC2 (SSH deploy)
arrow(1120, 300, 1120, 468, color="#B45309", dash="7 5")
text(1130, 400, "SSH deploy: scripts/deploy.sh", size=12.5, anchor="start",
     fill="#9A3412", bold=True)
badge(1105, 395, "6", "#B45309")

# ECR -> EC2 (docker pull)
arrow(590, 434, 1078, 475, color="#B45309")

# Internet -> ALB
arrow(220, 500, 738, 500, color="#1D4ED8")
text(545, 496, "HTTP :80", size=13, fill="#1E3A8A", bold=True)
badge(463, 500, "1", "#1D4ED8")

# ALB -> EC2
arrow(1000, 562, 1078, 562, color="#1D4ED8")
text(1039, 548, ":8080", size=12.5, fill="#1E3A8A", bold=True)
badge(1010, 562, "2", "#1D4ED8")

# EC2 -> RDS
arrow(1240, 615, 1240, 718, color="#1D4ED8")
text(1250, 670, "PostgreSQL :5432", size=12.5, anchor="start", fill="#1E3A8A", bold=True)
badge(1225, 668, "3", "#1D4ED8")

# metrics -> CloudWatch
arrow(718, 760, 572, 760, color="#7C3AED", dash="6 4")
text(645, 746, "metrics", size=12, fill="#5B21B6", bold=True)

# CloudWatch -> SNS
arrow(440, 820, 440, 848, color="#DB2777")
text(450, 840, "alarm state", size=12, anchor="start", fill="#9D174D", bold=True)

# SNS -> email (out of AWS box)
arrow(570, 881, 640, 881, color="#DB2777")
text(648, 873, "email notification", size=12.5, anchor="start", fill="#9D174D", bold=True)

# Legend
rect(660, 893, 440, 56, "#FFFFFF", "#94A3B8", rx=8, sw=1)
text(675, 916, "Legend: blue = application traffic · orange = CI/CD · green = state",
     size=11, anchor="start", fill="#475569")
text(675, 934, "purple dashed = monitoring \u00b7 1-3 = numbered request flow",
     size=11, anchor="start", fill="#475569")

add("</svg>")

out = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "architecture.svg")
out = os.path.abspath(out)
with open(out, "w") as fh:
    fh.write("\n".join(PARTS))
print(f"wrote {out}")
