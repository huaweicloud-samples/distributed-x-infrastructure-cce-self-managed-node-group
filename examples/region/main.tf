# 在区域（Region）部署一个 CCE 自管理节点组
provider "huaweicloud" {
  region = "cn-north-4"
}

# —— 验证目标集群（已新建 cce-verify-cluster，cn-north-4）——
data "huaweicloud_cce_cluster" "target" {
  name = "cce-verify-cluster"
}

# 节点登录密钥对（attach 纳管时由 CCE 在重置系统过程中注入）
resource "huaweicloud_compute_keypair" "node" {
  name = "cce-verify-node-kp"
}

module "cce_self_managed_node_group" {
  source = "../../infra"

  cce_cluster_name = "cce-verify-cluster"
  flavor           = "s6.large.2"
  desired_capacity = 3
  min_size         = 1
  max_size         = 4

  # 区域子网决定节点组所在的可用区（取自 _cce_verify_cluster 的 apply 输出）
  subnets = [
    "c58eb060-0b05-406a-9845-bac7480bfa1a",
    "10aa016b-fdf5-4a0a-9d3c-e88631e23b99",
  ]

  # cn-north-4 公共镜像无 "CCE-*" 前缀镜像，模块默认 image_name_regex="CCE-.*" 会查空失败。
  # 自管理节点用受支持的通用 OS 镜像即可（后续由 cce_node_attach 纳管并重置为 CCE 标准镜像）。
  # 选用 Ubuntu 22.04 server 64bit（CCE 纳管受支持 OS）。
  image_id = "89ac6e18-d938-4b0d-b038-bcdb03a1b87f"

  # 节点 ECS 绑定密钥对（attach 纳管复用）
  key_name = huaweicloud_compute_keypair.node.name

  # 注册机制：公有云 CCE 无「节点注册命令」，节点注册由下方
  # huaweicloud_cce_node_attach（server_id 纳管）完成。
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
    "node.kubernetes.io/node-group" = "node-group-a"
  }

  # CCE 纳管后会给 ECS 打系统标签（如 CCE-Dynamic-Provisioning-Node），
  # 该标签由平台管理、普通账号无权修改，terraform 若重试改系统标签会报 403。
  # 由平台管理即可，terraform 不再触碰。
  lifecycle {
    ignore_changes = [tags]
  }
}
