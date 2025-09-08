#!/bin/bash

# Redis External Client Setup Script
# This script automates the setup for accessing Redis from external machines

set -e

echo "🚀 Redis External Client Setup Script"
echo "=====================================​"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get node IP automatically
get_node_ip() {
    local node_ip=""
    
    # Try different methods to get node IP
    if command_exists kubectl; then
        node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    elif command_exists microk8s; then
        node_ip=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    fi
    
    # If still empty, try to detect from common network interfaces
    if [ -z "$node_ip" ]; then
        # Try to get IP from common network interfaces
        node_ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' | head -1)
    fi
    
    echo "$node_ip"
}

# Function to setup DNS entries
setup_dns() {
    local node_ip="$1"
    local hosts_file="/etc/hosts"
    
    echo ""
    print_info "Configurando DNS no arquivo $hosts_file..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_warning "Este script precisa de privilégios sudo para modificar $hosts_file"
        SUDO_CMD="sudo"
    else
        SUDO_CMD=""
    fi
    
    # Backup hosts file
    $SUDO_CMD cp "$hosts_file" "${hosts_file}.backup.$(date +%Y%m%d_%H%M%S)"
    print_success "Backup do hosts file criado"
    
    # Remove old Redis entries
    $SUDO_CMD sed -i '/# Redis Kubernetes Start/,/# Redis Kubernetes End/d' "$hosts_file"
    
    # Add new Redis entries
    {
        echo ""
        echo "# Redis Kubernetes Start"
        echo "$node_ip redis.home.arpa"
        echo "$node_ip redis-proxy.home.arpa"
        echo "$node_ip redis-master.home.arpa"
        echo "$node_ip redis-replica.home.arpa"
        echo "$node_ip redis-stats.home.arpa"
        echo "# Redis Kubernetes End"
    } | $SUDO_CMD tee -a "$hosts_file" > /dev/null
    
    print_success "Entradas DNS adicionadas ao $hosts_file"
}

# Function to test DNS resolution
test_dns() {
    local node_ip="$1"
    
    echo ""
    print_info "Testando resolução DNS..."
    
    local hosts=("redis.home.arpa" "redis-proxy.home.arpa" "redis-master.home.arpa" "redis-replica.home.arpa")
    
    for host in "${hosts[@]}"; do
        if getent hosts "$host" >/dev/null 2>&1; then
            resolved_ip=$(getent hosts "$host" | awk '{print $1}')
            if [ "$resolved_ip" = "$node_ip" ]; then
                print_success "DNS OK: $host -> $resolved_ip"
            else
                print_warning "DNS resolve para IP diferente: $host -> $resolved_ip (esperado: $node_ip)"
            fi
        else
            print_error "DNS não resolve: $host"
        fi
    done
}

# Function to install Redis CLI
install_redis_cli() {
    echo ""
    print_info "Verificando Redis CLI..."
    
    if command_exists redis-cli; then
        print_success "Redis CLI já instalado: $(redis-cli --version)"
        return 0
    fi
    
    print_warning "Redis CLI não encontrado. Tentando instalar..."
    
    # Detect OS and install Redis CLI
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        print_info "Sistema Debian/Ubuntu detectado"
        sudo apt update && sudo apt install -y redis-tools
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS/Fedora
        print_info "Sistema RHEL/CentOS/Fedora detectado"
        if command_exists dnf; then
            sudo dnf install -y redis
        else
            sudo yum install -y redis
        fi
    elif command_exists brew; then
        # macOS with Homebrew
        print_info "macOS com Homebrew detectado"
        brew install redis
    else
        print_error "Sistema operacional não suportado para instalação automática"
        print_info "Instale manualmente o Redis CLI para continuar"
        return 1
    fi
    
    if command_exists redis-cli; then
        print_success "Redis CLI instalado com sucesso: $(redis-cli --version)"
    else
        print_error "Falha na instalação do Redis CLI"
        return 1
    fi
}

# Function to test Redis connectivity
test_redis_connectivity() {
    local node_ip="$1"
    
    echo ""
    print_info "Testando conectividade com Redis..."
    
    # Test configurations
    local tests=(
        "Redis Proxy (sem TLS)|redis.home.arpa|30379|false"
        "Redis Proxy (via IP)|$node_ip|30379|false"
        "Redis Master TLS|redis-master.home.arpa|30380|true"
        "Redis Master TLS (via IP)|$node_ip|30380|true"
        "Redis Réplicas|redis-replica.home.arpa|30381|false"
        "Redis Réplicas TLS|redis-replica.home.arpa|30382|true"
    )
    
    local password="Admin@123"
    local success_count=0
    local total_tests=${#tests[@]}
    
    for test in "${tests[@]}"; do
        IFS='|' read -r description host port use_tls <<< "$test"
        
        echo -n "  Testando $description ($host:$port)... "
        
        local result
        if [ "$use_tls" = "true" ]; then
            result=$(timeout 10 redis-cli -h "$host" -p "$port" --tls --insecure -a "$password" ping 2>/dev/null || echo "FAILED")
        else
            result=$(timeout 10 redis-cli -h "$host" -p "$port" -a "$password" ping 2>/dev/null || echo "FAILED")
        fi
        
        if [ "$result" = "PONG" ]; then
            print_success "OK"
            ((success_count++))
        else
            print_error "FALHOU"
        fi
    done
    
    echo ""
    print_info "Resultado dos testes: $success_count/$total_tests conexões bem-sucedidas"
    
    if [ "$success_count" -gt 0 ]; then
        print_success "Pelo menos uma conexão está funcionando!"
    else
        print_error "Nenhuma conexão funcionou. Verifique se o Redis está rodando no cluster."
    fi
}

# Function to show Redis usage examples
show_usage_examples() {
    local node_ip="$1"
    
    echo ""
    print_info "Exemplos de Uso do Redis CLI:"
    echo ""
    
    echo "# Conexão básica (recomendado):"
    echo "redis-cli -h redis.home.arpa -p 30379 -a Admin@123"
    echo ""
    
    echo "# Conexão com TLS:"
    echo "redis-cli -h redis.home.arpa -p 30380 --tls --insecure -a Admin@123"
    echo ""
    
    echo "# Conexão direta via IP:"
    echo "redis-cli -h $node_ip -p 30379 -a Admin@123"
    echo ""
    
    echo "# Teste básico:"
    echo "redis-cli -h redis.home.arpa -p 30379 -a Admin@123 ping"
    echo ""
    
    echo "# Operações básicas:"
    echo "redis-cli -h redis.home.arpa -p 30379 -a Admin@123 SET teste 'funcionando'"
    echo "redis-cli -h redis.home.arpa -p 30379 -a Admin@123 GET teste"
    echo ""
    
    echo "# Dashboard HAProxy (monitoramento):"
    echo "http://$node_ip:30404/stats"
    echo "Usuário: admin | Senha: admin123"
    echo ""
}

# Function to create Windows PowerShell script
create_windows_script() {
    local node_ip="$1"
    local script_path="/tmp/setup-redis-client-windows.ps1"
    
    cat > "$script_path" << 'EOF'
# Redis Client Setup for Windows
# Run this script as Administrator

param(
    [Parameter(Mandatory=$true)]
    [string]$NodeIP
)

Write-Host "🚀 Redis Client Setup for Windows" -ForegroundColor Green
Write-Host "=================================="

# Hosts file path
$hostsFile = "C:\Windows\System32\drivers\etc\hosts"

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Este script deve ser executado como Administrador"
    exit 1
}

# Backup hosts file
$backupFile = "$hostsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item $hostsFile $backupFile
Write-Host "✅ Backup criado: $backupFile" -ForegroundColor Green

# Read current content
$content = Get-Content $hostsFile

# Remove old Redis entries
$newContent = @()
$skipLines = $false

foreach ($line in $content) {
    if ($line -match "# Redis Kubernetes Start") {
        $skipLines = $true
        continue
    }
    if ($line -match "# Redis Kubernetes End") {
        $skipLines = $false
        continue
    }
    if (-not $skipLines) {
        $newContent += $line
    }
}

# Add new Redis entries
$newContent += ""
$newContent += "# Redis Kubernetes Start"
$newContent += "$NodeIP redis.home.arpa"
$newContent += "$NodeIP redis-proxy.home.arpa"
$newContent += "$NodeIP redis-master.home.arpa"
$newContent += "$NodeIP redis-replica.home.arpa"
$newContent += "$NodeIP redis-stats.home.arpa"
$newContent += "# Redis Kubernetes End"

# Write updated content
$newContent | Set-Content $hostsFile

Write-Host "✅ DNS configurado no arquivo hosts" -ForegroundColor Green

# Test DNS resolution
Write-Host ""
Write-Host "🧪 Testando resolução DNS..." -ForegroundColor Blue

$hosts = @("redis.home.arpa", "redis-proxy.home.arpa", "redis-master.home.arpa", "redis-replica.home.arpa")

foreach ($host in $hosts) {
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($host)
        if ($resolved.IPAddressToString -contains $NodeIP) {
            Write-Host "✅ DNS OK: $host -> $NodeIP" -ForegroundColor Green
        } else {
            Write-Host "⚠️ DNS resolve para IP diferente: $host" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ DNS não resolve: $host" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "📋 Para instalar Redis CLI no Windows:" -ForegroundColor Blue
Write-Host "1. Instale o WSL (Windows Subsystem for Linux)"
Write-Host "2. No WSL: sudo apt install redis-tools"
Write-Host "3. Ou use Docker: docker run --rm -it redis:latest redis-cli -h redis.home.arpa -p 30379 -a Admin@123"

Write-Host ""
Write-Host "🧪 Teste de conectividade (se Redis CLI instalado):" -ForegroundColor Blue
Write-Host "redis-cli -h redis.home.arpa -p 30379 -a Admin@123 ping"
EOF

    # Update the script with the actual node IP
    sed -i "s/\$NodeIP/$node_ip/g" "$script_path"
    
    print_success "Script PowerShell criado: $script_path"
    echo ""
    print_info "Para usar no Windows:"
    echo "1. Copie o script para a máquina Windows"
    echo "2. Execute como Administrador:"
    echo "   PowerShell -ExecutionPolicy Bypass -File setup-redis-client-windows.ps1 -NodeIP $node_ip"
}

# Main execution
main() {
    echo "Este script irá:"
    echo "1. Detectar o IP do nó Kubernetes"
    echo "2. Configurar DNS local (/etc/hosts)"
    echo "3. Instalar Redis CLI (se necessário)"
    echo "4. Testar conectividade com Redis"
    echo "5. Mostrar exemplos de uso"
    echo ""
    
    # Get node IP
    print_info "Detectando IP do nó Kubernetes..."
    NODE_IP=$(get_node_ip)
    
    if [ -z "$NODE_IP" ]; then
        print_error "Não foi possível detectar o IP do nó Kubernetes"
        print_info "Métodos tentados:"
        echo "  - kubectl get nodes"
        echo "  - microk8s kubectl get nodes"
        echo "  - ip route get 1.1.1.1"
        echo ""
        echo -n "Digite manualmente o IP do nó Kubernetes: "
        read -r NODE_IP
        
        if [ -z "$NODE_IP" ]; then
            print_error "IP do nó é obrigatório"
            exit 1
        fi
    fi
    
    print_success "IP do nó detectado: $NODE_IP"
    
    # Ask for confirmation
    echo ""
    echo "Configuração:"
    echo "  - IP do nó: $NODE_IP"
    echo "  - Arquivo hosts: /etc/hosts"
    echo "  - Domínios: *.home.arpa"
    echo ""
    echo -n "Continuar? (y/N): "
    read -r response
    
    case "$response" in
        [yY][eE][sS]|[yY])
            ;;
        *)
            print_info "Operação cancelada"
            exit 0
            ;;
    esac
    
    # Setup DNS
    setup_dns "$NODE_IP"
    
    # Test DNS
    test_dns "$NODE_IP"
    
    # Install Redis CLI
    install_redis_cli
    
    # Test Redis connectivity (only if Redis CLI is available)
    if command_exists redis-cli; then
        test_redis_connectivity "$NODE_IP"
    else
        print_warning "Redis CLI não disponível. Pulando testes de conectividade."
    fi
    
    # Show usage examples
    show_usage_examples "$NODE_IP"
    
    # Create Windows script
    create_windows_script "$NODE_IP"
    
    echo ""
    print_success "Setup do cliente Redis externo concluído!"
    print_info "Se tiver problemas, verifique:"
    echo "  1. Se o Redis está rodando no cluster Kubernetes"
    echo "  2. Se as portas NodePort estão abertas (30379-30382, 30404)"
    echo "  3. Se não há firewall bloqueando as conexões"
    echo "  4. Se o cluster está acessível via rede"
}

# Run main function
main "$@"