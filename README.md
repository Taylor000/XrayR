# XrayR v0.9.4 自用归档

本仓库固定保留 **XrayR v0.9.4**，不跟随上游更新，也不使用 GitHub Actions。

## 用途

本仓库供 `Taylor000/tool` 工具箱安装 XrayR 使用。Linux 安装包直接保存在本仓库，不依赖原项目 Release。

工具箱入口：

```bash
curl -fsSL https://raw.githubusercontent.com/Taylor000/tool/master/tool.sh -o /usr/local/bin/tool
chmod +x /usr/local/bin/tool
tool
```

进入菜单后选择 XrayR 自用冻结版即可。

## 归档内容

- 源码：上游标签 `v0.9.4`（提交 `944e8cd6a8376d6daa86e9e445b8afb8264c0b33`）
- Linux amd64：`release/v0.9.4/XrayR-linux-64.zip`
- Linux arm64：`release/v0.9.4/XrayR-linux-arm64-v8a.zip`
- Linux s390x：`release/v0.9.4/XrayR-linux-s390x.zip`
- 校验：`release/v0.9.4/SHA256SUMS`

安装前请准备面板地址、节点 ID 和通讯密钥。该版本已停止维护，只用于兼容现有环境。

原项目采用 Mozilla Public License 2.0，许可内容见 [LICENSE](./LICENSE)。
