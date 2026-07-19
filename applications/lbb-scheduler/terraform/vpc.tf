# ============================================================
# LBBS Terraform — VPC (Virtual Private Cloud)
# ============================================================
# Creates the NETWORK that all resources live in.
#
# WHAT IS A VPC?
#   Your own private section of AWS's network.
#   Like having your own private building in a shared office complex.
#   Nobody from outside can get in unless you open a door.
#
# ARCHITECTURE:
#   VPC: 10.0.0.0/16 (65,536 IP addresses)
#   ├── Public Subnet A:  10.0.1.0/24 (256 IPs) → Load Balancer
#   ├── Public Subnet B:  10.0.2.0/24 (256 IPs) → Load Balancer
#   ├── Private Subnet A: 10.0.10.0/24 (256 IPs) → Backend containers
#   ├── Private Subnet B: 10.0.11.0/24 (256 IPs) → Backend containers
#   ├── Data Subnet A:    10.0.20.0/24 (256 IPs) → Database
#   └── Data Subnet B:    10.0.21.0/24 (256 IPs) → Database
#
# WHY 3 LAYERS?
#   Public:  Internet can reach (load balancer only)
#   Private: No internet access IN, but can reach OUT (containers)
#   Data:    Completely isolated (database — most protected)
#
# UNDER THE HOOD:
#   VPC = POST ec2:CreateVpc
#   Subnet = POST ec2:CreateSubnet
#   Route Table = POST ec2:CreateRouteTable
#   NAT Gateway = POST ec2:CreateNatGateway
# ============================================================

# ── Get available AZs in the region ──
data "aws_availability_zones" "available" {
  state = "available"
}

# ── VPC ──
resource "aws_vpc" "lbbs" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc" }
}

# ── Internet Gateway ──
# The "front door" that connects VPC to the internet
resource "aws_internet_gateway" "lbbs" {
  vpc_id = aws_vpc.lbbs.id
  tags   = { Name = "${var.project_name}-igw" }
}

# ── Public Subnets (Load Balancer lives here) ──
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.lbbs.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.lbbs.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-b" }
}

# ── Private Subnets (Backend containers live here) ──
# No direct internet access — protected from outside
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.lbbs.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "${var.project_name}-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.lbbs.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = { Name = "${var.project_name}-private-b" }
}

# ── Data Subnets (Database lives here — most protected) ──
resource "aws_subnet" "data_a" {
  vpc_id            = aws_vpc.lbbs.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "${var.project_name}-data-a" }
}

resource "aws_subnet" "data_b" {
  vpc_id            = aws_vpc.lbbs.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = { Name = "${var.project_name}-data-b" }
}

# ── NAT Gateway ──
# Allows private subnets to reach the internet (for updates)
# but internet CANNOT reach private subnets
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "lbbs" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "${var.project_name}-nat" }
}

# ── Route Tables ──
# Public: Traffic goes to Internet Gateway (internet access)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lbbs.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lbbs.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Private: Traffic goes to NAT Gateway (outbound only)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lbbs.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.lbbs.id
  }
  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# ── Security Groups (Firewalls) ──

# ALB Security Group: Allow HTTP/HTTPS from internet
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP/HTTPS from internet to load balancer"
  vpc_id      = aws_vpc.lbbs.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

# Backend Security Group: Allow traffic ONLY from ALB
resource "aws_security_group" "backend" {
  name        = "${var.project_name}-backend-sg"
  description = "Allow traffic only from load balancer"
  vpc_id      = aws_vpc.lbbs.id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "FastAPI from ALB only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = { Name = "${var.project_name}-backend-sg" }
}

# Database Security Group: Allow traffic ONLY from backend
resource "aws_security_group" "database" {
  name        = "${var.project_name}-database-sg"
  description = "Allow PostgreSQL only from backend containers"
  vpc_id      = aws_vpc.lbbs.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
    description     = "PostgreSQL from backend only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-database-sg" }

  # ── Security Group 4: Bastion Host (SSH Jump Box) ──
# A bastion is the ONLY way to SSH into private resources.
# You SSH into the bastion first, then from bastion to backend.
# This prevents direct SSH access from the internet to any server.
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "SSH access from admin IPs only"
  vpc_id      = aws_vpc.lbbs.id

  # Only allow SSH from YOUR specific IP address
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_ip_addresses
    description = "SSH from admin IPs only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-bastion-sg" }
}

# ── Security Group 5: Frontend Containers ──
# Separate from backend — frontend only serves static files
resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-frontend-sg"
  description = "Allow traffic only from ALB to frontend containers"
  vpc_id      = aws_vpc.lbbs.id

  ingress {
    from_port       = 5173
    to_port         = 5173
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "React dev server from ALB only"
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Nginx from ALB only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-frontend-sg" }
}

# ── Security Group 6: Redis Cache ──
# If we add caching for session storage or API responses
resource "aws_security_group" "redis" {
  name        = "${var.project_name}-redis-sg"
  description = "Redis access only from backend containers"
  vpc_id      = aws_vpc.lbbs.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
    description     = "Redis from backend only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-redis-sg" }
}

# ── Security Group 7: VPC Endpoints ──
# Allows private subnets to reach AWS services (S3, Secrets Manager)
# WITHOUT going through the internet or NAT Gateway
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpc-endpoints-sg"
  description = "Allow backend to reach AWS services via private link"
  vpc_id      = aws_vpc.lbbs.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
    description     = "HTTPS from backend to AWS services"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-vpc-endpoints-sg" }
}

# ── Security Group 8: Monitoring (Prometheus/Grafana) ──
# For monitoring dashboards — only accessible from admin IPs
resource "aws_security_group" "monitoring" {
  name        = "${var.project_name}-monitoring-sg"
  description = "Monitoring dashboard access from admin IPs"
  vpc_id      = aws_vpc.lbbs.id

  # Grafana dashboard
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.admin_ip_addresses
    description = "Grafana from admin IPs"
  }

  # Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.admin_ip_addresses
    description = "Prometheus from admin IPs"
  }

  # Accept metrics from backend containers
  ingress {
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
    description     = "Metrics from backend"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-monitoring-sg" }
}

# ── Security Group 9: CI/CD Runner ──
# If we run a GitLab runner in AWS for faster pipelines
resource "aws_security_group" "cicd_runner" {
  name        = "${var.project_name}-cicd-runner-sg"
  description = "GitLab CI/CD runner — outbound only, no inbound"
  vpc_id      = aws_vpc.lbbs.id

  # NO ingress rules — nobody can connect TO the runner
  # Runner only makes OUTBOUND connections

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to GitLab and Docker registries"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for package downloads"
  }

  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.database.id]
    description     = "Database for running migrations"
  }

  tags = { Name = "${var.project_name}-cicd-runner-sg" }
}
}

