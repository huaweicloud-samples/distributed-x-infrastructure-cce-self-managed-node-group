# 部署指导

本指导说明如何用本仓库的 Terraform 模块，在华为云上部署一个 CCE 自管理节点组。部署前请确认已具备一个**已存在的 CCE 集群**（本模块以 data source 读取其信息，不负责创建集群）。

## 前置条件

- 华为云账号，具备创建弹性伸缩、ECS、IAM 委托、CCE 相关资源的权限。
- 已安装 Terraform（≥ 1.5）与华为云 Terraform Provider（huaweicloud ~> 1.96）。
- 已配置访问凭证（在华为云「我的凭证」页面获取 Access Key 并填入部署环境；凭据仅以变量传入，不写入任何文件）。
- 一个已存在的 CCE 集群，以及该集群所在 VPC 下的若干子网。

> **节点注册机制说明**：公有云 CCE 不提供「节点注册命令」。节点注册由 `huaweicloud_cce_node_attach` 资源完成——AS 组拉起 ECS 实例后，按 `server_id` 将实例纳管进集群，纳管过程重置节点系统为 CCE 标准镜像，并自动完成节点 RBAC 授权与 Kubernetes 标签下发。纳管要求实例 ≥ 2核4GiB、挂载一块 ≥ 20GiB 的数据盘、与集群同 VPC（模块默认配置已满足）。

## 步骤一：配置示例

进入示例目录（以区域部署 `examples/region/` 为例），按注释填好：

- `cce_cluster_name`：目标集群名
- `subnets`：集群 VPC 下的子网 ID 列表
- `image_id`：节点镜像 ID（建议 Ubuntu 22.04 等受纳管支持的公共镜像；cn-north-4 公共镜像区无 `CCE-*` 前缀镜像，模块默认的 `image_name_regex = "CCE-.*"` 会查空，故显式传 `image_id`）

## 步骤二：初始化

```bash
cd distributed-x-infrastructure-cce-self-managed-node-group/examples/region
terraform init
```

## 步骤三：部署（两阶段 apply）

节点注册依赖 AS 组拉起的 ECS 实例 ID，实例在第一次 apply 后才存在，因此分两阶段：

```bash
# 阶段一：创建密钥对、IAM 委托、AS 启动配置与 AS 组（AS 组随即拉起 ECS 节点）
terraform apply -target=huaweicloud_compute_keypair.node \
                -target=module.cce_self_managed_node_group

# 阶段二：等实例进入「运行中」后（约 3~5 分钟），重新 apply，
#         huaweicloud_cce_node_attach 按 server_id 纳管节点（单节点约 3~4 分钟）
terraform apply
```

部署完成后，输出 `scaling_group_id`、`scaling_configuration_id`、`agency_name`、`image_id` 等信息。

## 步骤四：验证节点加入集群

纳管完成后，在已配置好 kubeconfig 的环境中确认节点状态：

```bash
kubectl get nodes -l node.kubernetes.io/node-group=node-group-a
```

预期输出：节点处于 `Ready` 状态，且带 `node.kubernetes.io/node-group=node-group-a` 标签（标签由 attach 资源的 `labels` 参数下发）。

## 步骤五：扩缩容

- **扩容**：调大 `desired_capacity` 后执行两阶段 apply——第一次 apply 更新 AS 组拉起新实例，实例就绪后再次 apply 纳管新节点。
- **缩容**：调小 `desired_capacity`，AS 组按策略移除实例（纳管进集群的节点会随实例删除同步移除）。

## 步骤六：清理

释放资源，避免残留：

```bash
cd distributed-x-infrastructure-cce-self-managed-node-group/examples/region
terraform destroy
```

destroy 顺序：先移除集群中的纳管节点（`cce_node_attach`），再删除 AS 组及其 ECS 实例（`force_delete = true`）、启动配置、IAM 委托与密钥对。

## 示例

- 区域部署：`examples/region/`
- 边缘部署（CloudPond）：`examples/on-prem/`（含数据盘加密）

各示例目录内均为「两阶段 apply」流程，仅变量取值不同。
