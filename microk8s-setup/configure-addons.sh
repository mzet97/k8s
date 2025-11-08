#!/bin/bash

# Script de Configuração dos Addons do MicroK8s
# Configura: DNS, Ingress, Cert-Manager, Helm, Hostpath Storage
# Para ambiente single-node
# Autor: Senior Software Engineer

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

# Verificar se MicroK8s está instalado
if ! command -v microk8s &> /dev/null; then
    log_error "MicroK8s não está instalado. Execute primeiro ./install-microk8s.sh"
    exit 1
fi

# Verificar se MicroK8s está rodando
log_info "Verificando status do MicroK8s..."
microk8s status --wait-ready --timeout=60

log_info "=== Configurando Addons do MicroK8s ==="

# 1. Habilitar DNS
log_info "1. Habilitando DNS..."
microk8s enable dns
log_success "DNS habilitado"

# Aguardar DNS estar pronto
log_info "Aguardando DNS estar pronto..."
microk8s kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=120s

# 2. Habilitar Hostpath Storage
log_info "2. Habilitando Storage (Hostpath Provisioner)..."
microk8s enable storage
log_success "Storage habilitado"

log_info "Aguardando Hostpath Provisioner estar pronto..."
microk8s kubectl wait --for=condition=ready pod -l app=hostpath-provisioner -n kube-system --timeout=120s || log_warning "Hostpath Provisioner pode não estar totalmente pronto, mas continuando..."

# 3. Habilitar Ingress
log_info "3. Habilitando Ingress NGINX..."
microk8s enable ingress
log_success "Ingress NGINX habilitado"

log_info "Aguardando Ingress Controller estar pronto..."
microk8s kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller -n ingress --timeout=120s || log_warning "Ingress Controller pode não estar totalmente pronto, mas continuando..."

# 4. Habilitar Helm
log_info "4. Habilitando Helm..."
microk8s enable helm3
log_success "Helm3 habilitado"

# 5. Habilitar Cert-Manager
log_info "5. Habilitando Cert-Manager..."
microk8s enable cert-manager
log_success "Cert-Manager habilitado"

# Aguardar cert-manager estar pronto
log_info "Aguardando Cert-Manager estar pronto..."
# Verificar se o namespace cert-manager existe
log_info "Verificando se namespace cert-manager está disponível..."
for i in {1..30}; do
    if microk8s kubectl get namespace cert-manager >/dev/null 2>&1; then
        log_info "Namespace cert-manager encontrado, aguardando pods..."
        break
    else
        log_info "Aguardando namespace cert-manager aparecer... ($i/30)"
        sleep 2
    fi
done

# Aguardar pods do cert-manager com verificação robusta
log_info "Aguardando pods do cert-manager..."
microk8s kubectl wait --for=condition=available deployment/cert-manager -n cert-manager --timeout=180s || log_warning "Cert-manager deployment pode não estar totalmente pronto, mas continuando..."

# 6. Configurações adicionais
log_info "6. Aplicando configurações adicionais..."

# Criar ClusterIssuer para certificados auto-assinados
log_info "Criando ClusterIssuer para certificados auto-assinados..."
cat <<EOF | microk8s kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF

# Verificar se ClusterIssuer foi criado
log_info "Verificando se ClusterIssuer foi criado..."
for i in {1..20}; do
    if microk8s kubectl get clusterissuer selfsigned-issuer >/dev/null 2>&1; then
        log_info "ClusterIssuer encontrado, verificando status..."
        microk8s kubectl wait --for=condition=ready clusterissuer/selfsigned-issuer --timeout=30s 2>/dev/null || \
        log_warning "ClusterIssuer pode não estar totalmente pronto, mas foi criado com sucesso"
        break
    else
        log_info "Aguardando ClusterIssuer aparecer... ($i/20)"
        sleep 3
    fi
done

log_success "ClusterIssuer criado com sucesso"

# 7. Verificar status de todos os addons
log_info "7. Verificando status dos addons..."
microk8s status

# 8. Verificar pods do sistema
log_info "8. Verificando pods do sistema..."
microk8s kubectl get pods --all-namespaces

# 9. Verificar storage classes
log_info "9. Verificando Storage Classes..."
microk8s kubectl get storageclass

# 10. Verificar ingress controller
log_info "10. Verificando Ingress Controller..."
log_info "Pods do Ingress Controller:"
microk8s kubectl get pods -n ingress
log_info "Serviços do Ingress (pode estar vazio se nenhum ingress foi criado ainda):"
microk8s kubectl get svc -n ingress 2>/dev/null || log_info "Nenhum serviço encontrado no namespace ingress (normal se nenhum ingress foi configurado)"
log_info "Verificando se o Ingress Controller está respondendo:"
microk8s kubectl get pods -n ingress -o wide

# 11. Verificar cert-manager
log_info "11. Verificando Cert-Manager..."
microk8s kubectl get pods -n cert-manager
microk8s kubectl get clusterissuers

# 12. Configurar kubeconfig para acesso externo (opcional)
log_info "12. Configurando kubeconfig para acesso externo..."

# Determinar o nome de usuário que invocou o script ou o usuário atual se executado como root
if [ -n "$SUDO_USER" ]; then
    CURRENT_USER="$SUDO_USER"
else
    CURRENT_USER="$(whoami)"
fi

HOME_DIR=$(eval echo ~$CURRENT_USER)
KUBECONFIG_DIR="$HOME_DIR/.kube"
KUBECONFIG_PATH="$KUBECONFIG_DIR/microk8s-config"

mkdir -p "$KUBECONFIG_DIR" || log_warning "Não foi possível criar o diretório $KUBECONFIG_DIR. Verifique as permissões."

if microk8s config > "$KUBECONFIG_PATH"; then
    chown "$CURRENT_USER":"$CURRENT_USER" "$KUBECONFIG_PATH" || log_warning "Não foi possível alterar o proprietário de $KUBECONFIG_PATH."
    chmod 600 "$KUBECONFIG_PATH" || log_warning "Não foi possível alterar as permissões de $KUBECONFIG_PATH."
    log_info "Kubeconfig para acesso externo salvo em: $KUBECONFIG_PATH"
    log_info "Para usar kubectl externamente: export KUBECONFIG=$KUBECONFIG_PATH"
else
    log_error "Falha ao gerar kubeconfig para acesso externo."
fi

# 13. Informações finais
log_success "=== Configuração dos Addons Concluída ==="
log_info ""
log_info "📋 Resumo dos Addons Habilitados:"
log_info "   ✅ DNS (CoreDNS)"
log_info "   ✅ Hostpath Storage"
log_info "   ✅ Ingress NGINX"
log_info "   ✅ Helm3"
log_info "   ✅ Cert-Manager"
log_info ""
log_info "🔧 Comandos Úteis:"
log_info "   microk8s status                    # Ver status dos addons"
log_info "   microk8s kubectl get pods -A       # Ver todos os pods"
log_info "   microk8s kubectl get nodes         # Ver nodes"
log_info "   microk8s kubectl get storageclass  # Ver storage classes"
log_info ""
log_info "🌐 Acesso:"
log_info "   Ingress Controller: http://localhost (porta 80/443)"
log_info "   Dashboard: Execute ./install-dashboard.sh"
log_info ""
log_warning "⚠️  Lembre-se de executar 'source ~/.bashrc' para usar os aliases kubectl/k"
log_info ""
log_success "Ambiente MicroK8s pronto para uso!"