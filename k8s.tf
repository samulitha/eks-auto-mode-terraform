# Authenticates to the cluster using the AWS CLI (same identity that ran terraform)
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
  }
}

# Test workload: forces EKS Auto Mode to launch an EC2 node
resource "kubernetes_deployment_v1" "inflate" {
  metadata {
    name = "inflate"
    labels = {
      app = "inflate"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "inflate"
      }
    }

    template {
      metadata {
        labels = {
          app = "inflate"
        }
      }

      spec {
        container {
          name  = "inflate"
          image = "public.ecr.aws/eks-distro/kubernetes/pause:3.7"

          resources {
            requests = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }
  }

  # Don't wait for pods to become ready; node launch can take a couple of minutes
  wait_for_rollout = false
  depends_on = [module.eks]
}
