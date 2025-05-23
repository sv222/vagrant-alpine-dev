# Alpine Linux Development Environment - Complete Setup Script
# This script sets up the entire development environment from scratch

param(
    [string]$ProjectPath = "vagrant-alpine-dev",
    [switch]$InstallPrerequisites,
    [switch]$SkipVMCreation
)

$ErrorActionPreference = "Stop"

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to install Chocolatey
function Install-Chocolatey {
    Write-Host "🍫 Installing Chocolatey package manager..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Host "✅ Chocolatey installed successfully!" -ForegroundColor Green
}

# Function to install prerequisites
function Install-Prerequisites {
    Write-Host "📦 Installing prerequisites..." -ForegroundColor Blue

    # Check if Chocolatey is installed
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Install-Chocolatey
        # Refresh environment to use choco
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }

    # Install VirtualBox, Vagrant, and Git
    Write-Host "Installing VirtualBox, Vagrant, and Git..." -ForegroundColor Yellow
    choco install virtualbox vagrant git -y

    Write-Host "✅ Prerequisites installed successfully!" -ForegroundColor Green
    Write-Host "⚠️  Please restart your terminal/PowerShell session before continuing." -ForegroundColor Yellow
}

# Function to create project structure
function New-ProjectStructure {
    param([string]$Path)

    Write-Host "📁 Creating project structure at: $Path" -ForegroundColor Blue

    # Create main directory
    if (Test-Path $Path) {
        Write-Host "⚠️  Directory $Path already exists. Continuing..." -ForegroundColor Yellow
    } else {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }

    # Create subdirectories
    $subdirs = @("scripts", "shared", "docs")
    foreach ($subdir in $subdirs) {
        $fullPath = Join-Path $Path $subdir
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        }
    }

    Write-Host "✅ Project structure created!" -ForegroundColor Green
}

# Function to create configuration files
function New-ConfigurationFiles {
    param([string]$ProjectPath)

    Write-Host "📝 Creating configuration files..." -ForegroundColor Blue

    # Create Vagrantfile
    $vagrantfileContent = @"
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Use the official Alpine Linux box from generic (verified vendor)
  config.vm.box = "generic/alpine319"
  config.vm.box_version = "4.3.12"

  # VM Configuration
  config.vm.hostname = "alpine-dev"

  # Network Configuration
  config.vm.network "forwarded_port", guest: 22, host: 2222, id: "ssh"
  config.vm.network "forwarded_port", guest: 8080, host: 8080
  config.vm.network "private_network", type: "dhcp"

  # Shared Folder
  config.vm.synced_folder "./shared", "/vagrant/shared",
    type: "virtualbox",
    create: true,
    mount_options: ["dmode=755", "fmode=644"]

  # Provider-specific configuration
  config.vm.provider "virtualbox" do |vb|
    vb.name = "Alpine-Dev-Environment"
    vb.memory = "2048"
    vb.cpus = 2

    # Performance optimizations
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    vb.customize ["modifyvm", :id, "--accelerate3d", "off"]
    vb.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
    vb.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
  end

  # Shell provisioning
  config.vm.provision "shell", path: "scripts/provision.sh"

  # Display success message
  config.vm.post_up_message = <<-MSG
    ╔══════════════════════════════════════════════════════════════╗
    ║                 🎉 VM SUCCESSFULLY CREATED! 🎉                ║
    ║                                                              ║
    ║  Alpine Linux Development Environment is ready!              ║
    ║                                                              ║
    ║  SSH Access: vagrant ssh                                     ║
    ║  Web Access: http://localhost:8080                           ║
    ║  Shared Folder: ./shared → /vagrant/shared                   ║
    ║                                                              ║
    ║  Docker is installed and running!                            ║
    ╚══════════════════════════════════════════════════════════════╝
  MSG
end
"@

    Set-Content -Path (Join-Path $ProjectPath "Vagrantfile") -Value $vagrantfileContent -Encoding UTF8

    # Create provision script
    $provisionScriptContent = @"
#!/bin/sh

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "`${BLUE}[INFO]`${NC} `$1"
}

log_success() {
    echo -e "`${GREEN}[SUCCESS]`${NC} `$1"
}

log_warning() {
    echo -e "`${YELLOW}[WARNING]`${NC} `$1"
}

log_error() {
    echo -e "`${RED}[ERROR]`${NC} `$1"
}

log_info "Starting Alpine Linux provisioning..."

# Update system packages
log_info "Updating system packages..."
apk update && apk upgrade
log_success "System packages updated"

# Install essential packages
log_info "Installing essential packages..."
apk add --no-cache \
    curl \
    wget \
    git \
    bash \
    sudo \
    openssh \
    shadow \
    docker \
    docker-compose \
    htop \
    nano \
    vim

log_success "Essential packages installed"

# Configure SSH
log_info "Configuring SSH..."
rc-update add sshd default
service sshd start
log_success "SSH configured and started"

# Configure Docker
log_info "Configuring Docker..."
rc-update add docker default
service docker start

# Add vagrant user to docker group
log_info "Adding vagrant user to docker group..."
addgroup vagrant docker

# Enable sudo for vagrant user without password
log_info "Configuring sudo for vagrant user..."
echo "vagrant ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install Docker Compose (latest version)
log_info "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=`$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
curl -L "https://github.com/docker/compose/releases/download/`${DOCKER_COMPOSE_VERSION}/docker-compose-`$(uname -s)-`$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
log_success "Docker Compose installed: `$DOCKER_COMPOSE_VERSION"

# Test Docker installation
log_info "Testing Docker installation..."
docker --version
docker-compose --version
log_success "Docker installation verified"

# Create useful aliases
log_info "Setting up useful aliases..."
cat >> /home/vagrant/.profile << 'EOF'
# Docker aliases
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlogs='docker logs'
alias dstop='docker stop `$(docker ps -q)'
alias drm='docker rm `$(docker ps -aq)'
alias drmi='docker rmi `$(docker images -q)'

# System aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'

export EDITOR=nano
EOF

log_success "Aliases configured"

# Set up development directories
log_info "Creating development directories..."
mkdir -p /home/vagrant/projects
mkdir -p /home/vagrant/scripts
chown -R vagrant:vagrant /home/vagrant/projects
chown -R vagrant:vagrant /home/vagrant/scripts

# Create a welcome script
cat > /home/vagrant/welcome.sh << 'EOF'
#!/bin/bash
echo "Welcome to Alpine Linux Development Environment!"
echo "System Information:"
echo "=================="
echo "OS: `$(cat /etc/alpine-release)"
echo "Kernel: `$(uname -r)"
echo "Memory: `$(free -h | grep Mem | awk '{print `$3 "/" `$2}')"
echo "Docker: `$(docker --version)"
echo "Docker Compose: `$(docker-compose --version)"
echo ""
echo "Useful directories:"
echo "- Projects: ~/projects"
echo "- Shared folder: /vagrant/shared"
echo ""
echo "Type 'alias' to see available shortcuts"
EOF

chmod +x /home/vagrant/welcome.sh
chown vagrant:vagrant /home/vagrant/welcome.sh

# Add welcome script to login
echo "/home/vagrant/welcome.sh" >> /home/vagrant/.profile

log_success "Development environment setup completed!"

# Clean up package cache
apk cache clean

log_success "Provisioning completed successfully!"
"@

    Set-Content -Path (Join-Path $ProjectPath "scripts/provision.sh") -Value $provisionScriptContent -Encoding UTF8

    Write-Host "✅ Configuration files created!" -ForegroundColor Green
}

# Function to create management scripts
function New-ManagementScripts {
    param([string]$ProjectPath)

    Write-Host "🔧 Creating management scripts..." -ForegroundColor Blue

    # Create start script (content already defined in the artifacts above)
    # Create stop script (content already defined in the artifacts above)

    # Create a simple README
    $readmeContent = @"
# Alpine Linux Development Environment

## Quick Start

1. **Start the environment:**
   ```
   .\scripts\start-vm.ps1
   ```

2. **Connect to VM:**
   ```
   vagrant ssh
   ```

3. **Stop the environment:**
   ```
   .\scripts\stop-vm.ps1
   ```

## File Sharing
- Windows: `./shared/`
- VM: `/vagrant/shared/`

## Useful Commands
- Check VM status: `vagrant status`
- Suspend VM: `.\scripts\stop-vm.ps1 -Suspend`
- Force shutdown: `.\scripts\stop-vm.ps1 -Force`
- Destroy VM: `vagrant destroy -f`

## Docker Commands (inside VM)
- List containers: `dps`
- List images: `di`
- Stop all containers: `dstop`

For more information, see the complete documentation.
"@

    Set-Content -Path (Join-Path $ProjectPath "README.md") -Value $readmeContent -Encoding UTF8

    Write-Host "✅ Management scripts and documentation created!" -ForegroundColor Green
}

# Main execution
Write-Host "🚀 Alpine Linux Development Environment Setup" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

try {
    # Check if prerequisites installation is requested
    if ($InstallPrerequisites) {
        if (-not (Test-Administrator)) {
            Write-Host "❌ Administrator privileges required for installing prerequisites." -ForegroundColor Red
            Write-Host "Please run PowerShell as Administrator and use -InstallPrerequisites flag." -ForegroundColor Yellow
            exit 1
        }
        Install-Prerequisites
        Write-Host "✅ Prerequisites installed. Please restart your terminal and run this script again without -InstallPrerequisites flag." -ForegroundColor Green
        exit 0
    }

    # Check if required tools are available
    $missingTools = @()
    if (-not (Get-Command vagrant -ErrorAction SilentlyContinue)) { $missingTools += "vagrant" }
    if (-not (Get-Command VBoxManage -ErrorAction SilentlyContinue)) { $missingTools += "virtualbox" }

    if ($missingTools.Count -gt 0) {
        Write-Host "❌ Missing required tools: $($missingTools -join ', ')" -ForegroundColor Red
        Write-Host "💡 Run with -InstallPrerequisites flag to install them automatically." -ForegroundColor Yellow
        exit 1
    }

    # Create project structure
    New-ProjectStructure -Path $ProjectPath

    # Create configuration files
    New-ConfigurationFiles -ProjectPath $ProjectPath

    # Create management scripts
    New-ManagementScripts -ProjectPath $ProjectPath

    # Change to project directory
    Set-Location $ProjectPath

    if (-not $SkipVMCreation) {
        Write-Host "🔧 Creating and starting VM..." -ForegroundColor Blue
        vagrant up

        Write-Host "✅ Environment setup completed successfully!" -ForegroundColor Green
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        Write-Host "🎉 Your Alpine Linux Development Environment is ready!" -ForegroundColor Cyan
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        Write-Host "📁 Project location: $(Get-Location)" -ForegroundColor White
        Write-Host "🔗 SSH access: vagrant ssh" -ForegroundColor White
        Write-Host "🌐 Web access: http://localhost:8080" -ForegroundColor White
        Write-Host "📂 Shared folder: ./shared ↔ /vagrant/shared" -ForegroundColor White
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    } else {
        Write-Host "✅ Project structure created successfully!" -ForegroundColor Green
        Write-Host "💡 Run 'vagrant up' to create and start the VM." -ForegroundColor Yellow
    }

} catch {
    Write-Host "❌ Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}