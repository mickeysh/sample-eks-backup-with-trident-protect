module "aws_lb_controller_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"
  version = "1.10.0"
  name = "AmazonEKS_LBC_Role_${random_string.suffix.result}"

  attach_aws_lb_controller_policy = true
}

resource "aws_eks_pod_identity_association" "aws-lb-pod-identity-association" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = module.aws_lb_controller_pod_identity.iam_role_arn
}


resource "helm_release" "lb" {
  provider = helm.cluster1

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [
    aws_eks_pod_identity_association.aws-lb-pod-identity-association
  ]

  set = [
    {
    name  = "serviceAccount.create"
    value = "true"
    },
{
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
    },
    {
    name  = "clusterName"
    value = module.eks.cluster_name
    },
    {
    name  = "disableRestrictedSecurityGroupRules"
    value = "true"
    }
  ]
}

