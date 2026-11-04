param([string]$Engine = 'C:/Godot/Godot_v4.6.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$buildPath = Join-Path $repoPath 'build'
New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $buildPath '.gdignore') -Force | Out-Null
$peers = @()
$failed = $false
try {
    foreach ($role in @('host', 'client delay=0.4', 'client delay=1.4', 'client delay=2.4')) {
        $index = $peers.Count
        $peers += Start-Process -FilePath $Engine -WorkingDirectory $repoPath `
            -ArgumentList "--headless --path . --script tests/check_network.gd -- $role" `
            -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $buildPath "net-$index.out.log") `
            -RedirectStandardError (Join-Path $buildPath "net-$index.err.log")
    }
    foreach ($process in $peers) {
        if (-not $process.WaitForExit(25000)) { throw "Test peer $($process.Id) timed out" }
        if ($process.ExitCode -ne 0) { $failed = $true }
    }
    foreach ($index in 0..3) {
        Get-Content -LiteralPath (Join-Path $buildPath "net-$index.out.log")
        Get-Content -LiteralPath (Join-Path $buildPath "net-$index.err.log")
    }
    if ($failed) { throw 'Network test failed; inspect build/net-*.log' }
} finally {
    foreach ($process in $peers) {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
    }
}
