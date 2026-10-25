################################################################################
# ACK S3 controller: lets you create S3 buckets as Kubernetes resources
################################################################################

locals {
  ack_namespace       = "ack-system"
  ack_s3_service_acct = "ack-s3-controller"
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    }
  }
}

# IAM role the controller pod assumes through EKS Pod Identity
# (the Pod Identity agent is built into EKS Auto Mode, no add-on needed)
data "aws_iam_policy_document" "ack_s3_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ack_s3" {
  name               = "${var.cluster_name}-ack-s3-controller"
  assume_role_policy = data.aws_iam_policy_document.ack_s3_assume.json
  tags               = local.tags
}

# Broad for learning; scope this down to specific buckets for real use
resource "aws_iam_role_policy_attachment" "ack_s3" {
  role       = aws_iam_role.ack_s3.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Links the Kubernetes service account to the IAM role
resource "aws_eks_pod_identity_association" "ack_s3" {
  cluster_name    = module.eks.cluster_name
  namespace       = local.ack_namespace
  service_account = local.ack_s3_service_acct
  role_arn        = aws_iam_role.ack_s3.arn
}

# The controller itself (public ECR OCI chart)
resource "helm_release" "ack_s3" {
  name             = "ack-s3-controller"
  namespace        = local.ack_namespace
  create_namespace = true

  repository = "oci://public.ecr.aws/aws-controllers-k8s"
  chart      = "s3-chart"
  # version  = "x.y.z"  # pin a chart version here for repeatable builds

  set {
    name  = "aws.region"
    value = var.region
  }

  set {
    name  = "serviceAccount.name"
    value = local.ack_s3_service_acct
  }

  depends_on = [
    module.eks,
    aws_eks_pod_identity_association.ack_s3,
    aws_iam_role_policy_attachment.ack_s3,
  ]
}
