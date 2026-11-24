---
name: codex-cli-prompt-launcher
description: 在 Windows 上为 Codex CLI 安装或迁移带 gpt-instruct 提示词菜单的独立 API 启动器；按 CMD 所在目录工作，记住上次提示词选择，不强制切换模型。
---

# Codex CLI 提示词启动器

适用于 Windows（PowerShell 5.1+）与已安装的 Codex CLI。本 Skill 仅负责安装、配置检查与迁移启动器，不执行附带提示词文件中的指令，也不运行模型评测。

## 安装与迁移步骤

1. **确认必要信息与依赖**
   - 收集用户指定的目标工作目录（路径不含英文单引号 `'`）及自定义 API 的 HTTPS Base URL（含 `/v1` 等完整路径，不含内嵌凭据、查询参数或 `#` 片段）。若从已有配置复用，仅读取这些非敏感字段。
   - 检查 `codex --version` 是否可用。若缺少 Codex CLI，明确说明依赖，未经用户同意不自行安装系统软件。

2. **执行安装脚本**
   在 Skill 所在目录运行：

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Destination 'D:\Projects\Example' -BaseUrl 'https://api.example.com/v1'
   ```

   - 脚本会创建 `codex-api.cmd` 和相邻的 `.codex-cli-launcher` 目录，并拒绝覆盖已有启动器。
   - 升级已有安装前须先备份并比对差异，仅替换启动器脚本与指定提示词，保留用户的 `config.toml`、`api-key.dpapi` 和 `last-prompt.txt`。

3. **引导用户本地填写 Key 并启动**
   - 让用户在日常使用的 Windows 账户下双击 `codex-api.cmd`（或在终端运行）。
   - API Key 须在首次启动时由用户通过终端隐藏输入填写（使用 Windows 用户级 DPAPI 加密保存），**切勿让用户在聊天中发送 API Key**。
   - 新设备或新 Windows 账户必须重新填写 Key，不可把旧设备的 `api-key.dpapi` 当作可迁移凭据。

4. **说明提示词与模型的区别**
   - 首次回车默认选择 `GPT-5.6 Sol`，后续回车沿用上次选择。
   - 菜单仅通过 `model_instructions_file` 加载提示词，不传 `--model` 也不改写 `config.toml` 中的 `model` 或 `model_reasoning_effort`。实际模型由用户在 CLI 内通过 `/model` 或在 `config.toml` 顶层自行指定。

5. **运行本地校验**
   - 使用 `codex-api.cmd -Check` 检查 CLI 版本、配置/Key 文件是否存在，以及提示词 SHA256 完整性；该检查不解析 TOML，也不解密 Key。
   - 使用 `codex-api.cmd -Preview` 预览菜单选择与最终启动参数（不读取 Key、不发起 API 请求、不保存选择）。
   - 本地检查通过不代表配置内容有效或远端 API 调用成功；实际模型可用性需启动 CLI 后确认。

## 行为规范与安全边界

- **工作目录与便携性**：`codex-api.cmd` 始终以自身所在目录为主工作目录。同账户迁移目录时，必须将 `codex-api.cmd` 与 `.codex-cli-launcher` 一起移动。
- **环境隔离**：独立 `cli-home` 位于 `.codex-cli-launcher` 下，不修改桌面端 Codex 配置、全局环境变量或 `PATH`。
- **提示词版本**：默认项为 `GPT-5.6 Sol v45`（稳定版），另含 `GPT-6 Astra v2-rc1` 与 `GPT-6.1 Sol v1-rc2`（预发布版）。名称仅作提示词适配标签，不代表模型切换或效果承诺；会话内切换 `/model` 不会重新触发菜单。
- **参数传递与 Key 维护**：`-ConfigureKey` 用于重新录入本机 Key。启动器自己的参数优先解析，`--help`、`--model` 等已验证参数可继续传给 CLI；`-c` 会产生参数歧义，`--config` 会被识别为 `-ConfigureKey`，因此配置调整应编辑独立的 `config.toml`。排障时一并核对用户传入的参数。
- **打包与隐私红线**：打包分发时仅包含本 Skill 的脚本与 `assets`，严禁复制运行目录中的 `api-key.dpapi`、认证文件、会话记录、历史记录或日志。不自动打包其他外部 Skill，避免携带失效的跨设备符号链接或目录联接（Junction）。

## 提示词来源与更新

附带提示词来自 `MDX-Tom/gpt-instruct`，固定提交、上游压缩包及文件 SHA256 均记录在 `assets/runtime/cli-home/prompts/manifest.json`，并保留上游 MIT 许可。更新资产时应先核对上游发布包与哈希，再同步更新 manifest 与文件；不要将上游 README 中的评测信息当作正式发布的提示词文件，且需保持原文完整，不自行拼接不同版本的提示词。

## 交付验证清单

交付或变更启动器时，重点验证以下项目（可使用隔离目录与模拟 CLI 验证参数，避免消耗真实 API 额度）：

- 首次回车默认项、上次选择记忆、无效编号输入重试；
- 包含中文、空格、`#` 的工作目录路径处理；
- `config.toml` 中的模型配置未被菜单改写；
- 新环境无 Key 时的本地隐藏输入流程。

交付结果中需写明已完成的检查项与未覆盖的环境；本启动器仅支持 Windows，不声称支持 macOS 或 Linux。
