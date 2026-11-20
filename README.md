# oh-my-opencode / oh-my-openagent 内网离线包（v5.1.79）

面向 **OpenCode V2.2.6 · Rocky Linux 8.10 · 只连 DeepSeek API 的内网环境**。
不需要 npm、不需要 node、不需要联网装包——插件由 OpenCode 自带的 Bun 运行时按 **本地插件目录** 加载。

配套的模型假设（与你们现有 opencode.json 一致）：

- provider id：`my_deepseek`（openai-compatible，baseURL `https://api.deepseek.com/v1`）
- 模型：`my_deepseek/deepseek-flash`、`my_deepseek/deepseek-v4-pro`

---

## 一、插件目录规范（多插件统一管理）

**核心约定：所有插件只落在 opencode 自己的配置根下，`$HOME` 不再新增任何点目录。**

```
$ROOT/                                  # 默认 ~/.config/opencode，可用 OMO_ROOT 覆盖
├── opencode.json(c)                    # opencode 自身配置
├── plugins/                            # ★ 插件包根：一个直接子目录 = 一个插件（V2 自动发现）
│   ├── oh-my-openagent/
│   └── <其它插件>/                      # 照同样规范放，无需改 opencode.json
└── plugin-data/                        # ★ 插件数据根：配置/状态/清单，每个插件一个子目录
    └── oh-my-openagent/
        ├── omo.jsonc                   # 该插件的配置（唯一副本）
        └── manifest.json               # 版本、来源、安装时间、路径
```

三条规则：

1. **插件本体** → `$ROOT/plugins/<name>/`，必须含带 `name` 的 `package.json`（V2 靠它识别插件包）；
2. **插件配置/状态** → `$ROOT/plugin-data/<name>/`，插件自己的 `.xxx` 目录不要再出现在 `$HOME`；
3. **兼容软链只作为例外**：某些插件（包括本插件）硬编码读取 `$HOME/.omo/omo.jsonc` 这类路径。本安装器会建
   `~/.omo -> $ROOT/plugin-data/oh-my-openagent` 的软链去“借道”，真实文件仍在统一目录里。
   若文件系统不允许软链（部分 Windows / 特殊挂载），会自动退化为真实目录 + 配置副本，并打印警告。

统一管理命令（纯 bash，无依赖）：

```bash
./manage.sh list              # 列出已装插件 + 版本 + 数据目录
./manage.sh check             # 校验每个插件目录是否符合规范
./manage.sh remove <name>     # 只删插件包，配置保留
OMO_ROOT=/opt/opencode ./manage.sh list   # 管理共享安装的插件根
```

---

## 二、为什么能在内网用

OpenCode V2 的插件加载有两条路：npm 包（启动时联网装进缓存）和**本地插件目录**。
本包走第二条——把插件解包成一个普通目录，放进 `$ROOT/plugins/`。
V2 启动时会自动发现该目录下的插件包（带 `package.json` 的 `name` + `exports`），
直接 import 它的 `.` / `./server` 入口，全程零网络。

前提条件本包都已满足：

| 检查项 | 结论 |
|---|---|
| 原生二进制 | 包内**没有任何** `.node`/`.so`/`.exe`，纯 JS → Rocky 8 的 glibc 2.28 不是问题 |
| 运行时依赖 | 只有 `zod` + `detect-libc`，已内嵌在 `node_modules/`，由包内解析 |
| `@opentui/solid` | 仅 TUI 部分使用，加载 server 入口不需要 → 连同几百个 babel 包一起剔除（省 40MB+） |
| V2 入口 | `package.json` 的 `exports` 含 `.` / `./server` → `dist/index.js`，V2 可直接识别 |

---

## 三、包内结构

```
omo-offline-5.1.79/
├── install.sh                 安装/升级脚本
├── uninstall.sh               卸载脚本
├── manage.sh                  多插件统一管理（list / check / remove）
├── README.md  VERSION  SHA256SUMS
└── payload/
    ├── oh-my-openagent/       插件本体（解包后 57MB）
    │   ├── dist/              入口 index.js(7.8MB 已打包) + skills + cli
    │   ├── node_modules/      zod 4.6.6、detect-libc 2.1.2
    │   ├── packages/          lsp-core / lsp-daemon / lsp-tools-mcp / shared-skills
    │   ├── .opencode/ .agents/ 命令与技能定义
    │   └── package.json       name + exports(./ ./server ./tui)
    └── omo.jsonc.example      全部 agent → my_deepseek/* 的配置模板
```

---

## 四、安装

```bash
tar xzf omo-offline-5.1.79.tar.gz
cd omo-offline-5.1.79
sha256sum -c SHA256SUMS      # 可选：先验完整性
./install.sh
```

默认行为（**无需改 opencode.json**）：

1. 插件包 → `~/.config/opencode/plugins/oh-my-openagent/`（V2 自动发现的目录）；
2. 插件配置 → `~/.config/opencode/plugin-data/oh-my-openagent/omo.jsonc`（若已有 `~/.omo/omo.jsonc`，自动迁移过来）；
3. 建兼容软链 `~/.omo -> plugin-data/oh-my-openagent`（不支持软链则退化为真实目录副本）；
4. 写 `manifest.json`（版本/路径/时间），清理旧版 V1 加载器 `plugins/omo-openagent.js`。

**共享安装**（多用户 / 放 `/opt`）：

```bash
OMO_ROOT=/opt/opencode ./install.sh
```

此时需在 `opencode.json(c)` 的 **`plugins`**（复数）数组里指向该插件目录：

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": ["/opt/opencode/plugins/oh-my-openagent"]
}
```

---

## 五、配置 DeepSeek 与启动

```bash
export DEEPSEEK_API_KEY=sk-xxxx
opencode
```

配置真实位置：`~/.config/opencode/plugin-data/oh-my-openagent/omo.jsonc`（`~/.omo/omo.jsonc` 只是软链）。
你们的 provider 是自定义的 `my_deepseek`，模板已按此写好映射：

- 规划/推理类（plan、sisyphus、oracle、prometheus、metis、momus、deep*、ultrabrain）→ `my_deepseek/deepseek-v4-pro`
- 执行/检索类（build、librarian、explore、quick、utility…）→ `my_deepseek/deepseek-flash`

改模型只改这个文件，无需重装。

关键开关（已写在模板里）：

| 键 | 值 | 原因 |
|---|---|---|
| `telemetry` | `false` | 不发遥测 |
| `model_fallback` | `false` | 避免回落去找 Anthropic/OpenAI/Google 而报错 |
| `model_capabilities.enabled` | `false` | 关闭模型能力库的**联网**拉取 |
| `model_capabilities.auto_refresh_on_start` | `false` | 同上，启动不联网 |
| `disabled_mcps` | `grep_app`, `context7`, `websearch`, `codegraph` | 这些 MCP 需要公网；本地 `ast_grep`/`git_bash` 仍可用 |

---

## 六、验证与排查

```bash
./manage.sh list                                    # 插件是否就位、版本对不对
ls ~/.config/opencode/plugins/oh-my-openagent/package.json
opencode plugin list                                # 列表里应出现 oh-my-openagent
opencode                                            # /agents 应出现 sisyphus、oracle、prometheus…
```

看不到时按顺序排查：

1. 目录层级：必须是 `plugins/oh-my-openagent/package.json`（插件包是 `plugins/` 的**直接子目录**）；
2. 配置键名：V2 是 `plugins`（复数），写 `plugin` 不生效；
3. 删掉 V1 时期手工放的 `plugins/omo-openagent.js`（V2 会把裸 `.js` 当独立插件，重复加载）；
4. `opencode.json` 里若有 `"oh-my-openagent"` npm 条目请删除（离线会联网安装失败）；
5. `opencode --log-level DEBUG` 看插件加载报错。

---

## 七、已知限制

| 项 | 说明 |
|---|---|
| `omo` / `oh-my-opencode` 命令行 | 本包只覆盖「作为 OpenCode 插件」的用法；CLI 需要 node/bun |
| TUI 部分 | `./tui` 需要 `@opentui/solid`（未打包），只用 server 插件不受影响 |
| 官方技能市场 | 需联网，不可用；随包自带的 skills 正常 |
| 遥测 | `omo.jsonc` 已关；需要彻底禁可 `export OMO_DISABLE_POSTHOG=1` |

---

## 八、卸载

```bash
./uninstall.sh            # 删插件包 + 兼容软链，保留 plugin-data 下的配置
./uninstall.sh --purge    # 连插件数据（omo.jsonc）一起删
```

---

## 九、来源

- 插件：npm `oh-my-openagent@5.1.79`（旧名 `oh-my-opencode`）官方 tarball
- 内嵌依赖：`zod@4.6.6`、`detect-libc@2.1.2`
- 已剔除：多语种 README、docs、`dist/__tests__`、测试文件、Codex 专用 `packages/omo-codex`、QA 脚本
- 保留：`dist`、`packages/{lsp-*,shared-skills,...}`、`.opencode/`、`.agents/`
