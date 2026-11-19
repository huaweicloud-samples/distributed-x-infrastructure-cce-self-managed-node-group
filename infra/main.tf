# ============================================================================
# CCE 自管理节点组 Terraform 模块
# 用华为云基础原语拼装一个自管理节点组：
#   弹性伸缩 AS 组 + 启动配置 + IAM 委托 + CCE 节点镜像 + 节点注册 user_data
# 保留「由用户用基础资源自行拼装节点组」的教学主题。
# =========================================================================

# -----------------------------------------------------------------------------
# 现有 CCE 集群（data source）
# -----------------------------------------------------------------------------
data "huaweicloud_cce_cluster" "selected" {
  name = var.cce_cluster_name
}

# -----------------------------------------------------------------------------
# 节点镜像（CCE 节点镜像 / IMS 公共镜像）
# -----------------------------------------------------------------------------
data "huaweicloud_images_image" "selected" {
  count = var.image_id == "" ? 1 : 0

  name_regex  = var.image_name_regex
  most_recent = true
}

locals {
  image_id = var.image_id != "" ? var.image_id : data.huaweicloud_images_image.selected[0].id

  # 节点组名称（唯一）
  node_group_name = coalesce(var.name, "${var.name_prefix}-${random_id.name_suffix.hex}")

  # 节点安全组：自动关联 CCE 集群节点安全组 + 用户额外安全组
  security_group_ids = concat(
    [data.huaweicloud_cce_cluster.selected.security_group_id],
    var.security_group_ids
  )
}

resource "random_id" "name_suffix" {
  byte_length = 8
}

# -----------------------------------------------------------------------------
# 节点 IAM 委托（Agency）
# 以 delegated_service_name = "op_svc_ecs" 表示 ECS 服务可假定该委托，
# 并绑定项目角色（OBS / SWR / KMS 等），对应节点所需的服务访问授权。
# 注：启用数据盘加密时 KMS 权限不可省略，否则 EVS 创建加密盘会报 EVS.2261。
# -----------------------------------------------------------------------------
resource "huaweicloud_identity_agency" "node" {
  name        = "${var.cce_cluster_name}-${local.node_group_name}-agency"
  description = "Agency for CCE self-managed node group to access OBS/SWR/KMS"
  duration    = "FOREVER"

  # ECS 服务假定此委托（华为云 IAM 中 ECS 云服务内部账号为 op_svc_ecs）
  delegated_service_name = "op_svc_ecs"

  # KMS 为全局服务，其角色必须在租户级（全部项目）绑定，project_role 对全局服务不生效
  domain_roles = var.agency_domain_roles

  dynamic "project_role" {
    for_each = length(var.agency_project_roles) > 0 ? [1] : []
    content {
      project = var.region
      roles   = var.agency_project_roles
    }
  }
}

# -----------------------------------------------------------------------------
# 启动配置（描述节点 ECS 的规格、镜像、磁盘、user_data）
# -----------------------------------------------------------------------------
resource "huaweicloud_as_configuration" "node" {
  scaling_configuration_name = "${var.cce_cluster_name}-${local.node_group_name}"

  instance_config {
    flavor   = var.flavor
    image    = local.image_id
    key_name = var.key_name

    # 安全组以列表形式传入（自动关联集群节点安全组 + 用户安全组）
    security_group_ids = local.security_group_ids

    # 节点注册由 huaweicloud_cce_node_attach（server_id 纳管）完成，
    # user_data 仅承载首次启动预置动作，不执行注册命令。
    user_data = base64encode(file("${path.module}/user_data.sh"))

    # 系统盘
    disk {
      size        = var.root_volume_size
      volume_type = var.root_volume_type
      disk_type   = "SYS"
    }

    # 数据盘（提供 kms_key_id 即启用加密）
    disk {
      size        = var.data_volume_size
      volume_type = var.data_volume_type
      disk_type   = "DATA"
      kms_id      = var.data_volume_encrypted ? var.kms_key_id : null
    }
  }
}

# -----------------------------------------------------------------------------
# 弹性伸缩组（管理节点组的扩缩容与生命周期）
# -----------------------------------------------------------------------------
resource "huaweicloud_as_group" "node_group" {
  scaling_group_name       = "${var.cce_cluster_name}-${local.node_group_name}"
  scaling_configuration_id = huaweicloud_as_configuration.node.id

  # 节点 ECS 通过此委托获得访问 OBS / SWR / KMS 等服务的权限
  agency_name = huaweicloud_identity_agency.node.name

  desire_instance_number = var.desired_capacity
  min_instance_number    = var.min_size
  max_instance_number    = var.max_size

  vpc_id = data.huaweicloud_cce_cluster.selected.vpc_id

  # destroy 时强制连带实例删除（min_size=1 时不传 force_delete 会被拒）
  force_delete = true

  dynamic "networks" {
    for_each = var.subnets
    content {
      id = networks.value
    }
  }

  dynamic "security_groups" {
    for_each = local.security_group_ids
    content {
      id = security_groups.value
    }
  }

  tags = merge(
    var.tags,
    {
      # 弹性伸缩组标签键长度上限 36 字符，kubernetes.io/cluster/<name> 易超限，改用短键保留集群关联语义
      "cce-cluster" = var.cce_cluster_name
    }
  )
}
