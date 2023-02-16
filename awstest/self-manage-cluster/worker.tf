## To use template_file, you will need to use template provider

locals {
  worker_instance_type = var.instance_type
  worker_keypair       = var.keypair_name
  worker_name          = "worker"
  number_of_workers    = var.number_of_workers
}

#   # You can put some variable here to render
# }

module "workers" {
  source = "../module/ec2_bootstrap"
  # bootstrap_script = data.template_file.woker_user_data.rendered
  # bootstrap_script = templatefile("../external/${local.cp_engine}/ubuntu20-k8s-worker.sh", {})
  ami = data.aws_ami.ubuntu.id
  bootstrap_script = templatefile("../external/templatescript.tftpl", {
    script_list : [
      templatefile("../external/script/awscli.sh", {}),
      templatefile("../external/script/k8s-containerd.sh", {}),
      templatefile("../external/script/config-crictl.sh", {}),
      contains(local.include_components, "docker") ? templatefile("../external/script/docker.sh", {}) : "",
      contains(local.include_components, "cri-docker") ? templatefile("../external/script/join-cluster-docker.sh", {}) : templatefile("../external/script/join-cluster.sh", {}),
    ]
  })

  # security_group_ids = setunion(module.common_sg.public_sg_ids, module.common_sg.specific_sg_ids)
  security_group_ids  = [module.public_ssh_http.public_sg_id, module.k8s_cluster_worker_sg.specific_sg_id, module.k8s_cluster_sg.specific_sg_id]
  keypair_name        = local.worker_keypair
  instance_type       = local.worker_instance_type
  name                = local.worker_name
  number_of_instances = local.number_of_workers

  // TODO: This will need to be more specific, but keep it simple for now
  role = aws_iam_role.worker_role.name
}


resource "aws_iam_role" "worker_role" {

  name = "role_${local.worker_name}"
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  /* This policy need attaching to  */
  inline_policy {
    name = "access_parameter_store"

    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "VisualEditor0",
          "Effect" : "Allow",
          "Action" : [
            "ssm:PutParameter",
            "ssm:LabelParameterVersion",
            "ssm:DeleteParameter",
            "ssm:UnlabelParameterVersion",
            "ssm:DescribeParameters",
            "ssm:RemoveTagsFromResource",
            "ssm:GetParameterHistory",
            "ssm:AddTagsToResource",
            "ssm:GetParametersByPath",
            "ssm:GetParameters",
            "ssm:GetParameter",
            "ssm:DeleteParameters"
          ],
          "Resource" : "*" // TODO: This will need to be more specific to secure, but just keep it simple for now
        },
      ]
    })
  }

  tags = {
    Name = "worker-role"
  }
}

#data "aws_iam_policy" "EBSCSIDriver" {
#  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
#}


#resource "aws_iam_role_policy_attachment" "EBSCSIDriver-role-policy-attach" {
#  count = local.include_ebs_csi_driver_policy ? 1 : 0
#  role  = aws_iam_role.worker_role.name

  # NOTE: This policy should be attached to Nodes which need to create EBS
  # Because this script is using control_plane_role for both control_plane and worker
  # -> Attach to this role
 # policy_arn = data.aws_iam_policy.EBSCSIDriver.arn
#}
