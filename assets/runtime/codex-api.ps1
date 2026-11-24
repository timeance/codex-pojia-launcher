param(
    [string]$WorkingDirectory = (Get-Location).Path,
    [switch]$ConfigureKey,
    [switch]$Check,
    [switch]$Preview,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CodexArguments
)
$ErrorActionPreference = 'Stop'
$cliHome = Join-Path $PSScriptRoot 'cli-home'
$keyPath = Join-Path $cliHome 'api-key.dpapi'
$selectionPath = Join-Path $cliHome 'last-prompt.txt'
$manifest = Get-Content -LiteralPath (Join-Path $cliHome 'prompts\manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$options = @($manifest.prompts)
if (-not (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) { throw 'Working directory does not exist.' }
if (-not (Test-Path -LiteralPath (Join-Path $cliHome 'config.toml'))) { throw 'Missing config.toml. Run the Skill installer first.' }
$cliCommand = Get-Command codex -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$cliBinary = if ($cliCommand) { $cliCommand.Source } else { Join-Path $env:LOCALAPPDATA 'Programs\OpenAI\Codex\bin\codex.exe' }
if (-not (Test-Path -LiteralPath $cliBinary -PathType Leaf)) { throw 'Codex CLI not found. Install Codex CLI, then open a new terminal.' }
foreach ($option in $options) {
    $path = Join-Path (Join-Path $cliHome 'prompts') $option.file
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $option.sha256) { throw ('Prompt checksum mismatch: ' + $option.file) }
}
if ($Check) {
    & $cliBinary --version
    Write-Host ('CLI: ' + $cliBinary)
    Write-Host ('Config: ' + (Join-Path $cliHome 'config.toml'))
    Write-Host ('Working directory: ' + $WorkingDirectory)
    Write-Host ('API key configured: ' + (Test-Path -LiteralPath $keyPath))
    Write-Host ('Prompt files verified: ' + $options.Count)
    exit $LASTEXITCODE
}
function Save-ApiKey {
    $enteredKey = Read-Host '粘贴 API Key（隐藏输入）' -AsSecureString
    try {
        if ($enteredKey.Length -eq 0) { throw 'API key cannot be empty.' }
        $enteredKey | ConvertFrom-SecureString | Set-Content -LiteralPath $keyPath -Encoding ASCII -NoNewline
    } finally { $enteredKey.Dispose() }
    Write-Host 'Key 已用当前 Windows 用户加密保存。'
}
if ($ConfigureKey) { Save-ApiKey; exit 0 }
$defaultIndex = 0
if (Test-Path -LiteralPath $selectionPath) {
    $lastId = (Get-Content -LiteralPath $selectionPath -Raw -Encoding UTF8).Trim()
    for ($i = 0; $i -lt $options.Count; $i++) {
        if ($options[$i].id -eq $lastId) { $defaultIndex = $i; break }
    }
}
Write-Host ''
Write-Host '选择 gpt-instruct 破甲提示词配置'
Write-Host '仅切换提示词，不强行指定模型；实际模型仍按 Codex 配置或 /model 选择。'
Write-Host '以下名称表示提示词对应的模型版本，不表示已切换推理模型。'
for ($i = 0; $i -lt $options.Count; $i++) {
    $marker = if ($i -eq $defaultIndex) { ' [回车默认]' } else { '' }
    Write-Host ('{0}. {1} ({2}){3}' -f ($i + 1), $options[$i].label, $options[$i].version, $marker)
}
while ($true) {
    $choice = (Read-Host '输入编号，或直接回车').Trim()
    if ($choice -eq '') { $selectedIndex = $defaultIndex; break }
    $number = 0
    if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $options.Count) { $selectedIndex = $number - 1; break }
    Write-Host ('请输入 1 到 ' + $options.Count + '。')
}
$selected = $options[$selectedIndex]
$promptPath = Join-Path (Join-Path $cliHome 'prompts') $selected.file
# TOML literal strings avoid native PowerShell quoting of double quotes.
$tomlPath = $promptPath.Replace('\', '/')
if ($tomlPath.Contains("'")) { throw 'The runtime path cannot contain an apostrophe. Install into another directory.' }
$nativeArguments = @('-C', $WorkingDirectory, '-c', ("model_instructions_file='" + $tomlPath + "'")) + @($CodexArguments)
Write-Host ('提示词：' + $selected.label + '；工作目录：' + $WorkingDirectory)
if ($Preview) {
    [pscustomobject]@{ prompt = $selected.id; cwd = $WorkingDirectory; cli = $cliBinary; arguments = $nativeArguments } | ConvertTo-Json -Depth 4
    exit 0
}
if (-not (Test-Path -LiteralPath $keyPath)) { Save-ApiKey }
$previousHome = $env:CODEX_HOME
$previousKey = $env:ZARIBA_CODEX_API_KEY
$keyPointer = [IntPtr]::Zero
$storedKey = $null
try {
    try { $storedKey = (Get-Content -LiteralPath $keyPath -Raw).Trim() | ConvertTo-SecureString }
    catch { throw 'Cannot decrypt API key on this Windows account. Run codex-api.cmd -ConfigureKey to enter a local key.' }
    $keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storedKey)
    $env:ZARIBA_CODEX_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)
    $env:CODEX_HOME = $cliHome
    Set-Content -LiteralPath $selectionPath -Value $selected.id -Encoding UTF8 -NoNewline
    & $cliBinary @nativeArguments
    $resultCode = $LASTEXITCODE
} finally {
    $env:CODEX_HOME = $previousHome
    $env:ZARIBA_CODEX_API_KEY = $previousKey
    if ($keyPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer) }
    if ($null -ne $storedKey) { $storedKey.Dispose() }
}
exit $resultCode
