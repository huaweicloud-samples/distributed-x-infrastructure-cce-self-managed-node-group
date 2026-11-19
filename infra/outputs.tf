output "name" {
  description = "自管理节点组完整名称"
  value       = "${var.cce_cluster_name}-${local.node_group_name}"
}

output "scaling_group_id" {
  description = "弹性伸缩组 ID"
  value       = huaweicloud_as_group.node_group.id
}

output "scaling_configuration_id" {
  description = "启动配置 ID"
  value       = huaweicloud_as_configuration.node.id
}

output "agency_name" {
  description = "节点 IAM 委托名称"
  value       = huaweicloud_identity_agency.node.name
}

output "image_id" {
  description = "选用的 CCE 节点镜像 ID"
  value       = local.image_id
}

output "cluster_endpoint" {
  description = "目标 CCE 集群 API endpoint"
  value       = data.huaweicloud_cce_cluster.selected.endpoints
  sensitive   = true
}
