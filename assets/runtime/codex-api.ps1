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
if (-not (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) { throw '工作目录不存在，请检查路径是否正确。' }
if (-not (Test-Path -LiteralPath (Join-Path $cliHome 'config.toml'))) { throw '未找到 config.toml，请先运行安装脚本初始化启动器。' }
$cliCommand = Get-Command codex -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$cliBinary = if ($cliCommand) { $cliCommand.Source } else { Join-Path $env:LOCALAPPDATA 'Programs\OpenAI\Codex\bin\codex.exe' }
if (-not (Test-Path -LiteralPath $cliBinary -PathType Leaf)) { throw '未检测到 Codex CLI。请先安装 Codex CLI，再重新打开终端运行。' }
foreach ($option in $options) {
    $path = Join-Path (Join-Path $cliHome 'prompts') $option.file
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $option.sha256) { throw ('提示词文件校验失败：' + $option.file) }
}
if ($Check) {
    & $cliBinary --version
    Write-Host ('Codex CLI：' + $cliBinary)
    Write-Host ('配置文件：' + (Join-Path $cliHome 'config.toml'))
    Write-Host ('工作目录：' + $WorkingDirectory)
    Write-Host ('API Key 文件：' + ($(if (Test-Path -LiteralPath $keyPath) { '存在' } else { '不存在' })))
    Write-Host ('提示词校验通过：' + $options.Count + ' 项')
    exit $LASTEXITCODE
}
function Save-ApiKey {
    $enteredKey = Read-Host '请粘贴 API Key（输入内容将自动隐藏）' -AsSecureString
    try {
        if ($enteredKey.Length -eq 0) { throw 'API Key 不能为空。' }
        $enteredKey | ConvertFrom-SecureString | Set-Content -LiteralPath $keyPath -Encoding ASCII -NoNewline
    } finally { $enteredKey.Dispose() }
    Write-Host 'API Key 已使用当前 Windows 账户加密保存。'
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
Write-Host '请选择 gpt-instruct 破甲提示词'
Write-Host '提示：菜单仅切换提示词，不指定实际模型（请在会话内使用 /model 或在 config.toml 中配置）。'
for ($i = 0; $i -lt $options.Count; $i++) {
    $marker = if ($i -eq $defaultIndex) { ' [回车默认]' } else { '' }
    Write-Host ('{0}. {1} ({2}){3}' -f ($i + 1), $options[$i].label, $options[$i].version, $marker)
}
while ($true) {
    $choice = (Read-Host '请输入编号，或直接回车使用默认项').Trim()
    if ($choice -eq '') { $selectedIndex = $defaultIndex; break }
    $number = 0
    if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $options.Count) { $selectedIndex = $number - 1; break }
    Write-Host ('输入无效，请输入 1 到 ' + $options.Count + ' 之间的数字。')
}
$selected = $options[$selectedIndex]
$promptPath = Join-Path (Join-Path $cliHome 'prompts') $selected.file
# TOML literal strings avoid native PowerShell quoting of double quotes.
$tomlPath = $promptPath.Replace('\', '/')
if ($tomlPath.Contains("'")) { throw "启动器运行路径不能包含英文单引号（'），请安装到其他目录。" }
$nativeArguments = @('-C', $WorkingDirectory, '-c', ("model_instructions_file='" + $tomlPath + "'")) + @($CodexArguments)
Write-Host ('已选提示词：' + $selected.label + ' | 工作目录：' + $WorkingDirectory)
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
    catch { throw '无法在当前 Windows 账户下解密 API Key，请运行 codex-api.cmd -ConfigureKey 重新录入本机 Key。' }
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
