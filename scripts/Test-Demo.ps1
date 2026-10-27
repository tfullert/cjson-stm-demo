[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Executable,
    [Parameter(Mandatory)][ValidateSet('1.7.16', '1.7.17')][string]$DependencyVersion,
    [string]$ReportPath = 'test-results.json'
)
$ErrorActionPreference = 'Stop'
$executablePath = (Resolve-Path $Executable).Path

function Invoke-Demo([string]$Mode) {
    $info = [System.Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $executablePath
    $info.ArgumentList.Add($Mode)
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $info
    if (-not $process.Start()) { throw 'Could not start the demo.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(15000)) {
        $process.Kill($true)
        throw "Demo timed out in mode $Mode."
    }
    $result = [ordered]@{
        mode = $Mode
        exit_code = $process.ExitCode
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
    $process.Dispose()
    Write-Host $result.stdout
    if ($result.stderr) { Write-Host $result.stderr }
    Write-Host "Exit code: $($result.exit_code)"
    return [pscustomobject]$result
}

$normal = Invoke-Demo '--normal'
$missing = Invoke-Demo '--missing'
$versionText = "cJSON version: $DependencyVersion"
$normalPassed = $normal.exit_code -eq 0 -and
    $normal.stdout.Contains($versionText) -and
    $normal.stdout.Contains('RESULT: normal update succeeded.')
if ($DependencyVersion -eq '1.7.16') {
    # Windows STATUS_ACCESS_VIOLATION (0xC0000005), represented as signed Int32.
    $expected = 'access violation reproduces CVE-2023-50472'
    $missingPassed = $missing.exit_code -eq -1073741819 -and
        $missing.stdout.Contains('Calling cJSON_SetValuestring...') -and
        -not $missing.stdout.Contains('RESULT:')
} else {
    $expected = 'missing setting is rejected safely'
    $missingPassed = $missing.exit_code -eq 2 -and
        $missing.stdout.Contains('RESULT: missing setting rejected safely.')
}
$missingPassed = $missingPassed -and $missing.stdout.Contains($versionText)
$report = [ordered]@{
    dependency_version = $DependencyVersion
    expected_missing_behavior = $expected
    normal_passed = [bool]$normalPassed
    missing_passed = [bool]$missingPassed
    normal = $normal
    missing = $missing
}
$report | ConvertTo-Json -Depth 5 | Set-Content -Path $ReportPath -Encoding utf8
if (-not ($normalPassed -and $missingPassed)) {
    throw "Unexpected demo behavior. See $ReportPath."
}
Write-Host "Verified: normal input succeeds; $expected."
