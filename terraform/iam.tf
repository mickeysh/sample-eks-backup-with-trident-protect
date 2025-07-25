
resource "aws_iam_policy" "fsxn-csi-policy" {
  name        = "AmazonFSXNCSIDriverPolicy_${random_string.suffix.result}"
  description = "FSxN CSI Driver Policy"


  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "fsx:DescribeFileSystems",
          "fsx:DescribeVolumes",
          "fsx:CreateVolume",
          "fsx:RestoreVolumeFromSnapshot",
          "fsx:DescribeStorageVirtualMachines",
          "fsx:UntagResource",
          "fsx:UpdateVolume",
          "fsx:TagResource",
          "fsx:DeleteVolume"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : "secretsmanager:GetSecretValue",
        "Resource" : "${aws_secretsmanager_secret.fsxn_password_secret.arn}"
      }
    ]
  })
}


locals {
  trident_service_account_namespace = "trident"
  trident_service_account_name      = "trident-controller"
  ebs_service_account_namespace     = "kube-system"
  ebs_service_account_name          = "ebs-csi-controller-sa"
  trident_protect_service_account_namespace = "trident-protect"
  trident_protect_service_account_resourcerestore  = "trident-protect-resourcerestore"
  trident_protect_service_account_resourcedelete  = "trident-protect-resourcedelete"
  trident_protect_service_account_resourcebackup  = "trident-protect-resourcebackup"
  trident_protect_service_account_controller-manager  = "trident-protect-controller-manager"
}

resource "aws_secretsmanager_secret" "fsxn_password_secret" {
  name        = local.secret_name
  description = "FSxN CSI Driver Password"
}

resource "aws_secretsmanager_secret_version" "fsxn_password_secret" {
  secret_id = aws_secretsmanager_secret.fsxn_password_secret.id
  secret_string = jsonencode({
    username = "vsadmin"
    password = "${random_string.fsx_password.result}"
  })
}


data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "fsxn-csi-role" {
  name               = "AmazonEKS_FSXN_CSI_DriverRole_${random_string.suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role" "ebs-csi-role" {
  name               = "AmazonEKS_EBS_CSI_DriverRole_${random_string.suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "fsxn-csi-policy-attachment" {
  policy_arn = aws_iam_policy.fsxn-csi-policy.arn
  role       = aws_iam_role.fsxn-csi-role.name
}

resource "aws_iam_role_policy_attachment" "ebs-csi-policy-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs-csi-role.name
}

resource "aws_eks_pod_identity_association" "fsxn-csi-pod-identity-association" {
  cluster_name    = module.eks.cluster_name
  namespace       = local.trident_service_account_namespace
  service_account = local.trident_service_account_name
  role_arn        = aws_iam_role.fsxn-csi-role.arn
}



resource "aws_iam_policy" "trident-protect-policy" {
  name        = "TridentProtectPolicy_${random_string.suffix.result}"
  description = "Trident Protect Policy"


  policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": "s3:*",
                "Resource": "*"
            }
        ]
  })
}

resource "aws_iam_role" "trident-protect-role" {
  name               = "AmazonEKS_Trident_protect_DriverRole_${random_string.suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "trident-protect-policy-attachment" {
  policy_arn = aws_iam_policy.trident-protect-policy.arn
  role       = aws_iam_role.trident-protect-role.name
}

resource "aws_eks_pod_identity_association" "trident-protect-controller-manager-association" {
  cluster_name    = module.eks.cluster_name
  namespace       = local.trident_protect_service_account_namespace
  service_account = local.trident_protect_service_account_controller-manager
  role_arn        = aws_iam_role.trident-protect-role.arn
}

resource "aws_eks_pod_identity_association" "trident-protect-resourcerestore-association" {
  cluster_name    = module.eks.cluster_name
  namespace       = local.trident_protect_service_account_namespace
  service_account = local.trident_protect_service_account_resourcerestore
  role_arn        = aws_iam_role.trident-protect-role.arn
}

resource "aws_eks_pod_identity_association" "trident-protect-resourcebackup-association" {
  cluster_name    = module.eks.cluster_name
  namespace       = local.trident_protect_service_account_namespace
  service_account = local.trident_protect_service_account_resourcebackup
  role_arn        = aws_iam_role.trident-protect-role.arn
}

resource "aws_eks_pod_identity_association" "trident-protect-resourcedelete-association" {
  cluster_name    = module.eks.cluster_name
  namespace       = local.trident_protect_service_account_namespace
  service_account = local.trident_protect_service_account_resourcedelete
  role_arn        = aws_iam_role.trident-protect-role.arn
}