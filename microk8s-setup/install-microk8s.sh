#!/bin/bash

# Script de Instalação e Configuração do MicroK8s
# Para ambiente single-node com todos os addons essenciais
# Autor: Senior Software Engineer
# Data: $(date +%Y-%m-%d)

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
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

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    log_error "Este script deve ser executado como root (sudo)"
    exit 1
fi

# Verificar sistema operacional
if ! command -v apt-get &> /dev/null; then
    log_error "Este script é para sistemas baseados em Debian/Ubuntu"
    exit 1
fi

log_info "=== Iniciando Instalação do MicroK8s ==="

# Atualizar sistema
log_info "Atualizando sistema..."
apt-get update -y
apt-get upgrade -y

# Instalar dependências
log_info "Instalando dependências..."
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    jq \
    htop \
    net-tools \
    snapd

# Verificar se snap está funcionando
log_info "Verificando snap..."
systemctl enable snapd
systemctl start snapd
sleep 5

# Instalar MicroK8s
log_info "Instalando MicroK8s..."
snap install microk8s --classic

# Adicionar usuário ao grupo microk8s
USER_NAME=$(logname 2>/dev/null || echo $SUDO_USER)
if [ ! -z "$USER_NAME" ]; then
    log_info "Adicionando usuário $USER_NAME ao grupo microk8s..."
    usermod -a -G microk8s $USER_NAME
    chown -f -R $USER_NAME ~/.kube
fi

# Aguardar MicroK8s estar pronto
log_info "Aguardando MicroK8s estar pronto..."
microk8s status --wait-ready --timeout=300

# Verificar status
log_info "Status do MicroK8s:"
microk8s status

log_success "MicroK8s instalado com sucesso!"

# Configurar alias kubectl
log_info "Configurando alias kubectl..."
echo 'alias kubectl="microk8s kubectl"' >> /home/$USER_NAME/.bashrc
echo 'alias k="microk8s kubectl"' >> /home/$USER_NAME/.bashrc

# Configurar kubectl para root também
echo 'alias kubectl="microk8s kubectl"' >> /root/.bashrc
echo 'alias k="microk8s kubectl"' >> /root/.bashrc

log_success "Aliases configurados! Use 'kubectl' ou 'k' como atalho."
log_info "Execute 'source ~/.bashrc' ou abra um novo terminal para usar os aliases."

log_success "=== Instalação do MicroK8s Concluída ==="
log_info "Próximo passo: Execute ./configure-addons.sh para configurar os addons"