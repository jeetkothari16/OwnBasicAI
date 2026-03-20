#Requires -Version 5.1
<#
.SYNOPSIS
    Foolproof Miniconda installer for Windows (PowerShell 5.1+)

.DESCRIPTION
    1. Detects existing Anaconda / Miniconda / conda installations
    2. Checks prerequisites (architecture, PowerShell version, disk space)
    3. Downloads the latest official Miniconda installer
    4. Verifies the SHA-256 checksum against Anaconda's published hash
    5. Runs a fully silent install
    6. Optionally initialises conda for PowerShell and CMD
    7. Cleans up the installer file

.PARAMETER Prefix
    Installation directory. Default: %USERPROFILE%\miniconda3
    NOTE: Path must NOT contain spaces (Miniconda limitation).

.PARAMETER SkipInit
    Skip running 'conda init'. Useful for CI/CD pipelines.

.PARAMETER Force
    Proceed even if an existing installation is detected.
    Does NOT remove the old installation -- choose a different -Prefix.

.PARAMETER AllUsers
    Install for all users (requires Administrator privileges).

.EXAMPLE
    .\Install-Miniconda.ps1
    .\Install-Miniconda.ps1 -Prefix "C:\Tools\miniconda3"
    .\Install-Miniconda.ps1 -Force -SkipInit
    .\Install-Miniconda.ps1 -AllUsers

.NOTES
    Run with:  powershell -ExecutionPolicy Bypass -File .\Install-Miniconda.ps1
    Or set policy first: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#>

[CmdletBinding()]
param(
    [string] $Prefix  = "$env:USERPROFILE\miniconda3",
    [switch] $SkipInit,
    [switch] $Force,
    [switch] $AllUsers
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
function Write-Info    { param([string]$Msg) Write-Host "[INFO]  $Msg" -ForegroundColor Cyan   }
function Write-Ok      { param([string]$Msg) Write-Host "[OK]    $Msg" -ForegroundColor Green  }
function Write-Warn    { param([string]$Msg) Write-Host "[WARN]  $Msg" -ForegroundColor Yellow }
function Write-Err     { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red    }
function Write-Section { param([string]$Msg) Write-Host ""; Write-Host "==> $Msg" -ForegroundColor White }
function Abort         { param([string]$Msg) Write-Err $Msg; exit 1 }

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   Miniconda Installer for Windows        |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# Step 1: Detect existing installations
# ---------------------------------------------------------------------------
Write-Section "Checking for existing conda / Miniconda / Anaconda installations"

$existingFound = $false

# 1a. Is conda already on PATH?
$condaInPath = Get-Command conda -ErrorAction SilentlyContinue
if ($condaInPath) {
    Write-Warn "conda is already on PATH: $($condaInPath.Source)"
    try {
        $ver = & conda --version 2>&1
        Write-Warn "  Version: $ver"
    } catch { }
    $existingFound = $true
}

# 1b. Scan common install directories
$commonPaths = @(
    "$env:USERPROFILE\miniconda3",
    "$env:USERPROFILE\miniconda",
    "$env:USERPROFILE\Miniconda3",
    "$env:USERPROFILE\anaconda3",
    "$env:USERPROFILE\Anaconda3",
    "C:\miniconda3",
    "C:\Miniconda3",
    "C:\anaconda3",
    "C:\Anaconda3",
    "C:\ProgramData\miniconda3",
    "C:\ProgramData\Miniconda3",
    "C:\ProgramData\anaconda3",
    "C:\ProgramData\Anaconda3"
)

foreach ($p in $commonPaths) {
    if (Test-Path $p) {
        Write-Warn "Found existing conda directory: $p"
        $existingFound = $true
    }
}

# 1c. Check registry for Anaconda/Miniconda uninstall entries
$regRoots = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)
foreach ($root in $regRoots) {
    if (Test-Path $root) {
        $entries = Get-ChildItem $root -ErrorAction SilentlyContinue | Where-Object {
            ($_.GetValue('DisplayName') -match 'miniconda|anaconda') -or
            ($_.GetValue('Publisher')   -match 'anaconda')
        }
        foreach ($e in $entries) {
            $name    = $e.GetValue('DisplayName')
            $version = $e.GetValue('DisplayVersion')
            $loc     = $e.GetValue('InstallLocation')
            Write-Warn "Registry entry found: $name $version at $loc"
            $existingFound = $true
        }
    }
}

# 1d. Check PowerShell profile for conda init block
$profiles = @($PROFILE.CurrentUserCurrentHost, $PROFILE.CurrentUserAllHosts)
foreach ($prof in $profiles) {
    if ((Test-Path $prof) -and (Select-String -Path $prof -Pattern 'conda initialize' -Quiet -ErrorAction SilentlyContinue)) {
        Write-Warn "A 'conda initialize' block was found in: $prof"
        $existingFound = $true
    }
}

# 1e. Decision
if ($existingFound) {
    if ($Force) {
        Write-Warn "-Force flag set. Proceeding despite existing installation."
        Write-Warn "Existing directories will NOT be removed."
    } else {
        Write-Host ""
        Write-Warn "An existing Anaconda/Miniconda installation appears to be present."
        Write-Warn "To avoid conflicts, this script will NOT install again."
        Write-Host ""
        Write-Info "Your options:"
        Write-Info "  1. Use the existing installation: open Anaconda Prompt or run 'conda --version'"
        Write-Info "  2. Re-run with -Force to install anyway (choose a different -Prefix to avoid clashes)"
        Write-Info "  3. Uninstall the existing version via Control Panel, then re-run this script"
        Write-Host ""
        exit 0
    }
} else {
    Write-Ok "No existing conda installation detected."
}

# ---------------------------------------------------------------------------
# Step 2: Validate install prefix
# ---------------------------------------------------------------------------
Write-Section "Validating install prefix: $Prefix"

if ($Prefix -match ' ') {
    Abort "The install path must NOT contain spaces: '$Prefix'`nChoose a path like C:\Tools\miniconda3"
}

if (Test-Path $Prefix) {
    if ($Force) {
        Write-Warn "Target directory already exists: $Prefix"
        Write-Warn "The installer will attempt to install into it anyway."
    } else {
        Abort "Target directory already exists: $Prefix`nUse -Force to proceed anyway, or choose a different -Prefix."
    }
} else {
    Write-Ok "Install prefix is available."
}

# ---------------------------------------------------------------------------
# Step 3: Verify architecture
# ---------------------------------------------------------------------------
Write-Section "Verifying system architecture"

$arch = $env:PROCESSOR_ARCHITECTURE
$installerUrl = $null

if ($arch -eq 'AMD64') {
    $installerUrl = 'https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe'
    Write-Ok "Architecture: AMD64 -- using standard 64-bit installer."
} elseif ($arch -eq 'ARM64') {
    $installerUrl = 'https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-arm64.exe'
    Write-Ok "Architecture: ARM64 -- using ARM64 installer."
} elseif ($arch -eq 'x86') {
    Abort "32-bit Windows is no longer supported by current Miniconda releases. Please use a 64-bit system."
} else {
    Abort "Unsupported or unrecognised architecture: $arch"
}

# ---------------------------------------------------------------------------
# Step 4: Check prerequisites
# ---------------------------------------------------------------------------
Write-Section "Checking prerequisites"

Write-Ok "PowerShell version: $($PSVersionTable.PSVersion)"

# Disk space: require at least 3 GB free on target drive
$driveLetter = (Split-Path -Qualifier $Prefix).TrimEnd(':')
$drive = Get-PSDrive -Name $driveLetter -ErrorAction SilentlyContinue
if ($drive) {
    $freeGB = [math]::Round($drive.Free / 1GB, 2)
    if ($freeGB -lt 3) {
        Abort "Insufficient disk space on drive ${driveLetter}: -- ${freeGB} GB free, 3 GB required."
    }
    Write-Ok "Disk space on ${driveLetter}: -- ${freeGB} GB free (3 GB minimum required)."
} else {
    Write-Warn "Could not check disk space for drive ${driveLetter}. Continuing."
}

# Admin check (only required for -AllUsers)
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($AllUsers -and -not $isAdmin) {
    Abort "-AllUsers requires Administrator privileges.`nRe-run PowerShell as Administrator, or omit -AllUsers for a per-user install."
}
if ($isAdmin) {
    Write-Ok "Running as Administrator."
} else {
    Write-Ok "Running as current user (no Administrator privileges needed for per-user install)."
}

# Internet connectivity check
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $tcp.Connect('repo.anaconda.com', 443)
    $tcp.Close()
    Write-Ok "Internet connectivity to repo.anaconda.com confirmed."
} catch {
    Abort "Cannot reach repo.anaconda.com on port 443.`nCheck your internet connection or firewall settings."
}

# ---------------------------------------------------------------------------
# Step 5: Download installer
# ---------------------------------------------------------------------------
Write-Section "Downloading Miniconda installer"

$tmpInstaller = Join-Path $env:TEMP "miniconda_installer_$PID.exe"
Write-Info "URL : $installerUrl"
Write-Info "Dest: $tmpInstaller"

try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $installerUrl -OutFile $tmpInstaller -UseBasicParsing
    $ProgressPreference = 'Continue'
    $sizeMB = [math]::Round((Get-Item $tmpInstaller).Length / 1MB, 1)
    Write-Ok "Download complete. Size: ${sizeMB} MB"
} catch {
    Abort "Download failed: $_`nCheck your internet connection or proxy settings."
}

# ---------------------------------------------------------------------------
# Step 6: Verify SHA-256 checksum
# ---------------------------------------------------------------------------
Write-Section "Verifying SHA-256 checksum"

$actualHash = (Get-FileHash -Path $tmpInstaller -Algorithm SHA256).Hash.ToLower()
Write-Info "Installer SHA-256: $actualHash"

$expectedHash = $null
try {
    $ProgressPreference = 'SilentlyContinue'
    $hashPage = Invoke-WebRequest -Uri 'https://repo.anaconda.com/miniconda/' -UseBasicParsing -TimeoutSec 15
    $ProgressPreference = 'Continue'
    $installerFilename = [System.IO.Path]::GetFileName($installerUrl)
    $escapedName = [regex]::Escape($installerFilename)
    if ($hashPage.Content -match "$escapedName[\s\S]{0,300}?([a-f0-9]{64})") {
        $expectedHash = $Matches[1].ToLower()
    }
} catch {
    Write-Warn "Could not fetch the checksum page: $_"
}

if ($expectedHash) {
    Write-Info "Expected SHA-256: $expectedHash"
    Write-Info "Actual   SHA-256: $actualHash"
    if ($actualHash -eq $expectedHash) {
        Write-Ok "Checksum verified -- installer is intact."
    } else {
        Remove-Item $tmpInstaller -Force -ErrorAction SilentlyContinue
        Abort "Checksum MISMATCH! The file may be corrupted or tampered with.`nExpected: $expectedHash`nActual  : $actualHash"
    }
} else {
    Write-Warn "Could not retrieve the official checksum to compare against."
    Write-Warn "Proceeding without checksum verification."
    Write-Warn "You can verify manually at: https://repo.anaconda.com/miniconda/"
}

# ---------------------------------------------------------------------------
# Step 7: Run silent installer
# ---------------------------------------------------------------------------
Write-Section "Installing Miniconda to: $Prefix"

$installType = if ($AllUsers) { 'AllUsers' } else { 'JustMe' }

# Official silent-mode flags (per Anaconda docs):
#   /S                     = silent, no GUI
#   /InstallationType=...  = JustMe or AllUsers
#   /RegisterPython=0      = do not register as default system Python
#   /AddToPath=0           = do not modify PATH (conda init handles activation)
#   /D=<path>              = install dir; must be LAST, no quotes, no spaces allowed
$installerArgs = "/S /InstallationType=$installType /RegisterPython=0 /AddToPath=0 /D=$Prefix"

Write-Info "Running installer (this may take a minute)..."

try {
    $proc = Start-Process -FilePath $tmpInstaller -ArgumentList $installerArgs -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        Abort "Installer exited with code $($proc.ExitCode). Installation may have failed."
    }
    Write-Ok "Miniconda installed successfully (exit code 0)."
} catch {
    Abort "Failed to launch installer: $_"
}

# ---------------------------------------------------------------------------
# Step 8: Initialise conda
# ---------------------------------------------------------------------------
Write-Section "Initialising conda"

$condaBin = Join-Path $Prefix 'Scripts\conda.exe'

if (-not (Test-Path $condaBin)) {
    Write-Warn "conda.exe not found at expected path: $condaBin"
    Write-Warn "Installation may be incomplete. Skipping conda init."
} elseif ($SkipInit) {
    Write-Warn "-SkipInit set. Skipping 'conda init'."
    Write-Warn "To activate conda manually later, run:"
    Write-Warn "  & '$Prefix\Scripts\activate.bat'"
} else {
    Write-Info "Running 'conda init' for PowerShell and CMD..."
    try {
        & $condaBin init powershell 2>&1 | ForEach-Object { Write-Info $_ }
        & $condaBin init cmd.exe     2>&1 | ForEach-Object { Write-Info $_ }
        Write-Ok "conda init complete."
    } catch {
        Write-Warn "conda init encountered an error: $_"
        Write-Warn "You can run it manually later: conda init powershell"
    }

    # Fix ExecutionPolicy if too restrictive for conda's profile script
    $execPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($execPolicy -eq 'Restricted' -or $execPolicy -eq 'Undefined') {
        Write-Warn "PowerShell ExecutionPolicy is '$execPolicy'."
        Write-Warn "Setting to RemoteSigned for CurrentUser so conda's profile script can run..."
        try {
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Ok "ExecutionPolicy set to RemoteSigned for CurrentUser."
        } catch {
            Write-Warn "Could not set ExecutionPolicy automatically: $_"
            Write-Warn "Run this manually in an elevated PowerShell window:"
            Write-Warn "  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
        }
    } else {
        Write-Ok "ExecutionPolicy is '$execPolicy' -- no change needed."
    }
}

# ---------------------------------------------------------------------------
# Step 9: Clean up
# ---------------------------------------------------------------------------
# Write-Section "Cleaning up"
# Remove-Item $tmpInstaller -Force -ErrorAction SilentlyContinue
# Write-Ok "Installer file removed."

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  +----------------------------------------------------+" -ForegroundColor Green
Write-Host "  |   Miniconda installation complete!                 |" -ForegroundColor Green
Write-Host "  +----------------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Info "Installed to : $Prefix"
Write-Info "conda binary : $Prefix\Scripts\conda.exe"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Close and re-open PowerShell (or CMD) to activate conda."
Write-Host "  2. Verify the install:     conda --version"
Write-Host "  3. Create an environment:  conda create -n myenv python=3.11"
Write-Host "  4. Activate it:            conda activate myenv"
Write-Host ""
Write-Warn "NOTE: Commercial use of Miniconda may require a paid Anaconda licence."
Write-Warn "      See: https://www.anaconda.com/legal"
Write-Host ""