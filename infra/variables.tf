# -----------------------------------------------------------------------------
# 必填输入变量
# -----------------------------------------------------------------------------
variable "cce_cluster_name" {
  type        = string
  description = "(Required) 目标 CCE 集群名称（集群须已存在，模块以 data source 读取其 endpoint / CA / 安全组 / VPC / 子网）。"
}

variable "flavor" {
  type        = string
  description = "(Required) 节点 ECS 规格，例如 s6.large.2。"
}

variable "desired_capacity" {
  type        = number
  description = "(Required) 节点组期望节点数。"
}

variable "min_size" {
  type        = number
  description = "(Required) 节点组最小节点数。"
}

variable "max_size" {
  type        = number
  description = "(Required) 节点组最大节点数。"
}

variable "subnets" {
  type        = list(string)
  description = "(Required) 节点启动的子网 ID 列表；子网决定节点组所在的可用区。"
}

# -----------------------------------------------------------------------------
# 可选输入变量
# -----------------------------------------------------------------------------
variable "name" {
  type        = string
  description = "(Optional) 自管理节点组名称。默认由 name_prefix 生成唯一名。"
  default     = ""
}

variable "name_prefix" {
  type        = string
  description = "(Optional) 名称前缀，用于生成唯一节点组名。"
  default     = "node-group"
}

variable "tags" {
  type        = map(string)
  description = "(Optional) 应用到所有可打标签资源的标签。"
  default     = {}
}

variable "key_name" {
  type        = string
  description = "(Optional) 节点 ECS 绑定的密钥对名称；示例中同时供 huaweicloud_cce_node_attach 纳管时复用。"
  default     = null
}

variable "security_group_ids" {
  type        = list(string)
  description = "(Optional) 额外关联到节点 ECS 的安全组 ID 列表。模块自动关联 CCE 集群节点安全组。"
  default     = []
}

variable "image_id" {
  type        = string
  description = "(Optional) 节点 ECS 使用的 CCE 节点镜像 ID。可通过 IMS 公共镜像（CCE 节点镜像）获取；不填则使用 image_name_regex 匹配最新镜像。"
  default     = ""
}

variable "image_name_regex" {
  type        = string
  description = "(Optional) 当 image_id 为空时，按名称正则匹配 CCE 节点镜像，例如 \"CCE-.*\"。"
  default     = "CCE-.*"
}

variable "root_volume_size" {
  type        = number
  description = "(Optional) 节点系统盘大小（GB）。"
  default     = 50
}

variable "root_volume_type" {
  type        = string
  description = "(Optional) 节点系统盘类型：SSD / GPSSD / ESSD。"
  default     = "GPSSD"
}

variable "data_volume_size" {
  type        = number
  description = "(Optional) 节点数据盘大小（GB）。"
  default     = 100
}

variable "data_volume_type" {
  type        = string
  description = "(Optional) 节点数据盘类型：SSD / GPSSD / ESSD。"
  default     = "GPSSD"
}

variable "data_volume_encrypted" {
  type        = bool
  description = "(Optional) 是否加密节点数据盘。"
  default     = false
}

variable "kms_key_id" {
  type        = string
  description = "(Optional) 数据盘加密使用的 KMS 密钥 ID；data_volume_encrypted 为 true 时生效。"
  default     = null
}

variable "domain_name" {
  type        = string
  description = "(Optional) 账号域名（IAM 委托归属域）；使用 delegated_service_name=op_svc_ecs 时通常留空。"
  default     = ""
}

variable "agency_project_roles" {
  type        = list(string)
  description = "(Optional) 节点 ECS 委托绑定的项目级角色（OBS / SWR 等区域项目级服务）。"
  default     = ["OBS OperateAccess", "SWR Admin"]
}

variable "agency_domain_roles" {
  type        = list(string)
  description = "(Optional) 节点 ECS 委托绑定的租户级（全部项目）角色。KMS 为全局服务，启用数据盘加密（data_volume_encrypted=true）时必须在此绑定 KMS 数据面角色（KMS CMKFullAccess），否则 EVS 创建加密盘会报 EVS.2261 / AS.0027 授权失败；仅用 project_role 绑定 KMS 对全局服务不生效。"
  default     = ["KMS CMKFullAccess"]
}

variable "region" {
  type        = string
  description = "(Optional) 区域，用于委托的项目角色绑定。"
  default     = "cn-north-4"
}
