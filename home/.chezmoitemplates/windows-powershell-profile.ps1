function y {
    $tmp = (New-TemporaryFile).FullName

    yazi.exe @args --cwd-file="$tmp"

    $cwd = Get-Content -Path $tmp -Encoding UTF8

    if (
        $cwd `
        -and $cwd -ne $PWD.Path `
        -and (Test-Path -LiteralPath $cwd -PathType Container)
    ) {
        Set-Location -LiteralPath (Resolve-Path -LiteralPath $cwd).Path
    }

    Remove-Item -Path $tmp
}

Invoke-Expression (& { (zoxide init powershell | Out-String) })

# Expose prompt, input and output boundaries to WezTerm so Prefix+Shift-V can
# copy the most recent command block. Preserve any prompt installed above and
# keep profile re-sourcing idempotent.
if ($env:TERM_PROGRAM -eq "WezTerm" -and -not $Global:__DotfilesWezTermIntegration) {
    $Global:__DotfilesWezTermIntegration = $true
    $Global:__DotfilesWezTermCommandStarted = $false
    $Global:__DotfilesOriginalPrompt = $function:Prompt

    function Global:prompt {
        $lastCommandSucceeded = $?
        $lastStatus = if ($lastCommandSucceeded) { 0 } else { -1 }
        $out = ""

        if ($Global:__DotfilesWezTermCommandStarted) {
            $out += "`e]133;D;$lastStatus`a"
        }
        $out += "`e]133;A`a"
        $out += [string]$Global:__DotfilesOriginalPrompt.Invoke()
        $out += "`e]133;B`a"
        $Global:__DotfilesWezTermCommandStarted = $false
        return $out
    }

    if (Get-Module -Name PSReadLine) {
        Set-PSReadLineKeyHandler -Chord Enter -BriefDescription "WezTermAcceptLine" `
            -Description "Mark command output, then accept the line" -ScriptBlock {
                $line = $null
                $cursor = 0
                [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState(
                    [ref]$line,
                    [ref]$cursor
                )
                $tokens = $null
                $parseErrors = $null
                [System.Management.Automation.Language.Parser]::ParseInput(
                    $line,
                    [ref]$tokens,
                    [ref]$parseErrors
                ) | Out-Null

                $incomplete = @(
                    $parseErrors | Where-Object { $_.IncompleteInput }
                ).Count -gt 0
                if (-not $incomplete) {
                    $Host.UI.Write("`e]133;C;`a")
                    $Global:__DotfilesWezTermCommandStarted = $true
                }
                [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            }
    }
}
