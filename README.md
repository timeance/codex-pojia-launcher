# Codex 破甲提示词启动器

为 Windows Codex CLI 提供独立 API 配置、提示词选择菜单和可移动的工作目录启动脚本。也可作为 `codex-cli-prompt-launcher` Skill 使用，安装流程见 [SKILL.md](SKILL.md)。

**菜单仅切换 gpt-instruct 破甲提示词配置，不强行指定实际模型。** 实际模型由 Codex 的 `/model` 或独立 `config.toml` 配置决定。

## 提示词菜单

| 选项 | 上游版本 | 状态 |
| --- | --- | --- |
| GPT-5.6 Sol | v45 | 稳定版；首次回车默认 |
| GPT-6 Astra | v2-rc1 | 预发布版 |
| GPT-6.1 Sol | v1-rc2 | 预发布版 |

后续直接回车使用上次选择。提示词通过单次启动的 `model_instructions_file` 参数加载，菜单不改写 `model` 或 `model_reasoning_effort`。会话内切换模型不会重新运行菜单；更换提示词需退出后重新启动。

## 安装

需要 Windows、Windows PowerShell 5.1 或以上，以及已安装且可运行 `codex --version` 的 Codex CLI。

克隆或下载本仓库，在仓库目录运行（替换工作目录和 API 地址）：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Destination 'D:\Projects\MyProject' -BaseUrl 'https://api.example.com/v1'
```

安装器创建以下文件，不覆盖已有启动器：

```text
MyProject/
├─ codex-api.cmd
└─ .codex-cli-launcher/
   ├─ codex-api.ps1
   └─ cli-home/
      ├─ config.toml
      └─ prompts/
```

1. 双击目标目录中的 `codex-api.cmd`，或从终端运行它。
2. 选择提示词。缺少 API Key 时，启动器通过隐藏输入提示填写，并用当前 Windows 用户的 DPAPI 加密保存。
3. 在 CLI 中通过 `/model` 选择服务端支持的实际模型，或在 `.codex-cli-launcher\cli-home\config.toml` 的顶层单独设置 `model` 和 `model_reasoning_effort`。

启动器使用自己的 `CODEX_HOME`，不修改桌面端登录、全局环境变量或 PATH。自定义 API 使用 Responses 协议和环境变量认证，不需要复用桌面端登录令牌。

## 更换工作目录与设备

CMD 始终将自身所在目录作为主工作目录。把 `codex-api.cmd` 和相邻的 `.codex-cli-launcher` 一起移动即可更换目录；只复制 CMD 不够。

另一台 Windows 设备请从本仓库重新安装并在本机填写 API Key。加密 Key 绑定 Windows 用户，不能当作跨设备凭据。仓库和发布源码不包含用户的配置、凭据、会话或其他翻译 Skill；其他 Skill 应另行安装，避免复制指向旧机器的目录链接。

## 检查与维护

```powershell
.\codex-api.cmd -Check         # 检查 CLI、提示词完整性和 Key 文件是否存在
.\codex-api.cmd -Preview       # 预览菜单和启动参数；不读取 Key、不请求 API、不保存选择
.\codex-api.cmd -ConfigureKey  # 用隐藏输入重新填写本机 Key
```

已有安装升级前应先备份，只替换启动器代码和提示词资产，保留 `config.toml`、`api-key.dpapi` 和 `last-prompt.txt`。安装器会拒绝覆盖已有入口或运行目录。

已本地验证 Windows PowerShell 5.1 下的首次默认项、选择记忆、无效输入重试、中文/空格/# 目录、移动后的相对路径、参数传递、配置保留及临时 DPAPI 凭据；真实 Codex CLI 的 `features list` 可接受生成的配置和提示词覆盖参数。没有进行真实 API 请求或提示词效果评测，也不声称支持 macOS/Linux。

## 上游与许可

提示词来自 [MDX-Tom/gpt-instruct](https://github.com/MDX-Tom/gpt-instruct)，固定提交 `79b9c1cfde30ca6d70ba8f76e9b23be38e4223a3`。发布包及原始提示词的 SHA256 记录在 [manifest.json](assets/runtime/cli-home/prompts/manifest.json)。启动器安装和运行前均校验提示词文件哈希；更新资产时需同步核对上游和更新 manifest。

本仓库采用 [MIT License](LICENSE)，附带提示词保留 [上游 MIT 许可](assets/runtime/cli-home/prompts/LICENSE.gpt-instruct)。提示词资产是待加载的数据，不是安装 Skill 时需要执行的指令。
