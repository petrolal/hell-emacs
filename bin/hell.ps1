<#
.SYNOPSIS
  Hell Emacs command-line tool for PowerShell / Windows.
.DESCRIPTION
  Runs Emacs in batch mode against this checkout or launches Hell Emacs interactively.
  Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
  License: GPL-3.0-or-later
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

$ErrorActionPreference = "Stop"

$HellRoot = Split-Path -Parent $PSScriptRoot
$EmacsCmd = if ($env:EMACS) { $env:EMACS } else { "emacs" }

$ProfileName = $null
$HellDir = $null
$DebugMode = $false
$ForceMode = $false
$RemainingArgs = [System.Collections.Generic.List[string]]::new()

$i = 0
while ($i -lt $ScriptArgs.Count) {
    $arg = $ScriptArgs[$i]
    switch -Regex ($arg) {
        '^(-p|--profile)$' {
            $i++
            if ($i -lt $ScriptArgs.Count) {
                $ProfileName = $ScriptArgs[$i]
                $env:HELL_PROFILE = $ProfileName
            }
        }
        '^--profile=(.*)$' {
            $ProfileName = $Matches[1]
            $env:HELL_PROFILE = $ProfileName
        }
        '^--helldir$' {
            $i++
            if ($i -lt $ScriptArgs.Count) {
                $HellDir = $ScriptArgs[$i]
                $env:HELLDIR = $HellDir
            }
        }
        '^--helldir=(.*)$' {
            $HellDir = $Matches[1]
            $env:HELLDIR = $HellDir
        }
        '^(-D|--debug)$' {
            $DebugMode = $true
            $env:DEBUG = "1"
        }
        '^(-!|--force)$' {
            $ForceMode = $true
            $env:HELL_FORCE = "1"
        }
        default {
            $RemainingArgs.Add($arg)
        }
    }
    $i++
}

function Invoke-HellBatch {
    param([string[]]$CliArgs)
    & $EmacsCmd --batch `
        -l "$HellRoot/early-init.el" `
        --eval "(require 'hell-cli)" `
        -f hell-cli-main -- @CliArgs
}

if ($RemainingArgs.Count -eq 0) {
    Invoke-HellBatch @("help")
    exit $LASTEXITCODE
}

$Command = $RemainingArgs[0]
$CommandArgs = if ($RemainingArgs.Count -gt 1) { $RemainingArgs[1..($RemainingArgs.Count - 1)] } else { @() }

switch ($Command) {
    "emacs" {
        if ($CommandArgs.Count -gt 0 -and $CommandArgs[0] -eq "--vanilla") {
            $VanillaArgs = if ($CommandArgs.Count -gt 1) { $CommandArgs[1..($CommandArgs.Count - 1)] } else { @() }
            & $EmacsCmd -Q @VanillaArgs
            exit $LASTEXITCODE
        }
        if ($CommandArgs.Count -gt 0 -and $CommandArgs[0] -eq "--sandbox") {
            $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("hell-sandbox-" + [System.Guid]::NewGuid().ToString("N"))
            $env:XDG_CONFIG_HOME = Join-Path $TempDir "config"
            $env:XDG_DATA_HOME = Join-Path $TempDir "data"
            $env:XDG_CACHE_HOME = Join-Path $TempDir "cache"
            $env:XDG_STATE_HOME = Join-Path $TempDir "state"
            $env:HELLDIR = Join-Path $TempDir "config/hell-emacs"
            New-Item -ItemType Directory -Force -Path $env:HELLDIR, $env:XDG_DATA_HOME, $env:XDG_CACHE_HOME, $env:XDG_STATE_HOME | Out-Null
            Write-Host "Starting Hell Emacs sandbox in $TempDir"
            $SandboxArgs = if ($CommandArgs.Count -gt 1) { $CommandArgs[1..($CommandArgs.Count - 1)] } else { @() }
            try {
                & $EmacsCmd --init-directory $HellRoot @SandboxArgs
            } finally {
                Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
            }
            exit $LASTEXITCODE
        }
        $EmacsLaunchArgs = @("--init-directory", $HellRoot)
        if ($ProfileName) {
            $EmacsLaunchArgs += @("--profile", $ProfileName)
        }
        $EmacsLaunchArgs += $CommandArgs
        & $EmacsCmd @EmacsLaunchArgs
        exit $LASTEXITCODE
    }
    "upgrade" {
        if ($CommandArgs -notcontains "--packages") {
            Invoke-HellBatch @("upgrade-self")
        }
        Invoke-HellBatch @($Command) + $CommandArgs
        exit $LASTEXITCODE
    }
    "up" {
        if ($CommandArgs -notcontains "--packages") {
            Invoke-HellBatch @("upgrade-self")
        }
        Invoke-HellBatch @($Command) + $CommandArgs
        exit $LASTEXITCODE
    }
    default {
        Invoke-HellBatch @($Command) + $CommandArgs
        exit $LASTEXITCODE
    }
}
