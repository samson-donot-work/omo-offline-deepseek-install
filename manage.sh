#!/usr/bin/env bash
# 统一插件管理（无依赖，只看目录规范）
#   ./manage.sh list            列出 $ROOT/plugins 下所有插件及版本、数据目录
#   ./manage.sh check           逐个校验：package.json / exports / 内嵌依赖 / manifest
#   ./manage.sh remove <name>   删除插件包（配置保留在 plugin-data/<name>）
# ROOT 覆盖: OMO_ROOT=/opt/opencode ./manage.sh list
set -uo pipefail
ROOT="${OMO_ROOT:-$(printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}")/opencode}"
PLUGINS="$ROOT/plugins"
DATA="$ROOT/plugin-data"
cmd="${1:-list}"

ver_of() { sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" 2>/dev/null | head -1; }

case "$cmd" in
list)
  [ -d "$PLUGINS" ] || { echo "没有插件目录: $PLUGINS"; exit 0; }
  printf '%-26s %-10s %s\n' "PLUGIN" "VERSION" "DATA"
  for d in "$PLUGINS"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    if [ ! -f "$d/package.json" ]; then
      printf '%-26s %-10s %s\n' "$name" "-" "(无 package.json，V2 不会加载)"
      continue
    fi
    printf '%-26s %-10s %s\n' "$name" "$(ver_of "$d/package.json")" "$([ -f "$DATA/$name/manifest.json" ] && echo "$DATA/$name" || echo "-")"
  done
  ;;
check)
  [ -d "$PLUGINS" ] || { echo "没有插件目录: $PLUGINS"; exit 1; }
  rc=0
  for d in "$PLUGINS"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    printf '== %s\n' "$name"
    if [ ! -f "$d/package.json" ]; then printf '  FAIL 缺 package.json（V2 不识别该目录）\n'; rc=1; continue; fi
    grep -q '"name"' "$d/package.json" || { printf '  FAIL package.json 缺 name\n'; rc=1; }
    grep -q '"exports"' "$d/package.json" || printf '  WARN package.json 缺 exports（只能按单文件/旧方式加载）\n'
    [ -f "$d/dist/index.js" ] || printf '  WARN 缺 dist/index.js（入口可能不同）\n'
    [ -f "$DATA/$name/manifest.json" ] || printf '  WARN 无安装清单（非本安装器安装）\n'
    [ -d "$d/node_modules" ] && printf '  ok   内嵌 node_modules 存在\n'
    printf '  ok   包目录就绪\n'
  done
  exit $rc
  ;;
remove)
  name="${2:-}"
  [ -n "$name" ] || { echo "用法: $0 remove <plugin-name>"; exit 1; }
  [ -d "$PLUGINS/$name" ] || { echo "未安装: $name"; exit 1; }
  rm -rf "${PLUGINS:?}/$name"
  echo "已删除插件包 $PLUGINS/$name（配置保留在 $DATA/$name，如仍存在）"
  ;;
*)
  echo "用法: $0 [list|check|remove <name>]"; exit 1;;
esac
