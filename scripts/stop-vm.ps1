# Alpine Linux Development Environment - Stop Script
# This script gracefully stops the Vagrant VM

param(
    [switch]$Force,
    [switch]$Suspend
)

$ErrorActionPreference = "Stop"

Write-Host "🛑 Stopping Alpine Linux Development Environment..." -ForegroundColor Yellow

try {
    # Change to the directory containing Vagrantfile
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $vagrantPath = Split-Path -Parent $scriptPath
    Set-Location $vagrantPath

    # Check if Vagrantfile exists
    if (-not (Test-Path "Vagrantfile")) {
        throw "Vagrantfile not found in current directory: $(Get-Location)"
    }

    # Check VM status first
    $status = vagrant status --machine-readable | Where-Object { $_ -match "state," }

    if ($status -match "not_created") {
        Write-Host "ℹ️ VM is not created yet." -ForegroundColor Blue
        return
    }

    if ($status -match "poweroff") {
        Write-Host "ℹ️ VM is already stopped." -ForegroundColor Blue
        return
    }

    # Stop VM based on parameters
    if ($Force) {
        Write-Host "⚡ Force stopping VM..." -ForegroundColor Red
        vagrant halt --force
    } elseif ($Suspend) {
        Write-Host "💤 Suspending VM..." -ForegroundColor Blue
        vagrant suspend
    } else {
        Write-Host "🔄 Gracefully stopping VM..." -ForegroundColor Green
        vagrant halt
    }

    # Verify VM is stopped
    Start-Sleep -Seconds 2
    $newStatus = vagrant status --machine-readable | Where-Object { $_ -match "state," }

    if ($newStatus -match "poweroff" -or $newStatus -match "saved") {
        Write-Host "✅ VM stopped successfully!" -ForegroundColor Green

        if ($Suspend) {
            Write-Host "💡 Use 'vagrant resume' or '.\scripts\start-vm.ps1' to resume" -ForegroundColor Cyan
        } else {
            Write-Host "💡 Use '.\scripts\start-vm.ps1' to start again" -ForegroundColor Cyan
        }
    } else {
        throw "Failed to stop VM properly"
    }

} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Try using -Force parameter for force shutdown" -ForegroundColor Yellow
    exit 1
}
