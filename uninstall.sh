#!/usr/bin/env bash
# 卸载 oh-my-openagent（统一目录规范版）
set -euo pipefail
ROOT="${OMO_ROOT:-$(printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}")/opencode}"
PLUGIN="oh-my-openagent"
TARGET="$ROOT/plugins/$PLUGIN"
DATA="$ROOT/plugin-data/$PLUGIN"
LEGACY_LINK="$HOME/.omo"
say() { printf '[omo] %s\n' "$*"; }

[ -d "$TARGET" ] && rm -rf "$TARGET" && say "已删除插件包 $TARGET"
[ -f "$ROOT/plugins/omo-openagent.js" ] && rm -f "$ROOT/plugins/omo-openagent.js" && say "已删除旧版 V1 加载器"

if [ -L "$LEGACY_LINK" ]; then
  rm -f "$LEGACY_LINK" && say "已移除兼容软链 ~/.omo"
fi

if [ "${1:-}" = "--purge" ]; then
  if [ -f "$DATA/.omo-link-mode" ] && [ "$(cat "$DATA/.omo-link-mode")" = "copy" ] && [ -d "$LEGACY_LINK" ] && [ ! -L "$LEGACY_LINK" ]; then
    rm -f "$LEGACY_LINK/omo.jsonc"
    rmdir "$LEGACY_LINK" 2>/dev/null || true
    say "已清理兼容目录 ~/.omo/omo.jsonc"
  fi
  if [ -d "$DATA" ]; then rm -rf "$DATA"; say "已删除插件数据 $DATA（含 omo.jsonc）"; fi
  rmdir "$ROOT/plugin-data" 2>/dev/null || true
else
  say "已保留配置 $DATA/omo.jsonc（彻底删除: --purge）"
fi
say "完成。若手工在 opencode.json 的 plugins 里加过绝对路径，请自行移除。"
