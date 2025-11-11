#!/bin/bash

# Script para configurar ArgoCD com ApplicationSets

set -e

NAMESPACE="argocd"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_DIR="${SCRIPT_DIR}/../argocd"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir mensagens coloridas
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[ARGOCD]${NC} $1"
}

# Função para verificar se o comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para detectar kubectl ou microk8s
setup_kubectl() {
    if command_exists microk8s && microk8s kubectl version >/dev/null 2>&1; then
        KUBECTL_CMD="microk8s kubectl"
        print_status "Usando microk8s kubectl"
    elif command_exists kubectl && kubectl version >/dev/null 2>&1; then
        KUBECTL_CMD="kubectl"
        print_status "Usando kubectl"
    else
        print_error "kubectl ou microk8s não encontrado"
        exit 1
    fi
}

# Função para verificar pré-requisitos
check_prerequisites() {
    print_status "Verificando pré-requisitos..."
    
    # Verificar conexão com Kubernetes
    if ! $KUBECTL_CMD cluster-info >/dev/null 2>&1; then
        print_error "Não foi possível conectar ao cluster Kubernetes"
        exit 1
    fi
    
    # Verificar se ArgoCD está instalado
    if ! $KUBECTL_CMD get namespace $NAMESPACE >/dev/null 2>&1; then
        print_warning "Namespace argocd não encontrado. Instalando ArgoCD..."
        install_argocd
    fi
    
    # Verificar se ArgoCD está rodando
    if ! $KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=argocd-server --field-selector=status.phase=Running >/dev/null 2>&1; then
        print_warning "ArgoCD não está rodando. Aguardando..."
        wait_for_argocd
    fi
    
    print_status "Pré-requisitos verificados com sucesso"
}

# Função para instalar ArgoCD
install_argocd() {
    print_status "Instalando ArgoCD..."
    
    # Criar namespace
    $KUBECTL_CMD create namespace $NAMESPACE || true
    
    # Instalar ArgoCD
    $KUBECTL_CMD apply -n $NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Aguardar ArgoCD ficar pronto
    wait_for_argocd
    
    # Configurar acesso
    setup_argocd_access
}

# Função para aguardar ArgoCD ficar pronto
wait_for_argocd() {
    print_status "Aguardando ArgoCD ficar pronto..."
    
    local timeout=300
    local interval=10
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if $KUBECTL_CMD get pods -n $NAMESPACE -l app.kubernetes.io/name=argocd-server --field-selector=status.phase=Running | grep -q "Running"; then
            print_status "ArgoCD está pronto!"
            return 0
        fi
        
        print_status "Aguardando... ($elapsed/$timeout segundos)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    print_error "Timeout aguardando ArgoCD ficar pronto"
    exit 1
}

# Função para configurar acesso ao ArgoCD
setup_argocd_access() {
    print_status "Configurando acesso ao ArgoCD..."
    
    # Obter senha inicial
    local argocd_password=$($KUBECTL_CMD -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    # Expor serviço via LoadBalancer
    $KUBECTL_CMD patch svc argocd-server -n $NAMESPACE -p '{"spec": {"type": "LoadBalancer"}}' || true
    
    # Aguardar IP externo
    print_status "Aguardando IP externo..."
    local external_ip=""
    local timeout=60
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        external_ip=$($KUBECTL_CMD get svc argocd-server -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$external_ip" ] && [ "$external_ip" != "null" ]; then
            break
        fi
        
        # Tentar hostname para cloud providers
        external_ip=$($KUBECTL_CMD get svc argocd-server -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
        if [ -n "$external_ip" ] && [ "$external_ip" != "null" ]; then
            break
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    if [ -n "$external_ip" ] && [ "$external_ip" != "null" ]; then
        print_status "ArgoCD acessível em: https://$external_ip"
    else
        # Usar port-forward como fallback
        print_status "Usando port-forward para acessar ArgoCD"
        print_status "Execute: kubectl port-forward svc/argocd-server -n argocd 8080:443"
        print_status "Acesse: https://localhost:8080"
    fi
    
    print_status "Usuário: admin"
    print_status "Senha: $argocd_password"
}

# Função para criar projetos do ArgoCD
create_argocd_projects() {
    print_status "Criando projetos do ArgoCD..."
    
    # Projeto para infraestrutura
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: infrastructure
  namespace: $NAMESPACE
spec:
  description: Infrastructure applications
  sourceRepos:
  - '*'
  destinations:
  - namespace: '*'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
EOF

    # Projeto para monitoramento
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: monitoring
  namespace: $NAMESPACE
spec:
  description: Monitoring applications
  sourceRepos:
  - '*'
  destinations:
  - namespace: 'monitoring'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
EOF

    # Projeto para dados
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: data
  namespace: $NAMESPACE
spec:
  description: Data applications (Redis, databases)
  sourceRepos:
  - '*'
  destinations:
  - namespace: 'redis-ha'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
EOF

    # Projeto para backup
    cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: backup
  namespace: $NAMESPACE
spec:
  description: Backup applications (Velero)
  sourceRepos:
  - '*'
  destinations:
  - namespace: 'velero'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
EOF

    print_status "Projetos criados com sucesso"
}

# Função para aplicar ApplicationSets
apply_applicationsets() {
    print_status "Aplicando ApplicationSets..."
    
    if [ -f "$ARGOCD_DIR/applicationsets.yaml" ]; then
        $KUBECTL_CMD apply -f "$ARGOCD_DIR/applicationsets.yaml"
        print_status "ApplicationSets aplicados com sucesso"
    else
        print_error "Arquivo applicationsets.yaml não encontrado em $ARGOCD_DIR"
        exit 1
    fi
}

# Função para verificar status
verify_status() {
    print_status "Verificando status dos ApplicationSets..."
    
    # Aguardar um pouco para os recursos serem criados
    sleep 10
    
    # Listar ApplicationSets
    print_status "ApplicationSets criados:"
    $KUBECTL_CMD get applicationsets -n $NAMESPACE
    
    # Listar aplicações
    print_status "Aplicações criadas:"
    $KUBECTL_CMD get applications -n $NAMESPACE
    
    # Verificar se há erros
    local failed_apps=$($KUBECTL_CMD get applications -n $NAMESPACE -o jsonpath='{.items[?(@.status.health.status!="Healthy")].metadata.name}' 2>/dev/null)
    if [ -n "$failed_apps" ]; then
        print_warning "Aplicações com problemas: $failed_apps"
        print_status "Use 'kubectl describe application <nome> -n $NAMESPACE' para mais detalhes"
    fi
}

# Função para mostrar informações de acesso
show_access_info() {
    print_header "Informações de Acesso"
    
    # Obter senha
    local argocd_password=$($KUBECTL_CMD -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    # Obter endereço
    local external_ip=$($KUBECTL_CMD get svc argocd-server -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -z "$external_ip" ] || [ "$external_ip" = "null" ]; then
        external_ip=$($KUBECTL_CMD get svc argocd-server -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    fi
    
    echo "=========================================="
    echo "ArgoCD configurado com sucesso!"
    echo "=========================================="
    echo
    echo "URL: https://${external_ip:-localhost:8080}"
    echo "Usuário: admin"
    echo "Senha: $argocd_password"
    echo
    echo "ApplicationSets criados:"
    echo "- infrastructure-apps"
    echo "- monitoring-apps"
    echo "- data-apps"
    echo "- backup-apps"
    echo
    echo "Comandos úteis:"
    echo "  kubectl get applicationsets -n $NAMESPACE"
    echo "  kubectl get applications -n $NAMESPACE"
    echo "  kubectl port-forward svc/argocd-server -n $NAMESPACE 8080:443"
    echo "=========================================="
}

# Função principal
main() {
    print_header "Configurando ArgoCD com ApplicationSets..."
    
    setup_kubectl
    check_prerequisites
    create_argocd_projects
    apply_applicationsets
    verify_status
    show_access_info
    
    print_status "Configuração concluída!"
}

# Verificar dependências
if ! command_exists kubectl && ! command_exists microk8s; then
    print_error "kubectl ou microk8s não encontrado"
    exit 1
fi

# Executar função principal
main "$@"