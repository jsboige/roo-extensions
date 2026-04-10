# Cleanup ghost node terminal windows
param()

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class ProcHelper {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool TerminateProcess(IntPtr hProcess, uint uExitCode);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);
}
"@

$PROCESS_TERMINATE = 0x0001
$ghostPids = @(10524, 10588, 15308, 15712, 16000)
$killed = 0
$failed = 0

foreach ($procId in $ghostPids) {
    $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if (-not $proc) {
        Write-Host "PID $procId : already gone"
        continue
    }

    $title = $proc.MainWindowTitle
    $hProc = [ProcHelper]::OpenProcess($PROCESS_TERMINATE, $false, $procId)
    $lastErr = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()

    if ($hProc -eq [IntPtr]::Zero) {
        Write-Host "PID $procId : OpenProcess FAILED (error=$lastErr) title=$title"
        $failed++
    } else {
        $ok = [ProcHelper]::TerminateProcess($hProc, 1)
        $termErr = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        [ProcHelper]::CloseHandle($hProc) | Out-Null

        if ($ok) {
            Write-Host "PID $procId : KILLED title=$title"
            $killed++
        } else {
            Write-Host "PID $procId : TerminateProcess FAILED (error=$termErr) title=$title"
            $failed++
        }
    }
}

Write-Host ""
Write-Host "Result: killed=$killed failed=$failed"

# Also cleanup old conhost processes (from previous days)
$oldConhosts = Get-Process conhost -ErrorAction SilentlyContinue | Where-Object {
    $_.StartTime -and $_.StartTime -lt (Get-Date).AddHours(-12)
}
if ($oldConhosts) {
    Write-Host ""
    Write-Host "Old conhost processes (>12h): $($oldConhosts.Count)"
    foreach ($ch in $oldConhosts) {
        try {
            Stop-Process -Id $ch.Id -Force -ErrorAction Stop
            Write-Host "  Cleaned conhost PID $($ch.Id)"
        } catch {
            # Some conhosts are needed by active processes - skip
        }
    }
}
