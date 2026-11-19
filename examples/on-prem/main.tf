# 在 CloudPond 智能边缘小站部署自管理节点组
provider "huaweicloud" {
  region = "cn-north-4"
}

# 目标集群（须已存在，且 VPC 打通 CloudPond 边缘可用区）
data "huaweicloud_cce_cluster" "target" {
  name = "my-cce-cluster"
}

# 节点登录密钥对（attach 纳管时由 CCE 在重置系统过程中注入）
resource "huaweicloud_compute_keypair" "node" {
  name = "cloudpond-node-kp"
}

module "cce_self_managed_node_group" {
  source = "../../infra"

  cce_cluster_name = "my-cce-cluster"
  flavor           = "s6.large.2"
  desired_capacity = 1
  min_size         = 1
  max_size         = 1

  # 节点子网落在 CloudPond 边缘可用区
  subnets = ["<cloudpond-edge-subnet-id>"]

  # 节点 ECS 绑定密钥对（attach 纳管复用）
  key_name = huaweicloud_compute_keypair.node.name

  # 边缘场景建议对数据盘全量加密
  data_volume_encrypted = true
  kms_key_id            = "<kms-key-id>"
}

# —— AS 组拉起的 ECS 实例（apply 模块后才有数据，需两阶段 apply）——
data "huaweicloud_as_instances" "nodes" {
  scaling_group_id = module.cce_self_managed_node_group.scaling_group_id
  life_cycle_state = "INSERVICE"
  health_status    = "NORMAL"
}

# —— 节点注册：将 AS 组拉起的 ECS 纳管进 CCE 集群 ——
# os 必填，纳管过程会重置节点系统为 CCE 标准镜像并自动完成 RBAC 授权。
resource "huaweicloud_cce_node_attach" "nodes" {
  for_each = toset(data.huaweicloud_as_instances.nodes.instances[*].instance_id)

  cluster_id = data.huaweicloud_cce_cluster.target.id
  server_id  = each.value
  os         = "Ubuntu 22.04"
  key_pair   = huaweicloud_compute_keypair.node.name

  labels = {
    "node.kubernetes.io/on-prem"    = "cloudpond-site-a"
    "node.kubernetes.io/node-group" = "node-group-a"
  }

  # CCE 纳管后会给 ECS 打系统标签（如 CCE-Dynamic-Provisioning-Node），
  # 该标签由平台管理、普通账号无权修改，terraform 若重试改系统标签会报 403。
  # 由平台管理即可，terraform 不再触碰。
  lifecycle {
    ignore_changes = [tags]
  }
}
