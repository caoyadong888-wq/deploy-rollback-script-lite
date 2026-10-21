# SSH Deploy with Rollback (lite)

## English

### Purpose

A free slice of the release-directory deploy script. `deploy.sh` defaults to `--dry-run` and prints `rsync` and `ssh` steps for a single `current -> releases/<id>` symlink. `--lab --apply` copies a local source tree and updates that symlink. It does not call ssh.

The full pack adds `previous`, shared path links, prune, and `rollback.sh`.

### Deliverables

- `CHANGELOG.md` — version note for this lite subset.
- `deliverables/deploy.sh` — dry-run plan and local lab publish.
- `deliverables/deploy.env.example` — sample host `app.example.com`.
- `examples/shop/deploy.env` — filled host `shop.example.com`.
- `examples/shop/public/index.html` — one shop page.
- `examples/shop/public/css/site.css` — styles for that page.

### Quick start

```bash
bash deliverables/deploy.sh --dry-run \
  --config examples/shop/deploy.env \
  --src examples/shop/public \
  --release-id 20261021T010000Z
bash deliverables/deploy.sh --lab --apply \
  --config examples/shop/deploy.env \
  --base /tmp/shop-lab \
  --src examples/shop/public \
  --release-id 20261021T010000Z
```

`--apply` without `--lab` exits with a refusal. This lite script never runs ssh.

### Requirements

bash 4.4 or newer, rsync 3.x, and GNU coreutils. OpenSSH is not required here. The printed flags are examples. Check upstream docs before you reuse them on a server.

## 中文

### 用途

发布目录脚本的免费子集。`deploy.sh` 默认 `--dry-run`，为一条 `current -> releases/<id>` 打印 `rsync` 和 `ssh` 步骤。`--lab --apply` 在本地复制文件并更新这个链接。它不调用 ssh。

完整版还有 `previous`、共享路径链接、旧发布清理，以及 `rollback.sh`。

### 交付清单

- `CHANGELOG.md` — 本精简子集的版本说明。
- `deliverables/deploy.sh` — dry-run 计划与本地实验发布。
- `deliverables/deploy.env.example` — 示例主机 `app.example.com`。
- `examples/shop/deploy.env` — 填好的主机 `shop.example.com`。
- `examples/shop/public/index.html` — 一页商店页面。
- `examples/shop/public/css/site.css` — 该页面的样式。

### 快速开始

```bash
bash deliverables/deploy.sh --dry-run \
  --config examples/shop/deploy.env \
  --src examples/shop/public \
  --release-id 20261021T010000Z
bash deliverables/deploy.sh --lab --apply \
  --config examples/shop/deploy.env \
  --base /tmp/shop-lab \
  --src examples/shop/public \
  --release-id 20261021T010000Z
```

不带 `--lab` 的 `--apply` 会拒绝执行。这个精简脚本不会运行 ssh。

### 环境要求

bash 4.4 或更高、rsync 3.x、GNU coreutils。这里不需要 OpenSSH。打印出来的标志是示例。拿到服务器上使用之前请 check upstream docs。

Full version: GUMROAD_URL
