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
# Determinar o nome de usuário que invocou o script ou o usuário atual se executado como root
if [ -n "$SUDO_USER" ]; then
    USER_NAME="$SUDO_USER"
else
    USER_NAME="$(whoami)"
fi
if [ ! -z "$USER_NAME" ]; then
    log_info "Adicionando usuário $USER_NAME ao grupo microk8s..."
    usermod -a -G microk8s $USER_NAME
    # A nova sessão do usuário precisará do grupo microk8s
    # Para aplicar imediatamente, o usuário precisaria fazer 'newgrp microk8s'
    # ou logar novamente. Para o script, vamos garantir que o kubeconfig seja acessível.

    log_info "Configurando kubeconfig para o usuário $USER_NAME..."
    HOME_DIR=$(eval echo ~$USER_NAME)
    mkdir -p $HOME_DIR/.kube
    microk8s config > $HOME_DIR/.kube/config
    chown -f -R $USER_NAME:$USER_NAME $HOME_DIR/.kube
    chmod 600 $HOME_DIR/.kube/config
    log_info "Kubeconfig configurado em $HOME_DIR/.kube/config"
else
    log_warning "Não foi possível determinar o usuário para configurar o kubeconfig. Configure manualmente se necessário."
fi

# Aguardar MicroK8s estar pronto
log_info "Aguardando MicroK8s estar pronto..."
microk8s status --wait-ready --timeout=300

# Verificar status
log_info "Status do MicroK8s:"
microk8s status

log_success "MicroK8s instalado com sucesso!"

# Configurar alias kubectl para o usuário
log_info "Configurando alias kubectl para o usuário $USER_NAME..."
USER_BASHRC="/home/$USER_NAME/.bashrc"
if [ -f "$USER_BASHRC" ]; then
    if ! grep -q 'alias kubectl="microk8s kubectl"' "$USER_BASHRC"; then
        echo 'alias kubectl="microk8s kubectl"' >> "$USER_BASHRC"
    fi
    if ! grep -q 'alias k="microk8s kubectl"' "$USER_BASHRC"; then
        echo 'alias k="microk8s kubectl"' >> "$USER_BASHRC"
    fi
    chown $USER_NAME:$USER_NAME "$USER_BASHRC"
else
    log_warning "Arquivo $USER_BASHRC não encontrado para o usuário $USER_NAME. Aliases não configurados."
fi

# Configurar kubectl para root também (se o script foi executado como root)
if [ "$EUID" -eq 0 ]; then
    log_info "Configurando alias kubectl para root..."
    ROOT_BASHRC="/root/.bashrc"
    if [ -f "$ROOT_BASHRC" ]; then
        if ! grep -q 'alias kubectl="microk8s kubectl"' "$ROOT_BASHRC"; then
            echo 'alias kubectl="microk8s kubectl"' >> "$ROOT_BASHRC"
        fi
        if ! grep -q 'alias k="microk8s kubectl"' "$ROOT_BASHRC"; then
            echo 'alias k="microk8s kubectl"' >> "$ROOT_BASHRC"
        fi
    else
        log_warning "Arquivo $ROOT_BASHRC não encontrado. Aliases para root não configurados."
    fi
fi

log_success "Aliases configurados! Use 'kubectl' ou 'k' como atalho."
log_info "Execute 'source ~/.bashrc' ou abra um novo terminal para usar os aliases."

log_success "=== Instalação do MicroK8s Concluída ==="
log_info "Próximo passo: Execute ./configure-addons.sh para configurar os addons"