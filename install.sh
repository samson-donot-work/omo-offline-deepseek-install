#!/usr/bin/env bash
# oh-my-openagent 离线安装（OpenCode V2 · 内网无外网）
#
# 统一插件目录规范（所有插件共用，不再每个插件在 $HOME 建点目录）:
#   $ROOT/plugins/<插件>/          插件本体，V2 自动发现（每个直接子目录一个插件）
#   $ROOT/plugin-data/<插件>/      该插件的配置/状态/清单
#   ~/.omo -> $ROOT/plugin-data/oh-my-openagent     仅当插件硬编码了 $HOME 路径时的兼容软链
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${OMO_ROOT:-$(printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}")/opencode}"
PLUGIN="oh-my-openagent"
TARGET="$ROOT/plugins/$PLUGIN"
DATA="$ROOT/plugin-data/$PLUGIN"
LEGACY_LINK="$HOME/.omo"
VERSION="$(cat "$HERE/VERSION" 2>/dev/null || echo unknown)"

say()  { printf '[omo] %s\n' "$*"; }
warn() { printf '[warn] %s\n' "$*"; }
die()  { printf '[error] %s\n' "$*" >&2; exit 1; }

[ -f "$HERE/payload/oh-my-openagent/dist/index.js" ] || die "payload 缺失，请确认解包完整"
command -v cp >/dev/null 2>&1 || die "缺少 cp 命令"

say "版本: $VERSION"
say "插件根: $ROOT"
say "插件包: $TARGET"
say "插件数据: $DATA"

# 1) 插件本体
rm -rf "$TARGET"
mkdir -p "$TARGET"
cp -a "$HERE/payload/oh-my-openagent/." "$TARGET/"
[ -f "$TARGET/dist/index.js" ] || die "安装后缺少 dist/index.js"
[ -f "$TARGET/package.json" ] || die "安装后缺少 package.json（V2 靠它识别插件包）"
[ -f "$TARGET/node_modules/zod/package.json" ] || warn "缺少内嵌 zod，插件可能无法加载"

# 2) 插件数据目录 + 配置迁移
mkdir -p "$DATA"
if [ -f "$DATA/omo.jsonc" ]; then
  warn "$DATA/omo.jsonc 已存在，保留（模板见 payload/omo.jsonc.example）"
elif [ -f "$LEGACY_LINK/omo.jsonc" ] && [ ! -L "$LEGACY_LINK" ]; then
  cp -a "$LEGACY_LINK/omo.jsonc" "$DATA/omo.jsonc"
  say "已把旧的 ~/.omo/omo.jsonc 迁移到 $DATA/omo.jsonc"
else
  cp "$HERE/payload/omo.jsonc.example" "$DATA/omo.jsonc"
  say "已写入 $DATA/omo.jsonc（agent 模型映射: my_deepseek/*）"
fi

# 3) 兼容路径：OMO 硬编码读取 $HOME/.omo/omo.jsonc
link_mode="symlink"
if [ -d "$LEGACY_LINK" ] && [ ! -L "$LEGACY_LINK" ]; then
  # 真实目录：内容并入 DATA 后再做软链，避免两份配置漂移
  for entry in "$LEGACY_LINK"/* "$LEGACY_LINK"/.[!.]*; do
    [ -e "$entry" ] || continue
    name="$(basename "$entry")"
    [ -e "$DATA/$name" ] || mv "$entry" "$DATA/$name"
  done
  rm -rf "$LEGACY_LINK"
  say "已把旧的 ~/.omo 目录并入 $DATA"
fi

rm -f "$LEGACY_LINK"
if ln -s "$DATA" "$LEGACY_LINK" 2>/dev/null; then
  say "已建立软链 ~/.omo -> $DATA"
else
  # 某些文件系统（或未提权的 Windows）不允许建软链 → 退化为真实目录 + 配置副本
  link_mode="copy"
  mkdir -p "$LEGACY_LINK"
  cp -f "$DATA/omo.jsonc" "$LEGACY_LINK/omo.jsonc"
  warn "该文件系统不支持软链，已退化为 ~/.omo 真实目录 + 配置副本"
  warn "改动配置时请以 $DATA/omo.jsonc 为准，再同步到 ~/.omo/omo.jsonc"
fi
printf '%s\n' "$link_mode" > "$DATA/.omo-link-mode"

# 4) 安装清单
cat > "$DATA/manifest.json" <<EOF
{
  "plugin": "$PLUGIN",
  "version": "$VERSION",
  "installed_at": "$(date -Is 2>/dev/null || date)",
  "package_dir": "$TARGET",
  "data_dir": "$DATA",
  "config": "$DATA/omo.jsonc",
  "installer": "omo-offline-bundle"
}
EOF

# 5) 常见误配置提醒
for f in "$ROOT/opencode.json" "$ROOT/opencode.jsonc"; do
  [ -f "$f" ] || continue
  grep -q '"oh-my-openagent"' "$f" 2>/dev/null && warn "$f 里仍有 \"oh-my-openagent\" npm 条目：离线会联网安装失败，请删除（本地目录方式已足够）"
  grep -qE '^[^/]*"plugin"[[:space:]]*:' "$f" 2>/dev/null && warn "$f 使用了单数键 \"plugin\"：V2 只认复数 \"plugins\""
done
[ -n "${DEEPSEEK_API_KEY:-}" ] || warn "未检测到 DEEPSEEK_API_KEY"

# 6) 清理旧版 V1 加载器
if [ -f "$ROOT/plugins/omo-openagent.js" ]; then
  rm -f "$ROOT/plugins/omo-openagent.js"
  say "已清理旧版 V1 加载器 plugins/omo-openagent.js"
fi

cat <<DONE

安装完成。

  export DEEPSEEK_API_KEY=sk-xxxx
  opencode                      # /agents 里应出现 sisyphus / oracle / prometheus 等

目录（所有插件统一在这里，$HOME 下不再新增点目录）:
  $ROOT/plugins/            插件包（V2 自动发现）
  $ROOT/plugin-data/        插件配置与状态
  ~/.omo                    -> $DATA   （OMO 硬编码路径的兼容软链）

后续再装别的插件，照同样规范放：$ROOT/plugins/<name>/ + $ROOT/plugin-data/<name>/

卸载: $HERE/uninstall.sh          # 保留配置；连配置一起删: $HERE/uninstall.sh --purge
DONE

if [ -n "${OMO_ROOT:-}" ]; then
cat <<DONE

你使用了自定义 OMO_ROOT，需要确认 opencode 的 plugins 配置能指向它，例如:
  "plugins": ["$TARGET"]

DONE
fi
