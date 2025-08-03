terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }

  backend "s3" {
    bucket = "mlops-terraform-state"
    key    = "gpu-cluster/terraform.tfstate"
    region = "us-west-2"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "mlops-portfolio"
      ManagedBy   = "terraform"
      Owner       = "mlops-team"
    }
  }
}

# VPC Configuration for GPU Cluster
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = false
  enable_vpn_gateway     = false
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # Enable flow logs for security monitoring
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

# EKS Cluster with GPU Node Groups
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 19.15"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true
  
  # Enable cluster logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # GPU Node Groups
  eks_managed_node_groups = {
    h100_nodes = {
      name = "h100-gpu-nodes"
      
      instance_types = ["p5.48xlarge"]  # H100 instances
      capacity_type  = "ON_DEMAND"
      
      min_size     = 1
      max_size     = 10
      desired_size = 2

      # Enable GPU support
      ami_type = "AL2_x86_64_GPU"
      
      # Large storage for models
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 500
            volume_type          = "gp3"
            iops                 = 3000
            throughput           = 125
            encrypted            = true
            delete_on_termination = true
          }
        }
      }

      # Taints for GPU workloads only
      taints = {
        gpu = {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      labels = {
        "accelerator"           = "h100"
        "node-type"            = "gpu-worker"
        "workload"             = "ai-inference"
        "kubernetes.io/arch"   = "amd64"
      }

      tags = {
        NodeType = "GPU-H100"
        Purpose  = "AI-Inference"
      }
    }

    cpu_nodes = {
      name = "cpu-worker-nodes"
      
      instance_types = ["c6i.8xlarge"]
      capacity_type  = "SPOT"
      
      min_size     = 2
      max_size     = 20
      desired_size = 4

      labels = {
        "node-type"          = "cpu-worker"
        "workload"           = "general"
        "kubernetes.io/arch" = "amd64"
      }

      tags = {
        NodeType = "CPU-Worker"
        Purpose  = "General-Workload"
      }
    }
  }

  # Fargate profiles for system workloads
  fargate_profiles = {
    karpenter = {
      name = "karpenter"
      selectors = [
        {
          namespace = "karpenter"
        }
      ]
    }
    
    kube_system = {
      name = "kube-system"
      selectors = [
        {
          namespace = "kube-system"
        }
      ]
    }
  }

  # Cluster access configuration
  manage_aws_auth_configmap = true
  
  aws_auth_roles = [
    {
      rolearn  = aws_iam_role.eks_admin.arn
      username = "cluster-admin"
      groups   = ["system:masters"]
    }
  ]

  aws_auth_users = var.cluster_admin_users
}

# IAM Role for EKS Cluster Administration
resource "aws_iam_role" "eks_admin" {
  name = "${var.cluster_name}-eks-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_admin" {
  role       = aws_iam_role.eks_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EFS for persistent model storage
resource "aws_efs_file_system" "model_storage" {
  creation_token   = "${var.cluster_name}-model-storage"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  tags = {
    Name    = "${var.cluster_name}-model-storage"
    Purpose = "AI-Model-Storage"
  }
}

resource "aws_efs_mount_target" "model_storage" {
  count           = length(module.vpc.private_subnets)
  file_system_id  = aws_efs_file_system.model_storage.id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_security_group" "efs" {
  name_prefix = "${var.cluster_name}-efs-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-efs-sg"
  }
}

data "aws_caller_identity" "current" {}