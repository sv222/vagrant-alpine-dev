# Alpine Linux Development Environment - Start Script
# This script starts the Vagrant VM and provides connection information

param(
    [switch]$Provision,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Alpine Linux Development Environment..." -ForegroundColor Green

try {
    # Change to the directory containing Vagrantfile
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $vagrantPath = Split-Path -Parent $scriptPath
    Set-Location $vagrantPath

    # Check if Vagrantfile exists
    if (-not (Test-Path "Vagrantfile")) {
        throw "Vagrantfile not found in current directory: $(Get-Location)"
    }

    # Start VM
    if ($Provision) {
        Write-Host "🔧 Starting VM with provisioning..." -ForegroundColor Yellow
        vagrant up --provision
    } else {
        Write-Host "▶️ Starting VM..." -ForegroundColor Blue
        vagrant up
    }

    # Wait a moment for services to stabilize
    Start-Sleep -Seconds 3

    # Get VM status
    $status = vagrant status --machine-readable | Where-Object { $_ -match "state," }

    if ($status -match "running") {
        Write-Host "`n✅ VM Started Successfully!" -ForegroundColor Green
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        Write-Host "🔗 Connection Information:" -ForegroundColor Cyan
        Write-Host "   SSH Access: vagrant ssh" -ForegroundColor White
        Write-Host "   Web Access: http://localhost:8080" -ForegroundColor White
        Write-Host "   Shared Folder: ./shared ↔ /vagrant/shared" -ForegroundColor White
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

        if ($Verbose) {
            Write-Host "`n📊 VM Information:" -ForegroundColor Magenta
            vagrant ssh -c "cat /etc/alpine-release && docker --version"
        }

        Write-Host "`n💡 Quick Commands:" -ForegroundColor Yellow
        Write-Host "   Connect: vagrant ssh" -ForegroundColor White
        Write-Host "   Stop VM: .\scripts\stop-vm.ps1" -ForegroundColor White
        Write-Host "   VM Status: vagrant status" -ForegroundColor White

    } else {
        throw "VM failed to start properly"
    }

} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}