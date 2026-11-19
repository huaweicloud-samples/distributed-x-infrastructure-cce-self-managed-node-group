#!/bin/bash
# CCE 自管理节点组 节点初始化脚本
#
# 节点注册机制说明：
# 公有云 CCE 不提供「节点注册命令」（控制台无该入口）。本模块的节点注册由
# huaweicloud_cce_node_attach 资源完成：AS 组拉起 ECS 实例后，按 server_id
# 将实例纳管进目标集群，CCE 在纳管过程中重置节点系统为标准镜像并自动完成
# 节点 RBAC 授权与 Kubernetes 标签下发。
#
# 本脚本仅承载节点首次启动的预置动作（预留扩展点），不执行任何注册命令。
set -o xtrace
