#!/usr/bin/env bash
# 博客一键发布：构建 Astro 站点 -> 组装 staging（博客在根、聊天 demo 在 /chat/）-> 推到 pages-out
#
#   pnpm deploy            # 或者 bash scripts/deploy.sh
#
# 可用环境变量覆盖默认值：
#   DEPLOY_DIR   部署仓库工作区（默认 ../pages-out）
#   CHAT_DIST    聊天 demo 的构建产物（默认 ../chat-whale/dist，不存在则跳过 /chat/）
#   DOMAIN       自定义域名（默认 blog.olivie.space）
#   SKIP_PUSH=1  只本地同步、不 commit/push
set -euo pipefail

BLOG_DIR="${BLOG_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DEPLOY_DIR="${DEPLOY_DIR:-$(cd "$BLOG_DIR/.." && pwd)/pages-out}"
CHAT_DIST="${CHAT_DIST:-$(cd "$BLOG_DIR/.." && pwd)/chat-whale/dist}"
DOMAIN="${DOMAIN:-blog.olivie.space}"

# 本机没装系统 Node：默认用 adhoc 重签名的会话运行时副本 + 该运行时自带的 pnpm
TOOLCHAIN_BIN="${TOOLCHAIN_BIN:-$HOME/DeepSeek/.toolchain/bin}"
PNPM_MJS="${PNPM_MJS:-$HOME/.dsh/dsh-runtimes/dsh-primary-runtime/dependencies/pnpm/bin/pnpm.mjs}"

step() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }

step "检查环境"
cd "$BLOG_DIR"
if ! command -v node >/dev/null 2>&1; then
  [ -d "$TOOLCHAIN_BIN" ] || { echo "找不到 node，也没有 $TOOLCHAIN_BIN"; exit 1; }
  export PATH="$TOOLCHAIN_BIN:$PATH"
fi
[ -f "$PNPM_MJS" ] || { echo "找不到 pnpm：$PNPM_MJS"; exit 1; }
node --version
node "$PNPM_MJS" --version

step "安装依赖"
node "$PNPM_MJS" install --frozen-lockfile

step "构建站点"
node "$PNPM_MJS" build

step "组装 staging"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
rsync -a "$BLOG_DIR/dist/" "$STAGE/"
if [ -d "$CHAT_DIST" ]; then
  mkdir -p "$STAGE/chat"
  rsync -a "$CHAT_DIST/" "$STAGE/chat/"
  echo "  已带上聊天 demo：$CHAT_DIST -> /chat/"
else
  echo "  跳过聊天 demo（没有 $CHAT_DIST），线上已有的 /chat/ 会被删掉！" >&2
  exit 1
fi
touch "$STAGE/.nojekyll"
printf '%s\n' "$DOMAIN" > "$STAGE/CNAME"
du -sh "$STAGE"

step "同步到部署仓库"
[ -d "$DEPLOY_DIR/.git" ] || { echo "$DEPLOY_DIR 不是 git 仓库"; exit 1; }
cd "$DEPLOY_DIR"
# 部署仓库是纯产物仓库：先对齐远端（GitHub 网页/Pages API 都可能往里写提交），
# 再整体覆盖，保证推送一定是 fast-forward。
git fetch -q origin main
git reset -q --hard origin/main
rsync -a --delete --exclude .git --exclude README.md "$STAGE/" "$DEPLOY_DIR/"
git status --short | head -20

if [ "${SKIP_PUSH:-0}" = "1" ]; then
  step "SKIP_PUSH=1，已停在 $DEPLOY_DIR（未提交）"
  exit 0
fi

if git diff --quiet && git diff --cached --quiet; then
  step "没有变化，无需发布"
  exit 0
fi

step "提交并推送"
git add -A
git -c user.name="$(git config user.name || echo chen)" -c user.email="$(git config user.email || echo chen@localhost)" \
  commit -m "deploy: blog.olivie.space $(date '+%Y-%m-%d %H:%M')"
git push origin main

step "完成"
printf '  站点：https://%s/\n  聊天：https://%s/chat/\n' "$DOMAIN" "$DOMAIN"
