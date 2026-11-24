# olivie-blog

`https://blog.olivie.space/` 的源码。Astro 静态站，写作只改 Markdown，发布一条命令。

内容：`src/content/blog/*.md`（一篇一个文件，头部是 `title` / `description` / `pubDate` / `tags`）。
页面：`src/pages/index.astro`（首页与页脚）、`src/pages/blog/[...slug].astro`（文章页）、`src/pages/rss.xml.ts`（订阅源）。
样式：`src/styles/global.css`。

## 两个仓库的分工

| 仓库 | 作用 |
| --- | --- |
| `17chemictech/blog`（本仓库） | 博客源码，写文章在这里 |
| `17chemictech/17chemictech.github.io` | 部署产物（GitHub Pages，`main` 根目录） |

部署仓库的内容由脚本生成，不要手改：根目录是博客，`/chat/` 是聊天 demo（来自 `../chat-whale/dist`），外加 `CNAME`（`blog.olivie.space`）和 `.nojekyll`。

## 常用命令

```bash
pnpm install      # 装依赖
pnpm dev          # 本地预览 http://localhost:4321
pnpm build        # 只构建，产物在 dist/
pnpm deploy       # 构建 + 组装 + 推到部署仓库（等价于 bash scripts/deploy.sh）
```

`pnpm deploy` 做四件事：构建 → 把 `dist/`、`../chat-whale/dist`（挂到 `/chat/`）、`CNAME`、`.nojekyll` 装进临时 staging → `rsync --delete` 覆盖部署仓库工作区 → commit + push。

可选环境变量：`DEPLOY_DIR`、`CHAT_DIST`、`DOMAIN`、`SKIP_PUSH=1`（只同步不推送，方便先看 diff）。

## 本机环境说明

这台机器没装系统 Node，脚本默认用：

- 运行时：`$HOME/DeepSeek/.toolchain/bin/node`（会话运行时副本，adhoc 重签名以避开 rspack/astro 原生模块的 Team ID 校验）
- pnpm：`$HOME/.dsh/dsh-runtimes/dsh-primary-runtime/dependencies/pnpm/bin/pnpm.mjs`

换成 `nvm` 或 `brew install node` 之后，这两个变量（`TOOLCHAIN_BIN`、`PNPM_MJS`）可以不改，脚本会优先用 PATH 里的 `node`。

## 历史

源码最初在 `17chemictech/personal-blog`（已归档），原先部署在 Cloudflare Pages。2026-11 迁到 GitHub Pages，源码搬到本仓库。
