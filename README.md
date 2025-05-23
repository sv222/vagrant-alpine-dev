# Complete Alpine Linux Development Environment Setup (Vagrant + Docker)

## Project Overview

This project establishes a robust and portable development environment on Windows hosts utilizing Alpine Linux within a Vagrant-managed VirtualBox VM, integrated with Docker. It provides a lightweight, consistent, and isolated Linux workspace designed to significantly streamline the setup and management of development workflows, particularly for containerized applications.

## Features

- Lightweight Alpine Linux base
- Vagrant for easy VM management
- Pre-configured Docker environment
- Shared folders for seamless file access between host and VM
- Automated and manual setup options
- PowerShell scripts for VM start/stop management
- Customizable VM resources and network settings
- Essential development tools pre-installed (Git, SSH, etc.)
- Support for integrating with popular IDEs via SSH
- Comprehensive troubleshooting and optimization guidance

## Installation Methods

### Method 1: Automated Setup (Recommended)

```powershell
# Download and run the complete setup script
# This will create everything automatically
.\setup-environment.ps1 -InstallPrerequisites
# Restart terminal, then run:
.\setup-environment.ps1
```

### Method 2: Manual Setup

1. **Install Prerequisites Manually:**

   ```powershell
   # Install Chocolatey
   Set-ExecutionPolicy Bypass -Scope Process -Force
   [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
   iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

   # Install tools
   choco install virtualbox vagrant git -y
   ```

2. **Clone the Repository:**

   ```powershell
   git clone https://github.com/sv222/vagrant-alpine-dev
   cd vagrant-alpine-dev
   ```

3. **Start Environment:**

   ```powershell
   vagrant up
   ```

## Daily Usage Workflow

### Starting Your Work Session

```powershell
# Option 1: Use management script
.\scripts\start-vm.ps1

# Option 2: Standard Vagrant command
vagrant up
```

### Connecting to the VM

```bash
# SSH into the VM
vagrant ssh

# Once inside, see welcome information
~/welcome.sh
```

### Working with Docker

```bash
# Inside the VM - useful aliases are pre-configured
dps                    # docker ps
di                     # docker images
dex <container>        # docker exec -it <container>
dlogs <container>      # docker logs <container>

# Example: Run a simple web server
docker run -d -p 8080:80 nginx
# Access at http://localhost:8080 from Windows
```

### File Sharing

```bash
# Windows side: Put files in ./shared/
# VM side: Access files at /vagrant/shared/

# Example workflow:
# 1. Create project on Windows in ./shared/my-project/
# 2. Work on it from VM at /vagrant/shared/my-project/
# 3. Use Docker to build/run from VM
# 4. Edit files from Windows with your favorite IDE
```

### Ending Your Work Session

```powershell
# Option 1: Graceful shutdown
.\scripts\stop-vm.ps1

# Option 2: Suspend (faster next startup)
.\scripts\stop-vm.ps1 -Suspend

# Option 3: Force shutdown (if needed)
.\scripts\stop-vm.ps1 -Force
```

## Advanced Usage

### Custom VM Configuration

Edit `Vagrantfile` to modify:

```ruby
# Memory and CPU
vb.memory = "4096"  # 4GB RAM
vb.cpus = 4         # 4 CPU cores

# Additional port forwarding
config.vm.network "forwarded_port", guest: 3000, host: 3000  # Node.js
config.vm.network "forwarded_port", guest: 5000, host: 5000  # Python/Flask
```

### Docker Development Examples

#### Node.js Application

```bash
# Inside VM
cd /vagrant/shared
mkdir my-node-app && cd my-node-app

# Create package.json
cat > package.json << 'EOF'
{
  "name": "my-app",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM node:alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
EOF

# Build and run
docker build -t my-node-app .
docker run -d -p 3000:3000 my-node-app
```

#### Python Flask Application

```bash
# Inside VM
cd /vagrant/shared
mkdir my-flask-app && cd my-flask-app

# Create requirements.txt
echo "Flask==2.3.3" > requirements.txt

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM python:alpine
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
EOF

# Build and run
docker build -t my-flask-app .
docker run -d -p 5000:5000 my-flask-app
```

### VM Management Commands

#### Snapshot Management

```powershell
# Create snapshot
vagrant snapshot save "clean-state"

# List snapshots
vagrant snapshot list

# Restore snapshot
vagrant snapshot restore "clean-state"

# Delete snapshot
vagrant snapshot delete "clean-state"
```

#### VM Information

```powershell
# Check VM status
vagrant status

# Get VM info
vagrant ssh -c "cat /etc/alpine-release && free -h && docker ps"

# Check global Vagrant VMs
vagrant global-status
```

## Troubleshooting

### Common Issues and Solutions

#### 1. VM Won't Start

**Symptoms:** `vagrant up` fails or hangs
**Solutions:**

```powershell
# Check VirtualBox installation
VBoxManage --version

# Check if virtualization is enabled in BIOS
# Enable VT-x/AMD-V in BIOS settings

# Try different provider
# Edit Vagrantfile to use VMware instead of VirtualBox
```

#### 2. Shared Folder Issues

**Symptoms:** Files not syncing between Windows and VM
**Solutions:**

```bash
# Inside VM - manually mount shared folder
sudo mount -t vboxsf shared /vagrant/shared

# Restart VM
exit
vagrant reload
```

#### 3. Docker Permission Issues

**Symptoms:** `permission denied` when running Docker commands
**Solutions:**

```bash
# Check if user is in docker group
groups

# Re-add user to docker group
sudo addgroup vagrant docker

# Restart session
exit
vagrant ssh
```

#### 4. Port Forwarding Not Working

**Symptoms:** Can't access services from Windows
**Solutions:**

```powershell
# Check Windows Firewall
# Disable temporarily to test

# Check if port is being used
netstat -an | findstr :8080

# Restart VM
vagrant reload
```

#### 5. VM Performance Issues

**Symptoms:** Slow performance, high CPU usage
**Solutions:**

```ruby
# Edit Vagrantfile - reduce resources
vb.memory = "1024"
vb.cpus = 1

# Enable performance optimizations
vb.customize ["modifyvm", :id, "--ioapic", "on"]
vb.customize ["modifyvm", :id, "--hpet", "on"]
```

### Performance Optimization Tips

1. **Use NFS for better file sharing performance** (macOS/Linux hosts only):

   ```ruby
   config.vm.synced_folder "./shared", "/vagrant/shared", type: "nfs"
   ```

2. **Allocate appropriate resources:**

   - Development: 2GB RAM, 2 CPUs
   - Heavy development: 4GB RAM, 4 CPUs
   - Testing: 8GB RAM, 8 CPUs

3. **Use linked clones for faster VM creation:**

   ```ruby
   vb.linked_clone = true
   ```

4. **Suspend instead of shutdown for faster restarts:**

   ```powershell
   .\scripts\stop-vm.ps1 -Suspend
   ```

## Customization Options

### Adding Development Tools

Edit `scripts/provision.sh` to add more tools:

```bash
# Add development tools
apk add --no-cache \
    python3 \
    python3-pip \
    nodejs \
    npm \
    go \
    openjdk11 \
    maven \
    gradle
```

### Environment Variables

Add to `scripts/provision.sh`:

```bash
# Set environment variables
cat >> /home/vagrant/.profile << 'EOF'
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
export GO_PATH=/home/vagrant/go
export PATH=$PATH:$GO_PATH/bin
EOF
```

### Custom Docker Images

Create a `docker-compose.yml` in shared folder:

```yaml
version: '3.8'
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./html:/usr/share/nginx/html

  database:
    image: postgres:alpine
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
```

## Best Practices

### 1. Project Organization

```text
vagrant-alpine-dev/
├── shared/
│   ├── project1/
│   ├── project2/
│   └── docker-compose.yml
├── scripts/
├── docs/
└── Vagrantfile
```

### 2. Version Control

- Keep `Vagrantfile` and scripts in version control
- Add `.vagrant/` to `.gitignore`
- Don't commit VM snapshots

### 3. Security

- Change default passwords
- Use SSH keys for better security
- Keep VM and tools updated regularly

### 4. Backup Strategy

- Create snapshots before major changes
- Backup shared folder regularly
- Export VM configuration for disaster recovery

## Integration with IDEs

### Visual Studio Code

1. Install "Remote - SSH" extension
2. Connect to `vagrant@localhost:2222`
3. Work directly on VM files

### JetBrains IDEs

1. Configure SSH connection to `localhost:2222`
2. Set up remote development environment
3. Use built-in terminal for VM access

### Docker Desktop Alternative

This environment can replace Docker Desktop on Windows:

- Full Linux environment
- Better performance for complex applications
- No licensing restrictions
- Full control over Docker daemon

## Monitoring and Maintenance

### System Monitoring

```bash
# Inside VM
htop                    # System monitor
docker stats           # Container resource usage
df -h                   # Disk usage
free -h                 # Memory usage
```

### Regular Maintenance

```bash
# Update system packages
sudo apk update && sudo apk upgrade

# Clean Docker system
docker system prune -af

# Clean package cache
sudo apk cache clean
```

### Log Management

```bash
# View system logs
sudo tail -f /var/log/messages

# View Docker logs
docker logs <container_name>

# View service logs
sudo rc-service docker status
```

## Contributing

We welcome contributions from the community. If you have ideas, bug reports, or feature requests, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License.
