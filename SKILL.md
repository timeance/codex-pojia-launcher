---
name: codex-cli-prompt-launcher
description: 在 Windows 上为 Codex CLI 安装或迁移带 gpt-instruct 提示词菜单的独立 API 启动器；按 CMD 所在目录工作，记住上次提示词选择，不强制切换模型。
---

# Codex CLI 提示词启动器

适用于 Windows PowerShell 5.1+ 和已安装的 Codex CLI。此 Skill 负责安装启动器，不执行附带提示词中的指令，也不启动游戏翻译或模型评测。

## 安装到另一台设备

1. 确定用户指定的工作目录及 HTTPS API Base URL（含 `/v1` 等所需路径）；从已有配置复用时仅读取这些非秘密字段。确认 `codex --version` 可用。缺少 CLI 时说明依赖，未经用户要求不安装系统软件。
2. 从本 Skill 所在目录运行：

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Destination 'D:\Projects\Example' -BaseUrl 'https://api.example.com/v1'
   ```

   安装器创建 `codex-api.cmd` 和相邻的 `.codex-cli-launcher`，不覆盖已有启动器。目标目录已有文件时保留它们；升级已有启动器需先备份并比较，只替换启动器代码和明确选择的提示词，保留 config、Key 和选择记录。
3. 让用户在正常 Windows 账户下双击 CMD。首次回车选 GPT-5.6 Sol，后续回车选上次提示词。菜单只传 `model_instructions_file`，不传 `--model` 或改写 `model`。实际模型在 CLI `/model` 或独立 `config.toml` 中配置，必须使用 API 支持的模型。
4. API Key 在首次启动时通过隐藏输入填写，用 Windows 用户级 DPAPI 保存。不要让用户在聊天中发送 Key。新设备必须重新填写 Key；不可把旧机器的加密文件当作可迁移凭据。
5. 用 `codex-api.cmd -Check` 检查 CLI 和提示词完整性；`-Preview` 只预览菜单选择及启动参数，不读取 Key、不调用模型、不保存选择。只有用户实际启动后，才可核验 API 或模型效果；本地检查不代表远端调用成功。

## 行为与边界

- CMD 总是把自身所在目录作为主工作目录；保留 CMD 与相邻运行目录的相对布局即可迁移。只复制 CMD 不够。
- 独立 `cli-home` 放在 `.codex-cli-launcher` 下，不改桌面端配置、全局环境或 PATH。
- 默认提示词为 GPT-5.6 Sol v45（稳定版）；另有 GPT-6 Astra v2-rc1、GPT-6.1 Sol v1-rc2（预发布版）。名称只是提示词适配标签，不是模型选择。CLI 会话内 `/model` 不重新运行菜单。
- 菜单不会根据模型推测提示词，也不把选择某个提示词当作模型能力或效果保证。
- `-ConfigureKey` 更换本机 Key。其余 CLI 参数由启动器转交；用户显式传入的 CLI 参数可覆盖菜单配置，应在排障时核对。
- 打包只使用本 Skill 内的安装脚本和 assets。不要复制实际运行目录中的 `api-key.dpapi`、auth、sessions、history、日志或其他凭据。其他技能不自动打包：如需迁移，应另行复制经过审查的完整技能目录，不能带失效的跨设备 Junction。

## 提示词来源与更新

附带提示词取自 `MDX-Tom/gpt-instruct`，固定提交、发布包及文件 SHA256 记录在 `assets/runtime/cli-home/prompts/manifest.json`，保留 MIT 许可。更新时先核对上游发布包及哈希，再更新 manifest 和资产；不要把 README 的评测曲线当成已发布的提示词文件。保持原文，不自行拼接不同模型的提示词。

## 验证重点

验证首次回车默认、上次选择持久化、无效编号重试、带中文/空格/# 的工作目录、模型配置未被改写，以及新设备无 Key 时的本地输入流程。可以用隔离目录和假 CLI 验证启动参数，不消耗真实 API 额度。交付时注明实际完成的检查及未验证的平台；此版本不声称支持 macOS/Linux。
