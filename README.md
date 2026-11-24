# Codex 破甲提示词启动器

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/brand/readme_banner_dark.png">
    <img src="assets/brand/readme_banner_light.png" alt="Codex 破甲提示词启动器：独立配置、提示词切换、随目录启动" width="960">
  </picture>
</p>

为 Windows 版 Codex CLI 提供独立的 API 环境、提示词选择菜单与可随目录移动的启动入口。  
本仓库同时支持作为 `codex-cli-prompt-launcher` Skill 使用，详见 [SKILL.md](SKILL.md)。

> **提示**：启动菜单仅切换 `gpt-instruct` 破甲提示词，不会强制指定或改写推理模型。实际使用的模型仍由 Codex 会话内的 `/model` 命令或 `config.toml` 决定。

## 提示词菜单

| 编号 | 提示词 | 上游版本 | 说明 |
| --- | --- | --- | --- |
| 1 | GPT-5.6 Sol | v45 | 稳定版（首次直接回车默认） |
| 2 | GPT-6 Astra | v2-rc1 | 预发布版 |
| 3 | GPT-6.1 Sol | v1-rc2 | 预发布版 |

- 首次启动直接回车默认选择 `GPT-5.6 Sol`，之后每次启动都会自动记住上次的选择。
- 提示词在每次启动时通过 `model_instructions_file` 临时传入，不会修改 `model` 或 `model_reasoning_effort`。
- 会话内使用 `/model` 切换模型不会重新弹出菜单；如需更换提示词，请退出后重新运行启动器。

## 快速开始

### 环境要求

- Windows 系统，Windows PowerShell 5.1 及以上
- 已安装 Codex CLI，且终端中可正常运行 `codex --version`

### 1. 安装到工作目录

克隆或下载本仓库后，在仓库根目录执行安装脚本（将路径和 API 地址替换为你的实际配置）：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Destination 'D:\Projects\MyProject' -BaseUrl 'https://api.example.com/v1'
```

参数说明：

- `-Destination`：目标工作目录（路径中不能包含英文单引号 `'`）。
- `-BaseUrl`：自定义 API 的 HTTPS 基础地址（如 `https://api.example.com/v1`，不能包含内嵌账号密码、查询参数或 `#` 片段）。

安装完成后，目标目录会新增以下结构（若目录中已存在启动器，安装脚本会拒绝覆盖以保护现有配置）：

```text
MyProject/
├── codex-api.cmd                  # 启动入口（双击或终端运行）
└── .codex-cli-launcher/
    ├── codex-api.ps1              # 启动脚本
    └── cli-home/                  # 独立 CODEX_HOME
        ├── config.toml            # API 与模型配置
        ├── api-key.dpapi          # 首次填写 Key 后自动生成（本机加密）
        ├── last-prompt.txt        # 首次启动后自动生成（记忆上次选择）
        └── prompts/               # 提示词文件与校验清单
```

### 2. 首次启动

1. 双击目标目录中的 `codex-api.cmd`，或在终端中执行 `.\codex-api.cmd`。
2. 按提示选择要加载的提示词（或直接回车使用默认项）。
3. 首次运行未检测到 API Key 时，终端会提示以隐藏方式粘贴 API Key，并使用当前 Windows 账户的 DPAPI 加密保存在本机。
4. 进入 Codex CLI 后，使用 `/model` 选择你的 API 服务商支持的实际模型即可开始使用。

## 配置说明

启动器使用独立的 `CODEX_HOME`（`.codex-cli-launcher\cli-home`），不会修改桌面端 Codex 的登录状态、系统环境变量或 `PATH`。自定义 API 采用 Responses 协议并通过环境变量认证，与官方桌面端登录互不干扰。

### config.toml 设置

安装时会自动生成 `.codex-cli-launcher\cli-home\config.toml`，默认内容如下：

```toml
# 提示词菜单不指定模型；请在此设置 model，或在会话内使用 /model 切换。
model_provider = "portable_api"
cli_auth_credentials_store = "ephemeral"
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[model_providers.portable_api]
name = "Custom API"
base_url = "https://api.example.com/v1"
env_key = "ZARIBA_CODEX_API_KEY"
wire_api = "responses"
requires_openai_auth = false
```

常用调整项：

- **固定默认模型与推理强度**：在文件顶层（`[model_providers.portable_api]` 之前）添加：
  ```toml
  model = "你的服务端模型名"
  model_reasoning_effort = "high"
  ```
- **更换 API 地址**：直接修改 `[model_providers.portable_api]` 下的 `base_url`。
- **调整审批与沙箱策略**：按需修改顶层的 `approval_policy`（默认 `"on-request"`）和 `sandbox_mode`（默认 `"workspace-write"`）。

### API Key 管理

- Key 加密保存在 `.codex-cli-launcher\cli-home\api-key.dpapi`，启动时临时注入进程环境，结束后恢复原环境。
- 如需更换 Key，运行 `.\codex-api.cmd -ConfigureKey` 重新输入即可。

## 常用命令

```powershell
.\codex-api.cmd                # 正常启动（选提示词并进入 Codex CLI）
.\codex-api.cmd -Check         # 检查 CLI 版本、配置/Key 文件是否存在，以及提示词完整性
.\codex-api.cmd -Preview       # 预览菜单选择与最终启动参数（不读 Key、不发请求、不保存选择）
.\codex-api.cmd -ConfigureKey  # 重新填写并加密保存本机 API Key
```

可附加部分 Codex CLI 参数，例如 `.\codex-api.cmd --help` 或 `.\codex-api.cmd --model 服务端模型名`。启动器自己的参数优先解析：`-c` 会产生参数歧义，`--config` 会被识别为 `-ConfigureKey`。配置调整请直接编辑独立的 `config.toml`，不要通过这两个参数传入。

`-Check` 不解析配置内容，也不尝试解密 Key 或连接 API；实际配置和服务端可用性需启动 CLI 后确认。

## 迁移与升级

### 更换工作目录（同设备、同账户）

`codex-api.cmd` 始终以自身所在目录作为主工作目录。如需换到其他项目目录，**将 `codex-api.cmd` 与相邻的 `.codex-cli-launcher` 文件夹一起移动或复制过去即可**（单独复制 `.cmd` 无法运行）。

### 更换电脑或 Windows 账户

由于 `api-key.dpapi` 绑定当前 Windows 账户，无法跨设备或跨账户解密。请在新设备上从本仓库重新安装，并在首次启动时重新填写 API Key。

### 升级已有安装

安装脚本默认不会覆盖已有启动器。如需升级，建议先备份现有目录，再仅替换启动器脚本与 `prompts` 目录，保留你原有的 `config.toml`、`api-key.dpapi` 和 `last-prompt.txt`。

## 常见问题

**Q：为什么选了 GPT-6.1 Sol，但实际调用的还是原来的模型？**

菜单中的名称仅表示提示词所适配的版本，不会切换模型。请在 Codex CLI 中输入 `/model` 选择服务端支持的模型，或在 `config.toml` 顶层显式配置 `model`。

**Q：启动提示无法解密 API Key 怎么办？**

通常是因为更换了电脑或切换了 Windows 账户。运行 `.\codex-api.cmd -ConfigureKey` 重新输入本机 Key 即可解决。

**Q：支持 macOS 或 Linux 吗？**

暂不支持。本启动器专为 Windows 环境（PowerShell 5.1+ 与 DPAPI）设计。

## 上游与许可

- 提示词来源：[MDX-Tom/gpt-instruct](https://github.com/MDX-Tom/gpt-instruct)
- 开源协议：本仓库采用 [MIT License](LICENSE)
