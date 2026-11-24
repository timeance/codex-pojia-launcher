param(
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][string]$BaseUrl
)
$ErrorActionPreference = 'Stop'
$uri = $null
if (-not [Uri]::TryCreate($BaseUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) {
    throw 'BaseUrl must be an HTTPS API URL without embedded credentials, query or fragment.'
}
$target = [IO.Path]::GetFullPath($Destination)
if ($target.Contains("'")) { throw 'Choose a destination without apostrophes.' }
$runtime = Join-Path $target '.codex-cli-launcher'
$entry = Join-Path $target 'codex-api.cmd'
if ((Test-Path -LiteralPath $runtime) -or (Test-Path -LiteralPath $entry)) { throw 'Destination already has a launcher. Choose a fresh directory; existing configuration was not overwritten.' }
$assetRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets'
$manifest = Get-Content -LiteralPath (Join-Path $assetRoot 'runtime\cli-home\prompts\manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($prompt in $manifest.prompts) {
    $path = Join-Path (Join-Path $assetRoot 'runtime\cli-home\prompts') $prompt.file
    if ((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -ne $prompt.sha256) { throw 'Packaged prompt checksum mismatch.' }
}
New-Item -ItemType Directory -Path $target -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $assetRoot 'runtime') -Destination $runtime -Recurse
$safeUrl = $uri.AbsoluteUri.TrimEnd('/').Replace('"', '\"')
$config = @"
# The prompt menu does not select a model. Set model separately or use /model.
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
Write-Host ('Created: ' + $entry)
Write-Host 'Start the CMD in your normal Windows account. Select a prompt, then enter the API key locally.'
Write-Host 'Choose the actual API-supported model separately with /model or config.toml. No model was forced.'
