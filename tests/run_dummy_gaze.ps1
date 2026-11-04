param([switch]$Native)
$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$engine = 'C:/Godot/Godot_v4.6.2-stable_win64_console.exe'
Get-ChildItem -LiteralPath (Join-Path $repoPath 'build') -Filter 'gaze-check-*' -File | Remove-Item
$processes = @()
try {
    foreach ($slot in 1..2) {
        $modeArgument = if ($Native) { '' } else { '--headless' }
        $processes += Start-Process -FilePath $engine -WorkingDirectory $repoPath -WindowStyle Hidden -PassThru `
            -ArgumentList "$modeArgument --path . --script tests/check_dummy_gaze.gd -- --slot=$slot" `
            -RedirectStandardOutput (Join-Path $repoPath "build/gaze-$slot.out.log") `
            -RedirectStandardError (Join-Path $repoPath "build/gaze-$slot.err.log")
        if ($slot -eq 1) { Start-Sleep -Milliseconds 600 }
    }
    $failed = $false
    foreach ($process in $processes) {
        if (-not $process.WaitForExit(22000)) { throw 'Gaze peer timed out' }
        if ($process.ExitCode -ne 0) { $failed = $true }
    }
    foreach ($slot in 1..2) {
        Get-Content -LiteralPath (Join-Path $repoPath "build/gaze-$slot.out.log")
        $errors = Get-Content -LiteralPath (Join-Path $repoPath "build/gaze-$slot.err.log")
        if ($errors) { $errors; $failed = $true }
    }
    if ($failed) { throw 'Gaze checks failed' }
} finally {
    foreach ($process in $processes) {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id }
    }
}
