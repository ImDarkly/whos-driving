param([string]$Engine = 'C:/Godot/Godot_v4.6.2-stable_win64_console.exe')
# Explicit live EOS check using existing authorized names in the local Dev Auth
# Tool. No account sign-in UI or portal changes. No test transport fallback.
$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$buildPath = Join-Path $repoPath 'build'
New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $buildPath '.gdignore') -Force | Out-Null
$roomFile = Join-Path $buildPath 'eos-wheel-room.json'
if (Test-Path -LiteralPath $roomFile) { Remove-Item -LiteralPath $roomFile }
$peers = @()
try {
    $peers += Start-Process -FilePath $Engine -WorkingDirectory $repoPath -WindowStyle Hidden -PassThru `
        -ArgumentList '--headless --path . --script tests/check_network.gd -- eos host --dev-auth=host_user --dev-auth-server=localhost:8081' `
        -RedirectStandardOutput (Join-Path $buildPath 'eos-wheel-host.out.log') `
        -RedirectStandardError (Join-Path $buildPath 'eos-wheel-host.err.log')
    $deadline = [DateTime]::UtcNow.AddSeconds(40)
    while (-not (Test-Path -LiteralPath $roomFile)) {
        if ($peers[0].HasExited) { throw 'EOS host exited before opening a room. See build/eos-wheel-host.*.log' }
        if ([DateTime]::UtcNow -gt $deadline) { throw 'EOS host login/room timed out. See build/eos-wheel-host.*.log' }
        Start-Sleep -Milliseconds 250
    }
    $room = (Get-Content -LiteralPath $roomFile -Raw | ConvertFrom-Json).room_code
    if ($room -notmatch '^[A-Z2-9]{6}$') { throw 'Invalid test room code' }
    $peers += Start-Process -FilePath $Engine -WorkingDirectory $repoPath -WindowStyle Hidden -PassThru `
        -ArgumentList "--headless --path . --script tests/check_network.gd -- eos client room=$room --dev-auth=client_user --dev-auth-server=localhost:8081" `
        -RedirectStandardOutput (Join-Path $buildPath 'eos-wheel-client.out.log') `
        -RedirectStandardError (Join-Path $buildPath 'eos-wheel-client.err.log')
    foreach ($process in $peers) {
        if (-not $process.WaitForExit(60000)) { throw 'EOS test peer timed out. See build/eos-wheel-*.log' }
        if ($process.ExitCode -ne 0) { throw 'EOS test peer failed. See build/eos-wheel-*.log' }
    }
    # Only protocol check results; keep SDK/account details in ignored logs.
    foreach ($role in @('host', 'client')) {
        Get-Content -LiteralPath (Join-Path $buildPath "eos-wheel-$role.out.log") | Where-Object { $_ -match '^(NETWORK OK:|NETWORK CLIENT|EOS WHEEL HOST)' }
    }
} finally {
    foreach ($process in $peers) {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
    }
}
