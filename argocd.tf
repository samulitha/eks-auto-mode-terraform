################################################################################
# Argo CD (GitOps controller), installed from the official Argo Helm chart
################################################################################

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  # version  = "x.y.z"  # pin a chart version here for repeatable builds

  # Argo CD pulls several images and EKS Auto Mode may need to launch a node first
  timeout = 600

  # The UI/API stays private (ClusterIP). Reach it with: kubectl port-forward svc/argocd-server -n argocd 8080:443
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  depends_on = [module.eks]
}
