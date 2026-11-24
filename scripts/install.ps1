param(
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][string]$BaseUrl
)
$ErrorActionPreference = 'Stop'
$uri = $null
if (-not [Uri]::TryCreate($BaseUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) {
    throw 'BaseUrl 必须是有效的 HTTPS API 地址，且不能包含内嵌凭据、查询参数或 # 片段。'
}
$target = [IO.Path]::GetFullPath($Destination)
if ($target.Contains("'")) { throw "目标目录路径不能包含英文单引号（'），请更换其他目录。" }
$runtime = Join-Path $target '.codex-cli-launcher'
$entry = Join-Path $target 'codex-api.cmd'
if ((Test-Path -LiteralPath $runtime) -or (Test-Path -LiteralPath $entry)) { throw '目标目录已存在启动器。为避免覆盖现有配置，请选择新的目录。' }
$assetRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets'
$manifest = Get-Content -LiteralPath (Join-Path $assetRoot 'runtime\cli-home\prompts\manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($prompt in $manifest.prompts) {
    $path = Join-Path (Join-Path $assetRoot 'runtime\cli-home\prompts') $prompt.file
    if ((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -ne $prompt.sha256) { throw ('内置提示词校验失败：' + $prompt.file) }
}
New-Item -ItemType Directory -Path $target -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $assetRoot 'runtime') -Destination $runtime -Recurse
$safeUrl = $uri.AbsoluteUri.TrimEnd('/').Replace('"', '\"')
$config = @"
# 提示词菜单不指定模型；请在此设置 model，或在会话内使用 /model 切换。
model_provider = "portable_api"
cli_auth_credentials_store = "ephemeral"
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[model_providers.portable_api]
name = "Custom API"
base_url = "$safeUrl"
env_key = "ZARIBA_CODEX_API_KEY"
wire_api = "responses"
requires_openai_auth = false
"@
[IO.File]::WriteAllText((Join-Path $runtime 'cli-home\config.toml'), $config, (New-Object Text.UTF8Encoding($false)))
Copy-Item -LiteralPath (Join-Path $assetRoot 'codex-api.cmd') -Destination $entry
Write-Host ('安装完成：' + $entry)
Write-Host '请在当前 Windows 账户下运行 codex-api.cmd，选择提示词后按提示在本地填写 API Key。'
Write-Host '提示：菜单不会强制指定模型，请在会话内使用 /model 或编辑 config.toml 选择服务端支持的模型。'
