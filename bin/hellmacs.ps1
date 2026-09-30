<#
.SYNOPSIS
  Hellmacs command-line tool for PowerShell / Windows.
.DESCRIPTION
  Runs Emacs in batch mode against this checkout or launches Hellmacs interactively.
  Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
  License: GPL-3.0-or-later
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

$ErrorActionPreference = "Stop"

$HellmacsRoot = Split-Path -Parent $PSScriptRoot
$EmacsCmd = if ($env:EMACS) { $env:EMACS } else { "emacs" }

$ProfileName = $null
$HellmacsDir = $null
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
                $env:HELLMACS_PROFILE = $ProfileName
            }
        }
        '^--profile=(.*)$' {
            $ProfileName = $Matches[1]
            $env:HELLMACS_PROFILE = $ProfileName
        }
        '^--hellmacsdir$' {
            $i++
            if ($i -lt $ScriptArgs.Count) {
                $HellmacsDir = $ScriptArgs[$i]
                $env:HELLMACSDIR = $HellmacsDir
            }
        }
        '^--hellmacsdir=(.*)$' {
            $HellmacsDir = $Matches[1]
            $env:HELLMACSDIR = $HellmacsDir
        }
        '^(-D|--debug)$' {
            $DebugMode = $true
            $env:DEBUG = "1"
        }
        '^(-!|--force)$' {
            $ForceMode = $true
            $env:HELLMACS_FORCE = "1"
        }
        default {
            while ($i -lt $ScriptArgs.Count) {
                $RemainingArgs.Add($ScriptArgs[$i])
                $i++
            }
            break
        }
    }
    $i++
}

function Invoke-HellmacsBatch {
    param([string[]]$CliArgs)
    & $EmacsCmd --batch `
        -l "$HellmacsRoot/early-init.el" `
        --eval "(require 'hellmacs-cli)" `
        -f hellmacs-cli-main -- @CliArgs
}

if ($RemainingArgs.Count -eq 0) {
    Invoke-HellmacsBatch @("help")
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
            $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("hellmacs-sandbox-" + [System.Guid]::NewGuid().ToString("N"))
            $env:XDG_CONFIG_HOME = Join-Path $TempDir "config"
            $env:XDG_DATA_HOME = Join-Path $TempDir "data"
            $env:XDG_CACHE_HOME = Join-Path $TempDir "cache"
            $env:XDG_STATE_HOME = Join-Path $TempDir "state"
            $env:HELLMACSDIR = Join-Path $TempDir "config/hellmacs"
            New-Item -ItemType Directory -Force -Path $env:HELLMACSDIR, $env:XDG_DATA_HOME, $env:XDG_CACHE_HOME, $env:XDG_STATE_HOME | Out-Null
            Write-Host "Starting Hellmacs sandbox in $TempDir"
            $SandboxArgs = if ($CommandArgs.Count -gt 1) { $CommandArgs[1..($CommandArgs.Count - 1)] } else { @() }
            try {
                & $EmacsCmd --init-directory $HellmacsRoot @SandboxArgs
            } finally {
                Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
            }
            exit $LASTEXITCODE
        }
        $EmacsLaunchArgs = @("--init-directory", $HellmacsRoot)
        if ($ProfileName) {
            $EmacsLaunchArgs += @("--profile", $ProfileName)
        }
        $EmacsLaunchArgs += $CommandArgs
        & $EmacsCmd @EmacsLaunchArgs
        exit $LASTEXITCODE
    }
    "upgrade" {
        if ($CommandArgs -notcontains "--packages") {
            Invoke-HellmacsBatch @("upgrade-self")
        }
        Invoke-HellmacsBatch @($Command) + $CommandArgs
        exit $LASTEXITCODE
    }
    "up" {
        if ($CommandArgs -notcontains "--packages") {
            Invoke-HellmacsBatch @("upgrade-self")
        }
        Invoke-HellmacsBatch @($Command) + $CommandArgs
        exit $LASTEXITCODE
    }
    default {
        Invoke-HellmacsBatch @($Command) + $CommandArgs
        exit $LASTEXITCODE
    }
}
