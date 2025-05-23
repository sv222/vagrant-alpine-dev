#!/bin/sh

# Script version
SCRIPT_VERSION="2.0.0"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_version() {
    echo -e "${CYAN}[VERSION]${NC} $1"
}

# Display script header
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║              Alpine Linux Provisioning Script              ║${NC}"
echo -e "${BOLD}${CYAN}║                     Version ${SCRIPT_VERSION}                        ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

log_info "Starting Alpine Linux provisioning..."

# Get current Alpine version
CURRENT_VERSION=$(cat /etc/alpine-release 2>/dev/null || echo "Unknown")
log_version "Current Alpine Linux version: $CURRENT_VERSION"

# Check for Alpine version upgrade (this section runs on every provision)
log_info "Checking for Alpine Linux version updates..."

# Get current major.minor version
CURRENT_MAJOR_MINOR=$(echo "$CURRENT_VERSION" | cut -d'.' -f1-2)
log_info "Current Alpine major.minor: $CURRENT_MAJOR_MINOR"

# Check latest Alpine version using the specified method
log_info "Fetching latest Alpine version from official repository..."
LATEST_VERSION=$(curl -s http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/ | grep -oE 'alpine-minirootfs-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f3)

# Verify if the check was successful and process the latest version info
if [ -n "$LATEST_VERSION" ] && echo "$LATEST_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
    log_success "Latest Alpine version found: $LATEST_VERSION"
    LATEST_MAJOR_MINOR=$(echo "$LATEST_VERSION" | cut -d'.' -f1-2)

    if [ "$LATEST_MAJOR_MINOR" != "$CURRENT_MAJOR_MINOR" ]; then
        log_warning "Alpine Linux major.minor upgrade available: $CURRENT_MAJOR_MINOR → $LATEST_MAJOR_MINOR"
        log_info "Attempting to upgrade Alpine Linux to $LATEST_MAJOR_MINOR..."

        # Store original repositories in case of rollback
        cp /etc/apk/repositories /etc/apk/repositories.bak

        # **FIX:** Overwrite /etc/apk/repositories to guarantee pointing to the new version
        log_info "Overwriting /etc/apk/repositories to point to v${LATEST_MAJOR_MINOR}..."
        {
            echo "http://dl-cdn.alpinelinux.org/alpine/v${LATEST_MAJOR_MINOR}/main"
            echo "http://dl-cdn.alpinelinux.org/alpine/v${LATEST_MAJOR_MINOR}/community"
            # If you need testing or other repositories, add them here:
            # echo "http://dl-cdn.alpinelinux.org/alpine/v${LATEST_MAJOR_MINOR}/testing"
        } > /etc/apk/repositories
        if [ $? -eq 0 ]; then # Check if the previous command was successful
            log_success "Repository configuration updated for v${LATEST_MAJOR_MINOR}."

            # Perform the major version upgrade
            log_info "Running apk update and apk upgrade for major version change..."
            # Perform a standard apk upgrade. This should handle kernel/initramfs updates properly.
            if apk update && apk upgrade; then
                log_success "Alpine Linux major version upgrade initiated. Packages upgraded."

                # Crucial step for Alpine: ensure persistent changes are committed for diskless mode
                # This ensures the new kernel and system changes are saved to persistent storage.
                if command -v lbu >/dev/null 2>&1; then
                    log_info "Committing changes with lbu..."
                    # **FIX:** Removed -d as it's not supported by older lbu versions.
                    # lbu commit might require LBU_BACKUPDIR/LBU_MEDIA or specific media.
                    # If this still fails and your VM is diskless, you need to configure lbu.
                    if lbu commit; then
                        log_success "lbu commit successful."
                    else
                        log_warning "lbu commit failed or not applicable. Ensure changes are persistent."
                        log_info "If reboot fails, investigate lbu configuration or persistence method for your Vagrant box."
                    fi
                else
                    log_info "lbu not found, skipping lbu commit (likely not a diskless setup)."
                fi

                touch /tmp/reboot_required # Mark for reboot at the end of the script
                log_info "A reboot is required to complete the Alpine major version upgrade."
            else
                log_error "Failed to upgrade Alpine Linux major version. Manual intervention might be necessary."
                # Attempt to revert repository changes if upgrade failed
                log_warning "Attempting to revert /etc/apk/repositories to previous version (v${CURRENT_MAJOR_MINOR})."
                mv /etc/apk/repositories.bak /etc/apk/repositories || log_error "Failed to revert repository configuration."
                exit 1 # Exit on critical failure
            fi
        else
            log_error "Failed to update /etc/apk/repositories. Skipping major version upgrade."
            exit 1 # Exit on critical failure
        fi
    else
        log_success "You are already on the latest stable major.minor version: $CURRENT_MAJOR_MINOR"
    fi
else
    log_error "Could not fetch latest Alpine version from official repository or invalid format. Skipping major version check."
fi

# Regular package updates (always run for current minor version)
log_info "Updating system packages..."
apk update

# Check if there are any upgradeable packages
UPGRADEABLE=$(apk list --upgradable 2>/dev/null | wc -l)

if [ "$UPGRADEABLE" -gt 1 ]; then
    log_warning "Found $((UPGRADEABLE - 1)) packages that can be upgraded"
    log_info "Upgrading system packages..."

    # Perform upgrade
    if apk upgrade; then
        # Get new version if it changed
        NEW_VERSION=$(cat /etc/alpine-release 2>/dev/null || echo "Unknown")
        if [ "$NEW_VERSION" != "$CURRENT_VERSION" ]; then
            log_success "Alpine Linux updated: $CURRENT_VERSION → $NEW_VERSION"
        else
            log_success "System packages upgraded (Alpine version unchanged, or only patch updates)"
        fi
    else
        log_error "Failed to upgrade system packages"
        exit 1
    fi
else
    log_success "System is already up to date"
fi

# Check if this is first run or subsequent run (this section runs only once for initial setup)
PROVISION_MARKER="/var/lib/vagrant-provision-complete"

if [ ! -f "$PROVISION_MARKER" ]; then
    log_info "First-time provisioning detected - installing essential packages and setting up environment..."

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
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    log_success "Docker Compose installed: $DOCKER_COMPOSE_VERSION"

    # Create useful aliases
    log_info "Setting up useful aliases..."
    cat >> /home/vagrant/.profile << 'EOF'
# Docker aliases
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlogs='docker logs'
alias dstop='docker stop $(docker ps -q)'
alias drm='docker rm $(docker ps -aq)'
alias drmi='docker rmi $(docker images -q)'

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
echo "OS: $(cat /etc/alpine-release)"
echo "Kernel: $(uname -r)"
echo "Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo "Docker: $(docker --version)"
echo "Docker Compose: $(docker-compose --version)"
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

    # Mark first-time provisioning as complete
    touch "$PROVISION_MARKER"
    echo "$(date): First-time provisioning completed" > "$PROVISION_MARKER"

    log_success "Initial development environment setup completed!"
else
    log_info "Subsequent run detected - skipping initial setup (packages, Docker, aliases, etc.)"
    LAST_PROVISION=$(cat "$PROVISION_MARKER" 2>/dev/null || echo "Unknown")
    log_info "Last initial setup completed: $LAST_PROVISION"
fi

# Always check and update Docker Compose if needed (runs on every provision)
log_info "Checking Docker Compose version..."
if command -v docker-compose >/dev/null 2>&1; then
    CURRENT_DC_VERSION=$(docker-compose --version | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    LATEST_DC_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)

    if [ "$CURRENT_DC_VERSION" != "$LATEST_DC_VERSION" ]; then
        log_warning "Docker Compose update available: $CURRENT_DC_VERSION → $LATEST_DC_VERSION"
        log_info "Updating Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/download/${LATEST_DC_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        log_success "Docker Compose updated to: $LATEST_DC_VERSION"
    else
        log_success "Docker Compose is up to date: $CURRENT_DC_VERSION"
    fi
else
    log_warning "Docker Compose not found - this should not happen after initial setup. Attempting to install..."
    # Re-attempt Docker Compose install if somehow missing after initial setup
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    log_success "Docker Compose re-installed: $DOCKER_COMPOSE_VERSION"
fi

# Test Docker installation (always run)
log_info "Verifying Docker installation..."
if docker --version && docker-compose --version; then
    log_success "Docker installation verified"
else
    log_error "Docker verification failed"
    exit 1 # Exit if Docker is not working
fi

# Update provision marker with current run timestamp
echo "$(date): Provisioning script v${SCRIPT_VERSION} completed" >> "$PROVISION_MARKER"

# Clean up package cache
apk cache clean

# Final status
FINAL_VERSION=$(cat /etc/alpine-release 2>/dev/null || echo "Unknown")
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                  PROVISIONING COMPLETED                     ║${NC}"
echo -e "${BOLD}${GREEN}║                                                              ║${NC}"
echo -e "${BOLD}${GREEN}║  Alpine Linux Version: ${FINAL_VERSION}                               ║${NC}"
echo -e "${BOLD}${GREEN}║  Provisioning Script: v${SCRIPT_VERSION}                            ║${NC}"
echo -e "${BOLD}${GREEN}║  Status: SUCCESS ✓                                          ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"

log_success "Provisioning completed successfully!"

# Handle reboot if Alpine version was upgraded (this logic is at the very end as before)
if [ -f /tmp/reboot_required ]; then
    log_warning "Rebooting system to complete Alpine version upgrade..."
    rm -f /tmp/reboot_required
    sleep 5 # Give some time for logs to flush
    reboot
fi