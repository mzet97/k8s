#!/bin/bash
# Script para configurar e gerenciar Prometheus Federation

set -euo pipefail

NAMESPACE="monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="${SCRIPT_DIR}/../infrastructure/monitoring"

# Detectar comando Kubernetes (kubectl ou microk8s kubectl)
if command -v kubectl >/dev/null 2>&1; then
    KUBECTL_CMD="kubectl"
elif command -v microk8s >/dev/null 2>&1 && microk8s kubectl version >/dev/null 2>&1; then
    KUBECTL_CMD="microk8s kubectl"
else
    echo "Erro: kubectl ou microk8s não encontrado"
    exit 1
fi

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Função para verificar pré-requisitos
check_prerequisites() {
    print_status "Verificando pré-requisitos..."
    
    # Verificar comando Kubernetes
    if ! $KUBECTL_CMD version >/dev/null 2>&1; then
        print_error "Não foi possível conectar ao cluster Kubernetes"
        exit 1
    fi
    
    # Verificar namespace
    if ! $KUBECTL_CMD get namespace $NAMESPACE >/dev/null 2>&1; then
        print_status "Criando namespace $NAMESPACE..."
        $KUBECTL_CMD create namespace $NAMESPACE
    fi
    
    # Verificar storage class
    if ! $KUBECTL_CMD get storageclass local-hostpath >/dev/null 2>&1; then
        print_warning "StorageClass 'local-hostpath' não encontrado. Verificando storage classes disponíveis..."
        $KUBECTL_CMD get storageclass
        print_warning "Certifique-se de ter um storage class disponível para os PVCs"
    fi
    
    # Verificar ingress controller
    if ! $KUBECTL_CMD get pods -n ingress-nginx >/dev/null 2>&1 && ! $KUBECTL_CMD get pods -n kube-system | grep -q ingress; then
        print_warning "Ingress controller não encontrado. O acesso externo pode não funcionar."
    fi
    
    # Verificar cert-manager
    if ! $KUBECTL_CMD get pods -n cert-manager >/dev/null 2>&1; then
        print_warning "cert-manager não encontrado. Os certificados TLS podem não ser emitidos."
    fi
    
    print_status "Pré-requisitos verificados!"
}

# Função para verificar se o comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para executar comando kubectl com tratamento de erro
run_kubectl() {
    local cmd="$1"
    shift
    
    if ! $KUBECTL_CMD $cmd "$@"; then
        print_error "Falha ao executar: $KUBECTL_CMD $cmd $*"
        return 1
    fi
    return 0
}

# Função para esperar por deployment estar pronto
wait_for_deployment() {
    local deployment=$1
    local namespace=$2
    local timeout=${3:-300}
    
    print_status "Aguardando deployment $deployment estar pronto..."
    
    if $KUBECTL_CMD wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $namespace; then
        print_status "Deployment $deployment está pronto!"
        return 0
    else
        print_error "Deployment $deployment não ficou pronto dentro do timeout"
        print_status "Verificando logs do deployment..."
        $KUBECTL_CMD describe deployment/$deployment -n $namespace
        $KUBECTL_CMD logs -n $namespace deployment/$deployment --tail=50
        return 1
    fi
}

# Função para esperar por pods estarem prontos
wait_for_pods() {
    local label=$1
    local namespace=$2
    local expected=${3:-1}
    local timeout=${4:-300}
    
    print_status "Aguardando $expected pods com label $label estarem prontos..."
    
    local start_time=$(date +%s)
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            print_error "Timeout aguardando pods ficarem prontos"
            return 1
        fi
        
        local ready_pods=$(kubectl get pods -n $namespace -l $label -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | wc -w)
        
        if [ $ready_pods -ge $expected ]; then
            print_status "$ready_pods pods estão prontos!"
            return 0
        fi
        
        echo -n "."
        sleep 5
    done
}

# Função para configurar Prometheus Federation
setup_federation() {
    print_status "Configurando Prometheus Federation..."
    
    # Verificar pré-requisitos
    check_prerequisites
    
    # Criar secret de autenticação básica
    print_status "Criando secret de autenticação básica..."
    if ! $KUBECTL_CMD get secret prometheus-basic-auth -n $NAMESPACE >/dev/null 2>&1; then
        # Criar secret com credenciais admin/admin123
        $KUBECTL_CMD create secret generic prometheus-basic-auth \
            --from-literal=auth="admin:$(openssl passwd -apr1 admin123)" \
            -n $NAMESPACE
    fi
    
    # Aplicar ConfigMaps
    print_status "Aplicando ConfigMaps de configuração..."
    run_kubectl apply -f $MONITORING_DIR/prometheus-federation-config.yaml || return 1
    run_kubectl apply -f $MONITORING_DIR/prometheus-federation-rules.yaml || return 1
    
    # Aplicar deployments e serviços
    print_status "Aplicando deployments e serviços..."
    run_kubectl apply -f $MONITORING_DIR/prometheus-federation-deployment.yaml || return 1
    
    # Aplicar ingress
    print_status "Aplicando ingress..."
    run_kubectl apply -f $MONITORING_DIR/prometheus-federation-ingress.yaml || print_warning "Falha ao aplicar ingress"
    
    # Aguardar deployments ficarem prontos
    print_status "Aguardando deployments ficarem prontos..."
    wait_for_deployment "prometheus-global" $NAMESPACE 300 || return 1
    wait_for_deployment "prometheus-local-1" $NAMESPACE 300 || return 1
    wait_for_deployment "prometheus-local-2" $NAMESPACE 300 || return 1
    
    print_status "Prometheus Federation configurado com sucesso!"
    
    # Mostrar informações de acesso
    echo -e "\n${GREEN}=== Informações de Acesso ===${NC}"
    echo "Prometheus Global: https://prometheus-global.homelab.local (admin/admin123)"
    echo "Prometheus Local 1: https://prometheus-local1.homelab.local (admin/admin123)"
    echo "Prometheus Local 2: https://prometheus-local2.homelab.local (admin/admin123)"
    echo -e "\nUse '$0 access' para acessar via port-forward"
}

# Função para verificar status da federation
check_federation_status() {
    print_status "Verificando status da Prometheus Federation..."
    
    echo -e "\n${YELLOW}=== Prometheus Global ===${NC}"
    $KUBECTL_CMD get pods -n $NAMESPACE -l app=prometheus,component=global
    
    echo -e "\n${YELLOW}=== Prometheus Local 1 ===${NC}"
    $KUBECTL_CMD get pods -n $NAMESPACE -l app=prometheus,component=local-1
    
    echo -e "\n${YELLOW}=== Prometheus Local 2 ===${NC}"
    $KUBECTL_CMD get pods -n $NAMESPACE -l app=prometheus,component=local-2
    
    echo -e "\n${YELLOW}=== Serviços ===${NC}"
    $KUBECTL_CMD get services -n $NAMESPACE | grep prometheus || echo "Nenhum serviço prometheus encontrado"
    
    echo -e "\n${YELLOW}=== Ingress ===${NC}"
    $KUBECTL_CMD get ingress -n $NAMESPACE | grep prometheus || echo "Nenhum ingress prometheus encontrado"
    
    echo -e "\n${YELLOW}=== PersistentVolumeClaims ===${NC}"
    $KUBECTL_CMD get pvc -n $NAMESPACE | grep prometheus || echo "Nenhum PVC prometheus encontrado"
    
    # Testar endpoints de health
    echo -e "\n${YELLOW}=== Health Checks ===${NC}"
    
    # Prometheus Global
    local global_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$global_pod" ]; then
        if $KUBECTL_CMD exec -n $NAMESPACE $global_pod -- wget -q -O- http://localhost:9090/-/healthy >/dev/null 2>&1; then
            print_status "Prometheus Global: HEALTHY"
        else
            print_error "Prometheus Global: UNHEALTHY"
        fi
    else
        print_warning "Prometheus Global pod não encontrado"
    fi
    
    # Prometheus Local 1
    local local1_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=prometheus,component=local-1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local1_pod" ]; then
        if $KUBECTL_CMD exec -n $NAMESPACE $local1_pod -- wget -q -O- http://localhost:9090/-/healthy >/dev/null 2>&1; then
            print_status "Prometheus Local 1: HEALTHY"
        else
            print_error "Prometheus Local 1: UNHEALTHY"
        fi
    else
        print_warning "Prometheus Local 1 pod não encontrado"
    fi
    
    # Prometheus Local 2
    local local2_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=prometheus,component=local-2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local2_pod" ]; then
        if $KUBECTL_CMD exec -n $NAMESPACE $local2_pod -- wget -q -O- http://localhost:9090/-/healthy >/dev/null 2>&1; then
            print_status "Prometheus Local 2: HEALTHY"
        else
            print_error "Prometheus Local 2: UNHEALTHY"
        fi
    else
        print_warning "Prometheus Local 2 pod não encontrado"
    fi
}

# Função para testar federation
test_federation() {
    print_status "Testando Prometheus Federation..."
    
    # Obter pods
    local global_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    local local1_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=prometheus,component=local-1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    local local2_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=prometheus,component=local-2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$global_pod" ] || [ -z "$local1_pod" ] || [ -z "$local2_pod" ]; then
        print_error "Não foi possível encontrar todos os pods do Prometheus"
        return 1
    fi
    
    # Testar federation endpoint
    print_status "Testando endpoint de federation..."
    local federation_test=$($KUBECTL_CMD exec -n $NAMESPACE $global_pod -- wget -q -O- "http://localhost:9090/federate?match[]={__name__=~\"job:.*\"}" 2>/dev/null | head -5)
    
    if [ -n "$federation_test" ]; then
        print_status "Federation endpoint está funcionando!"
        echo "Exemplo de métricas federadas:"
        echo "$federation_test"
    else
        print_error "Federation endpoint não está respondendo corretamente"
        print_status "Verificando configuração do Prometheus Global..."
        $KUBECTL_CMD exec -n $NAMESPACE $global_pod -- cat /etc/prometheus/prometheus.yml | grep -A 20 "federate" || true
    fi
    
    # Testar queries
    print_status "Testando queries de agregação..."
    
    # Query de disponibilidade
    local availability_query="job:up:avg"
    local availability_result=$($KUBECTL_CMD exec -n $NAMESPACE $global_pod -- wget -q -O- "http://localhost:9090/api/v1/query?query=$availability_query" 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null)
    
    if [ -n "$availability_result" ] && [ "$availability_result" != "null" ]; then
        print_status "Query de disponibilidade funcionando: $availability_result"
    else
        print_warning "Query de disponibilidade não retornou resultados"
    fi
    
    # Query de CPU
    local cpu_query="job:cpu_usage:avg"
    local cpu_result=$($KUBECTL_CMD exec -n $NAMESPACE $global_pod -- wget -q -O- "http://localhost:9090/api/v1/query?query=$cpu_query" 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null)
    
    if [ -n "$cpu_result" ] && [ "$cpu_result" != "null" ]; then
        print_status "Query de CPU funcionando: ${cpu_result}%"
    else
        print_warning "Query de CPU não retornou resultados"
    fi
    
    # Testar conectividade entre Prometheus
    print_status "Testando conectividade entre Prometheus..."
    
    # Testar se o Global consegue federar dos Locais
    local local1_svc=$($KUBECTL_CMD get svc prometheus-local-1-service -n $NAMESPACE -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    local local2_svc=$($KUBECTL_CMD get svc prometheus-local-2-service -n $NAMESPACE -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    
    if [ -n "$local1_svc" ] && [ -n "$local2_svc" ]; then
        if $KUBECTL_CMD exec -n $NAMESPACE $global_pod -- wget -q -O- "http://$local1_svc:9090/-/healthy" >/dev/null 2>&1; then
            print_status "Conectividade com Prometheus Local 1: OK"
        else
            print_error "Conectividade com Prometheus Local 1: FALHOU"
        fi
        
        if $KUBECTL_CMD exec -n $NAMESPACE $global_pod -- wget -q -O- "http://$local2_svc:9090/-/healthy" >/dev/null 2>&1; then
            print_status "Conectividade com Prometheus Local 2: OK"
        else
            print_error "Conectividade com Prometheus Local 2: FALHOU"
        fi
    fi
}

# Função para acessar Prometheus Global
access_prometheus() {
    print_status "Iniciando port-forward para Prometheus Global..."
    
    local global_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$global_pod" ]; then
        print_status "Acesse Prometheus Global em: http://localhost:9090"
        print_status "Pressione Ctrl+C para parar o port-forward"
        $KUBECTL_CMD port-forward -n $NAMESPACE $global_pod 9090:9090
    else
        print_error "Não foi possível encontrar Prometheus Global pod"
    fi
}

# Função para acessar Prometheus Local 1
access_prometheus_local1() {
    print_status "Iniciando port-forward para Prometheus Local 1..."
    
    local local1_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=prometheus,component=local-1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local1_pod" ]; then
        print_status "Acesse Prometheus Local 1 em: http://localhost:9091"
        print_status "Pressione Ctrl+C para parar o port-forward"
        $KUBECTL_CMD port-forward -n $NAMESPACE $local1_pod 9091:9090
    else
        print_error "Não foi possível encontrar Prometheus Local 1 pod"
    fi
}

# Função para acessar Prometheus Local 2
access_prometheus_local2() {
    print_status "Iniciando port-forward para Prometheus Local 2..."
    
    local local2_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=prometheus,component=local-2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local2_pod" ]; then
        print_status "Acesse Prometheus Local 2 em: http://localhost:9092"
        print_status "Pressione Ctrl+C para parar o port-forward"
        $KUBECTL_CMD port-forward -n $NAMESPACE $local2_pod 9092:9090
    else
        print_error "Não foi possível encontrar Prometheus Local 2 pod"
    fi
}

# Função para diagnóstico detalhado
detailed_diagnosis() {
    print_status "Executando diagnóstico detalhado..."
    
    # Verificar logs dos pods
    print_status "Logs dos pods Prometheus Global:"
    local global_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$global_pod" ]; then
        $KUBECTL_CMD logs -n $NAMESPACE $global_pod --tail=50 | grep -E "(error|Error|ERROR|federate|scraping)" || echo "Nenhum erro encontrado nos logs"
    fi
    
    print_status "Logs dos pods Prometheus Local 1:"
    local local1_pod=$($KUBECTL_CMD get pods -n $NAMESPACE -l app=prometheus,component=local-1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local1_pod" ]; then
        $KUBECTL_CMD logs -n $NAMESPACE $local1_pod --tail=50 | grep -E "(error|Error|ERROR|scraping)" || echo "Nenhum erro encontrado nos logs"
    fi
    
    # Verificar configuração carregada
    print_status "Verificando configurações carregadas:"
    if [ -n "$global_pod" ]; then
        $KUBECTL_CMD exec -n $NAMESPACE $global_pod -- cat /etc/prometheus/prometheus.yml | grep -E "(scrape_configs|federate)" -A 5 || true
    fi
    
    # Verificar regras carregadas
    print_status "Verificando regras de alerta:"
    if [ -n "$global_pod" ]; then
        $KUBECTL_CMD exec -n $NAMESPACE $global_pod -- ls -la /etc/prometheus/rules/ 2>/dev/null || echo "Diretório de regras não encontrado"
    fi
    
    # Verificar targets
    print_status "Verificando targets:"
    if [ -n "$global_pod" ]; then
        $KUBECTL_CMD exec -n $NAMESPACE $global_pod -- wget -q -O- "http://localhost:9090/api/v1/targets" 2>/dev/null | jq '.data.activeTargets | length' 2>/dev/null || echo "Não foi possível verificar targets"
    fi
    
    # Verificar espaço em disco
    print_status "Verificando espaço em disco:"
    $KUBECTL_CMD exec -n $NAMESPACE $global_pod -- df -h /prometheus 2>/dev/null || echo "Não foi possível verificar disco"
}

# Função para limpar recursos
cleanup() {
    print_warning "Isso irá remover todos os recursos do Prometheus Federation!"
    read -p "Tem certeza que deseja continuar? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        print_status "Removendo Prometheus Federation..."
        
        # Parar port-forwards se estiverem rodando
        pkill -f "kubectl.*port-forward.*prometheus" 2>/dev/null || true
        
        # Remover deployments
        $KUBECTL_CMD delete deployment prometheus-global prometheus-local-1 prometheus-local-2 -n $NAMESPACE --ignore-not-found=true
        
        # Remover serviços
        $KUBECTL_CMD delete service prometheus-global-service prometheus-local-1-service prometheus-local-2-service -n $NAMESPACE --ignore-not-found=true
        
        # Remover PVCs
        $KUBECTL_CMD delete pvc prometheus-global-pvc prometheus-local-1-pvc prometheus-local-2-pvc -n $NAMESPACE --ignore-not-found=true
        
        # Remover ConfigMaps
        $KUBECTL_CMD delete configmap prometheus-global-config prometheus-local-1-config prometheus-local-2-config -n $NAMESPACE --ignore-not-found=true
        $KUBECTL_CMD delete configmap prometheus-global-rules prometheus-local-rules -n $NAMESPACE --ignore-not-found=true
        
        # Remover Ingress
        $KUBECTL_CMD delete ingress prometheus-global-ingress prometheus-local-1-ingress prometheus-local-2-ingress -n $NAMESPACE --ignore-not-found=true
        
        # Remover secret
        $KUBECTL_CMD delete secret prometheus-basic-auth -n $NAMESPACE --ignore-not-found=true
        
        print_status "Prometheus Federation removido com sucesso!"
        
        # Verificar se tudo foi removido
        print_status "Verificando limpeza..."
        $KUBECTL_CMD get all -n $NAMESPACE -l app=prometheus 2>/dev/null || echo "Todos os recursos removidos com sucesso"
        
    else
        print_status "Operação cancelada."
    fi
}

# Função para mostrar uso
show_usage() {
    echo "Uso: $0 [comando]"
    echo
    echo "Comandos disponíveis:"
    echo "  setup        - Configurar Prometheus Federation"
    echo "  status       - Verificar status da federation"
    echo "  test         - Testar federation"
    echo "  diagnosis    - Executar diagnóstico detalhado"
    echo "  access       - Acessar Prometheus Global (port-forward)"
    echo "  access-local1 - Acessar Prometheus Local 1 (port-forward)"
    echo "  access-local2 - Acessar Prometheus Local 2 (port-forward)"
    echo "  cleanup      - Remover todos os recursos"
    echo "  help         - Mostrar esta ajuda"
    echo
    echo "Exemplos:"
    echo "  $0 setup"
    echo "  $0 status"
    echo "  $0 test"
    echo "  $0 diagnosis"
    echo "  $0 access"
}

# Função principal
main() {
    case "${1:-help}" in
        setup)
            setup_federation
            ;;
        status)
            check_federation_status
            ;;
        test)
            test_federation
            ;;
        diagnosis)
            detailed_diagnosis
            ;;
        access)
            access_prometheus
            ;;
        access-local1)
            access_prometheus_local1
            ;;
        access-local2)
            access_prometheus_local2
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Comando desconhecido: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Verificar dependências
if ! command_exists kubectl; then
    print_error "kubectl não está instalado ou não está no PATH"
    exit 1
fi

if ! command_exists jq; then
    print_warning "jq não está instalado - algumas funcionalidades podem não funcionar corretamente"
fi

# Executar função principal
main "$@"

#!/bin/bash
# Script para configurar e gerenciar Prometheus Federation

set -e

NAMESPACE="monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="${SCRIPT_DIR}/../infrastructure/monitoring"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Função para verificar se o comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para esperar por deployment estar pronto
wait_for_deployment() {
    local deployment=$1
    local namespace=$2
    local timeout=${3:-300}
    
    print_status "Aguardando deployment $deployment estar pronto..."
    
    if kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $namespace; then
        print_status "Deployment $deployment está pronto!"
        return 0
    else
        print_error "Deployment $deployment não ficou pronto dentro do timeout"
        return 1
    fi
}

# Função para esperar por pods estarem prontos
wait_for_pods() {
    local label=$1
    local namespace=$2
    local expected=${3:-1}
    local timeout=${4:-300}
    
    print_status "Aguardando $expected pods com label $label estarem prontos..."
    
    local start_time=$(date +%s)
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            print_error "Timeout aguardando pods ficarem prontos"
            return 1
        fi
        
        local ready_pods=$(kubectl get pods -n $namespace -l $label -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | wc -w)
        
        if [ $ready_pods -ge $expected ]; then
            print_status "$ready_pods pods estão prontos!"
            return 0
        fi
        
        echo -n "."
        sleep 5
    done
}

# Função para configurar Prometheus Federation
setup_federation() {
    print_status "Configurando Prometheus Federation..."
    
    # Criar namespace se não existir
    if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
        print_status "Criando namespace $NAMESPACE..."
        kubectl create namespace $NAMESPACE
    fi
    
    # Aplicar ConfigMaps
    print_status "Aplicando ConfigMaps de configuração..."
    kubectl apply -f $MONITORING_DIR/prometheus-federation-config.yaml
    kubectl apply -f $MONITORING_DIR/prometheus-federation-rules.yaml
    
    # Aplicar deployments e serviços
    print_status "Aplicando deployments e serviços..."
    kubectl apply -f $MONITORING_DIR/prometheus-federation-deployment.yaml
    
    # Aguardar deployments ficarem prontos
    wait_for_deployment "prometheus-global" $NAMESPACE 300
    wait_for_deployment "prometheus-local-1" $NAMESPACE 300
    wait_for_deployment "prometheus-local-2" $NAMESPACE 300
    
    print_status "Prometheus Federation configurado com sucesso!"
}

# Função para verificar status da federation
check_federation_status() {
    print_status "Verificando status da Prometheus Federation..."
    
    echo -e "\n${YELLOW}=== Prometheus Global ===${NC}"
    kubectl get pods -n $NAMESPACE -l app=prometheus,component=global
    
    echo -e "\n${YELLOW}=== Prometheus Local 1 ===${NC}"
    kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-1
    
    echo -e "\n${YELLOW}=== Prometheus Local 2 ===${NC}"
    kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-2
    
    echo -e "\n${YELLOW}=== Serviços ===${NC}"
    kubectl get services -n $NAMESPACE | grep prometheus
    
    echo -e "\n${YELLOW}=== PersistentVolumeClaims ===${NC}"
    kubectl get pvc -n $NAMESPACE | grep prometheus
    
    # Testar endpoints de health
    echo -e "\n${YELLOW}=== Health Checks ===${NC}"
    
    # Prometheus Global
    local global_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$global_pod" ]; then
        if kubectl exec -n $NAMESPACE $global_pod -- wget -q -O- http://localhost:9090/-/healthy >/dev/null 2>&1; then
            print_status "Prometheus Global: HEALTHY"
        else
            print_error "Prometheus Global: UNHEALTHY"
        fi
    fi
    
    # Prometheus Local 1
    local local1_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local1_pod" ]; then
        if kubectl exec -n $NAMESPACE $local1_pod -- wget -q -O- http://localhost:9090/-/healthy >/dev/null 2>&1; then
            print_status "Prometheus Local 1: HEALTHY"
        else
            print_error "Prometheus Local 1: UNHEALTHY"
        fi
    fi
    
    # Prometheus Local 2
    local local2_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local2_pod" ]; then
        if kubectl exec -n $NAMESPACE $local2_pod -- wget -q -O- http://localhost:9090/-/healthy >/dev/null 2>&1; then
            print_status "Prometheus Local 2: HEALTHY"
        else
            print_error "Prometheus Local 2: UNHEALTHY"
        fi
    fi
}

# Função para testar federation
test_federation() {
    print_status "Testando Prometheus Federation..."
    
    # Obter pods
    local global_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    local local1_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    local local2_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$global_pod" ] || [ -z "$local1_pod" ] || [ -z "$local2_pod" ]; then
        print_error "Não foi possível encontrar todos os pods do Prometheus"
        return 1
    fi
    
    # Testar federation endpoint
    print_status "Testando endpoint de federation..."
    local federation_test=$(kubectl exec -n $NAMESPACE $global_pod -- wget -q -O- "http://localhost:9090/federate?match[]={__name__=~\"job:.*\"}" 2>/dev/null | head -5)
    
    if [ -n "$federation_test" ]; then
        print_status "Federation endpoint está funcionando!"
        echo "Exemplo de métricas federadas:"
        echo "$federation_test"
    else
        print_error "Federation endpoint não está respondendo corretamente"
    fi
    
    # Testar queries
    print_status "Testando queries de agregação..."
    
    # Query de disponibilidade
    local availability_query="job:up:avg"
    local availability_result=$(kubectl exec -n $NAMESPACE $global_pod -- wget -q -O- "http://localhost:9090/api/v1/query?query=$availability_query" 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null)
    
    if [ -n "$availability_result" ] && [ "$availability_result" != "null" ]; then
        print_status "Query de disponibilidade funcionando: $availability_result"
    else
        print_warning "Query de disponibilidade não retornou resultados"
    fi
    
    # Query de CPU
    local cpu_query="job:cpu_usage:avg"
    local cpu_result=$(kubectl exec -n $NAMESPACE $global_pod -- wget -q -O- "http://localhost:9090/api/v1/query?query=$cpu_query" 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null)
    
    if [ -n "$cpu_result" ] && [ "$cpu_result" != "null" ]; then
        print_status "Query de CPU funcionando: ${cpu_result}%"
    else
        print_warning "Query de CPU não retornou resultados"
    fi
}

# Função para acessar Prometheus Global
access_prometheus() {
    print_status "Iniciando port-forward para Prometheus Global..."
    
    local global_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$global_pod" ]; then
        print_status "Acesse Prometheus Global em: http://localhost:9090"
        print_status "Pressione Ctrl+C para parar o port-forward"
        kubectl port-forward -n $NAMESPACE $global_pod 9090:9090
    else
        print_error "Não foi possível encontrar Prometheus Global pod"
    fi
}

# Função para acessar Prometheus Local 1
access_prometheus_local1() {
    print_status "Iniciando port-forward para Prometheus Local 1..."
    
    local local1_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local1_pod" ]; then
        print_status "Acesse Prometheus Local 1 em: http://localhost:9091"
        print_status "Pressione Ctrl+C para parar o port-forward"
        kubectl port-forward -n $NAMESPACE $local1_pod 9091:9090
    else
        print_error "Não foi possível encontrar Prometheus Local 1 pod"
    fi
}

# Função para acessar Prometheus Local 2
access_prometheus_local2() {
    print_status "Iniciando port-forward para Prometheus Local 2..."
    
    local local2_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local2_pod" ]; then
        print_status "Acesse Prometheus Local 2 em: http://localhost:9092"
        print_status "Pressione Ctrl+C para parar o port-forward"
        kubectl port-forward -n $NAMESPACE $local2_pod 9092:9090
    else
        print_error "Não foi possível encontrar Prometheus Local 2 pod"
    fi
}

# Função para limpar recursos
cleanup() {
    print_warning "Isso irá remover todos os recursos do Prometheus Federation!"
    read -p "Tem certeza que deseja continuar? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        print_status "Removendo Prometheus Federation..."
        
        # Remover deployments
        kubectl delete deployment prometheus-global prometheus-local-1 prometheus-local-2 -n $NAMESPACE --ignore-not-found=true
        
        # Remover serviços
        kubectl delete service prometheus-global-service prometheus-local-1-service prometheus-local-2-service -n $NAMESPACE --ignore-not-found=true
        
        # Remover PVCs
        kubectl delete pvc prometheus-global-pvc prometheus-local-1-pvc prometheus-local-2-pvc -n $NAMESPACE --ignore-not-found=true
        
        # Remover ConfigMaps
        kubectl delete configmap prometheus-global-config prometheus-local-1-config prometheus-local-2-config -n $NAMESPACE --ignore-not-found=true
        kubectl delete configmap prometheus-global-rules prometheus-local-rules -n $NAMESPACE --ignore-not-found=true
        
        print_status "Prometheus Federation removido com sucesso!"
    else
        print_status "Operação cancelada."
    fi
}

# Função para mostrar uso
show_usage() {
    echo "Uso: $0 [comando]"
    echo
    echo "Comandos disponíveis:"
    echo "  setup        - Configurar Prometheus Federation"
    echo "  status       - Verificar status da federation"
    echo "  test         - Testar federation"
    echo "  access       - Acessar Prometheus Global (port-forward)"
    echo "  access-local1 - Acessar Prometheus Local 1 (port-forward)"
    echo "  access-local2 - Acessar Prometheus Local 2 (port-forward)"
    echo "  cleanup      - Remover todos os recursos"
    echo "  help         - Mostrar esta ajuda"
    echo
    echo "Exemplos:"
    echo "  $0 setup"
    echo "  $0 status"
    echo "  $0 test"
    echo "  $0 access"
}

# Função principal
main() {
    case "${1:-help}" in
        setup)
            setup_federation
            ;;
        status)
            check_federation_status
            ;;
        test)
            test_federation
            ;;
        access)
            access_prometheus
            ;;
        access-local1)
            access_prometheus_local1
            ;;
        access-local2)
            access_prometheus_local2
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Comando desconhecido: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Verificar dependências
if ! command_exists kubectl; then
    print_error "kubectl não está instalado ou não está no PATH"
    exit 1
fi

if ! command_exists jq; then
    print_warning "jq não está instalado - algumas funcionalidades podem não funcionar corretamente"
fi

# Executar função principal
main "$@"

#!/bin/bash
# Script para configurar e gerenciar Prometheus Federation

set -e

NAMESPACE="monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="${SCRIPT_DIR}/../infrastructure/monitoring"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Função para verificar se o comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para esperar por deployment estar pronto
wait_for_deployment() {
    local deployment=$1
    local namespace=$2
    local timeout=${3:-300}
    
    print_status "Aguardando deployment $deployment estar pronto..."
    
    if kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $namespace; then
        print_status "Deployment $deployment está pronto!"
        return 0
    else
        print_error "Deployment $deployment não ficou pronto dentro do timeout"
        return 1
    fi
}

# Função para esperar por pods estarem prontos
wait_for_pods() {
    local label=$1
    local namespace=$2
    local expected=${3:-1}
    local timeout=${4:-300}
    
    print_status "Aguardando $expected pods com label $label estarem prontos..."
    
    local start_time=$(date +%s)
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            print_error "Timeout aguardando pods ficarem prontos"
            return 1
        fi
        
        local ready_pods=$(kubectl get pods -n $namespace -l $label -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | wc -w)
        
        if [ $ready_pods -ge $expected ]; then
            print_status "$ready_pods pods estão prontos!"
            return 0
        fi
        
        echo -n "."
        sleep 5
    done
}

# Função para configurar Prometheus Federation
setup_federation() {
    print_status "Configurando Prometheus Federation..."
    
    # Criar namespace se não existir
    if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
        print_status "Criando namespace $NAMESPACE..."
        kubectl create namespace $NAMESPACE
    fi
    
    # Aplicar ConfigMaps
    print_status "Aplicando ConfigMaps de configuração..."
    kubectl apply -f $MONITORING_DIR/prometheus-federation-config.yaml
    kubectl apply -f $MONITORING_DIR/prometheus-federation-rules.yaml
    
    # Aplicar deployments e serviços
    print_status "Aplicando deployments e serviços..."
    kubectl apply -f $MONITORING_DIR/prometheus-federation-deployment.yaml
    
    # Aguardar deployments ficarem prontos
    wait_for_deployment "prometheus-global" $NAMESPACE 300
    wait_for_deployment "prometheus-local-1" $NAMESPACE 300
    wait_for_deployment "prometheus-local-2" $NAMESPACE 300
    
    print_status "Prometheus Federation configurado com sucesso!"
}

# Função para verificar status da federation
check_federation_status() {
    print_status "Verificando status da Prometheus Federation..."
    
    echo -e "\n${YELLOW}=== Prometheus Global ===${NC}"
    kubectl get pods -n $NAMESPACE -l app=prometheus,component=global
    
    echo -e "\n${YELLOW}=== Prometheus Local 1 ===${NC}"
    kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-1
    
    echo -e "\n${YELLOW}=== Prometheus Local 2 ===${NC}"
    kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-2
    
    echo -e "\n${YELLOW}=== Serviços ===${NC}"
    kubectl get services -n $NAMESPACE | grep prometheus
    
    echo -e "\n${YELLOW}=== PersistentVolumeClaims ===${NC}"
    kubectl get pvc -n $NAMESPACE | grep prometheus
    
    # Testar endpoints de health
    echo -e "\n${YELLOW}=== Health Checks ===${NC}"
    
    # Prometheus Global
    local global_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$global_pod" ]; then
        if kubectl exec -n $NAMESPACE $global_pod -- wget -q -O- http://localhost:9090/-/healthy >/dev/null 2>&1; then
            print_status "Prometheus Global: HEALTHY"
        else
            print_error "Prometheus Global: UNHEALTHY"
        fi
    fi
    
    # Prometheus Local 1
    local local1_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local1_pod" ]; then
        if kubectl exec -n $NAMESPACE $local1_pod -- wget -q -O- http://localhost:9090/-/healthy >/dev/null 2>&1; then
            print_status "Prometheus Local 1: HEALTHY"
        else
            print_error "Prometheus Local 1: UNHEALTHY"
        fi
    fi
    
    # Prometheus Local 2
    local local2_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local2_pod" ]; then
        if kubectl exec -n $NAMESPACE $local2_pod -- wget -q -O- http://localhost:9090/-/healthy >/dev/null 2>&1; then
            print_status "Prometheus Local 2: HEALTHY"
        else
            print_error "Prometheus Local 2: UNHEALTHY"
        fi
    fi
}

# Função para testar federation
test_federation() {
    print_status "Testando Prometheus Federation..."
    
    # Obter pods
    local global_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    local local1_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    local local2_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$global_pod" ] || [ -z "$local1_pod" ] || [ -z "$local2_pod" ]; then
        print_error "Não foi possível encontrar todos os pods do Prometheus"
        return 1
    fi
    
    # Testar federation endpoint
    print_status "Testando endpoint de federation..."
    local federation_test=$(kubectl exec -n $NAMESPACE $global_pod -- wget -q -O- "http://localhost:9090/federate?match[]={__name__=~\"job:.*\"}" 2>/dev/null | head -5)
    
    if [ -n "$federation_test" ]; then
        print_status "Federation endpoint está funcionando!"
        echo "Exemplo de métricas federadas:"
        echo "$federation_test"
    else
        print_error "Federation endpoint não está respondendo corretamente"
    fi
    
    # Testar queries
    print_status "Testando queries de agregação..."
    
    # Query de disponibilidade
    local availability_query="job:up:avg"
    local availability_result=$(kubectl exec -n $NAMESPACE $global_pod -- wget -q -O- "http://localhost:9090/api/v1/query?query=$availability_query" 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null)
    
    if [ -n "$availability_result" ] && [ "$availability_result" != "null" ]; then
        print_status "Query de disponibilidade funcionando: $availability_result"
    else
        print_warning "Query de disponibilidade não retornou resultados"
    fi
    
    # Query de CPU
    local cpu_query="job:cpu_usage:avg"
    local cpu_result=$(kubectl exec -n $NAMESPACE $global_pod -- wget -q -O- "http://localhost:9090/api/v1/query?query=$cpu_query" 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null)
    
    if [ -n "$cpu_result" ] && [ "$cpu_result" != "null" ]; then
        print_status "Query de CPU funcionando: ${cpu_result}%"
    else
        print_warning "Query de CPU não retornou resultados"
    fi
}

# Função para acessar Prometheus Global
access_prometheus() {
    print_status "Iniciando port-forward para Prometheus Global..."
    
    local global_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$global_pod" ]; then
        print_status "Acesse Prometheus Global em: http://localhost:9090"
        print_status "Pressione Ctrl+C para parar o port-forward"
        kubectl port-forward -n $NAMESPACE $global_pod 9090:9090
    else
        print_error "Não foi possível encontrar Prometheus Global pod"
    fi
}

# Função para acessar Prometheus Local 1
access_prometheus_local1() {
    print_status "Iniciando port-forward para Prometheus Local 1..."
    
    local local1_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local1_pod" ]; then
        print_status "Acesse Prometheus Local 1 em: http://localhost:9091"
        print_status "Pressione Ctrl+C para parar o port-forward"
        kubectl port-forward -n $NAMESPACE $local1_pod 9091:9090
    else
        print_error "Não foi possível encontrar Prometheus Local 1 pod"
    fi
}

# Função para acessar Prometheus Local 2
access_prometheus_local2() {
    print_status "Iniciando port-forward para Prometheus Local 2..."
    
    local local2_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local2_pod" ]; then
        print_status "Acesse Prometheus Local 2 em: http://localhost:9092"
        print_status "Pressione Ctrl+C para parar o port-forward"
        kubectl port-forward -n $NAMESPACE $local2_pod 9092:9090
    else
        print_error "Não foi possível encontrar Prometheus Local 2 pod"
    fi
}

# Função para limpar recursos
cleanup() {
    print_warning "Isso irá remover todos os recursos do Prometheus Federation!"
    read -p "Tem certeza que deseja continuar? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        print_status "Removendo Prometheus Federation..."
        
        # Remover deployments
        kubectl delete deployment prometheus-global prometheus-local-1 prometheus-local-2 -n $NAMESPACE --ignore-not-found=true
        
        # Remover serviços
        kubectl delete service prometheus-global-service prometheus-local-1-service prometheus-local-2-service -n $NAMESPACE --ignore-not-found=true
        
        # Remover PVCs
        kubectl delete pvc prometheus-global-pvc prometheus-local-1-pvc prometheus-local-2-pvc -n $NAMESPACE --ignore-not-found=true
        
        # Remover ConfigMaps
        kubectl delete configmap prometheus-global-config prometheus-local-1-config prometheus-local-2-config -n $NAMESPACE --ignore-not-found=true
        kubectl delete configmap prometheus-global-rules prometheus-local-rules -n $NAMESPACE --ignore-not-found=true
        
        print_status "Prometheus Federation removido com sucesso!"
    else
        print_status "Operação cancelada."
    fi
}

# Função para mostrar uso
show_usage() {
    echo "Uso: $0 [comando]"
    echo
    echo "Comandos disponíveis:"
    echo "  setup        - Configurar Prometheus Federation"
    echo "  status       - Verificar status da federation"
    echo "  test         - Testar federation"
    echo "  access       - Acessar Prometheus Global (port-forward)"
    echo "  access-local1 - Acessar Prometheus Local 1 (port-forward)"
    echo "  access-local2 - Acessar Prometheus Local 2 (port-forward)"
    echo "  cleanup      - Remover todos os recursos"
    echo "  help         - Mostrar esta ajuda"
    echo
    echo "Exemplos:"
    echo "  $0 setup"
    echo "  $0 status"
    echo "  $0 test"
    echo "  $0 access"
}

# Função principal
main() {
    case "${1:-help}" in
        setup)
            setup_federation
            ;;
        status)
            check_federation_status
            ;;
        test)
            test_federation
            ;;
        access)
            access_prometheus
            ;;
        access-local1)
            access_prometheus_local1
            ;;
        access-local2)
            access_prometheus_local2
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Comando desconhecido: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Verificar dependências
if ! command_exists kubectl; then
    print_error "kubectl não está instalado ou não está no PATH"
    exit 1
fi

if ! command_exists jq; then
    print_warning "jq não está instalado - algumas funcionalidades podem não funcionar corretamente"
fi

# Executar função principal
main "$@"

#!/bin/bash
# Script para configurar e gerenciar Prometheus Federation

set -e

NAMESPACE="monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="${SCRIPT_DIR}/../infrastructure/monitoring"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Função para verificar se o comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para esperar por deployment estar pronto
wait_for_deployment() {
    local deployment=$1
    local namespace=$2
    local timeout=${3:-300}
    
    print_status "Aguardando deployment $deployment estar pronto..."
    
    if kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $namespace; then
        print_status "Deployment $deployment está pronto!"
        return 0
    else
        print_error "Deployment $deployment não ficou pronto dentro do timeout"
        return 1
    fi
}

# Função para esperar por pods estarem prontos
wait_for_pods() {
    local label=$1
    local namespace=$2
    local expected=${3:-1}
    local timeout=${4:-300}
    
    print_status "Aguardando $expected pods com label $label estarem prontos..."
    
    local start_time=$(date +%s)
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            print_error "Timeout aguardando pods ficarem prontos"
            return 1
        fi
        
        local ready_pods=$(kubectl get pods -n $namespace -l $label -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | wc -w)
        
        if [ $ready_pods -ge $expected ]; then
            print_status "$ready_pods pods estão prontos!"
            return 0
        fi
        
        echo -n "."
        sleep 5
    done
}

# Função para configurar Prometheus Federation
setup_federation() {
    print_status "Configurando Prometheus Federation..."
    
    # Criar namespace se não existir
    if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
        print_status "Criando namespace $NAMESPACE..."
        kubectl create namespace $NAMESPACE
    fi
    
    # Aplicar ConfigMaps
    print_status "Aplicando ConfigMaps de configuração..."
    kubectl apply -f $MONITORING_DIR/prometheus-federation-config.yaml
    kubectl apply -f $MONITORING_DIR/prometheus-federation-rules.yaml
    
    # Aplicar deployments e serviços
    print_status "Aplicando deployments e serviços..."
    kubectl apply -f $MONITORING_DIR/prometheus-federation-deployment.yaml
    
    # Aguardar deployments ficarem prontos
    wait_for_deployment "prometheus-global" $NAMESPACE 300
    wait_for_deployment "prometheus-local-1" $NAMESPACE 300
    wait_for_deployment "prometheus-local-2" $NAMESPACE 300
    
    print_status "Prometheus Federation configurado com sucesso!"
}

# Função para verificar status da federation
check_federation_status() {
    print_status "Verificando status da Prometheus Federation..."
    
    echo -e "\n${YELLOW}=== Prometheus Global ===${NC}"
    kubectl get pods -n $NAMESPACE -l app=prometheus,component=global
    
    echo -e "\n${YELLOW}=== Prometheus Local 1 ===${NC}"
    kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-1
    
    echo -e "\n${YELLOW}=== Prometheus Local 2 ===${NC}"
    kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-2
    
    echo -e "\n${YELLOW}=== Serviços ===${NC}"
    kubectl get services -n $NAMESPACE | grep prometheus
    
    echo -e "\n${YELLOW}=== PersistentVolumeClaims ===${NC}"
    kubectl get pvc -n $NAMESPACE | grep prometheus
    
    # Testar endpoints de health
    echo -e "\n${YELLOW}=== Health Checks ===${NC}"
    
    # Prometheus Global
    local global_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$global_pod" ]; then
        if kubectl exec -n $NAMESPACE $global_pod -- wget -q -O- http://localhost:9090/-/healthy >/dev/null 2>&1; then
            print_status "Prometheus Global: HEALTHY"
        else
            print_error "Prometheus Global: UNHEALTHY"
        fi
    fi
    
    # Prometheus Local 1
    local local1_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local1_pod" ]; then
        if kubectl exec -n $NAMESPACE $local1_pod -- wget -q -O- http://localhost:9090/-/healthy >/dev/null 2>&1; then
            print_status "Prometheus Local 1: HEALTHY"
        else
            print_error "Prometheus Local 1: UNHEALTHY"
        fi
    fi
    
    # Prometheus Local 2
    local local2_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local2_pod" ]; then
        if kubectl exec -n $NAMESPACE $local2_pod -- wget -q -O- http://localhost:9090/-/healthy >/dev/null 2>&1; then
            print_status "Prometheus Local 2: HEALTHY"
        else
            print_error "Prometheus Local 2: UNHEALTHY"
        fi
    fi
}

# Função para testar federation
test_federation() {
    print_status "Testando Prometheus Federation..."
    
    # Obter pods
    local global_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    local local1_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    local local2_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$global_pod" ] || [ -z "$local1_pod" ] || [ -z "$local2_pod" ]; then
        print_error "Não foi possível encontrar todos os pods do Prometheus"
        return 1
    fi
    
    # Testar federation endpoint
    print_status "Testando endpoint de federation..."
    local federation_test=$(kubectl exec -n $NAMESPACE $global_pod -- wget -q -O- "http://localhost:9090/federate?match[]={__name__=~\"job:.*\"}" 2>/dev/null | head -5)
    
    if [ -n "$federation_test" ]; then
        print_status "Federation endpoint está funcionando!"
        echo "Exemplo de métricas federadas:"
        echo "$federation_test"
    else
        print_error "Federation endpoint não está respondendo corretamente"
    fi
    
    # Testar queries
    print_status "Testando queries de agregação..."
    
    # Query de disponibilidade
    local availability_query="job:up:avg"
    local availability_result=$(kubectl exec -n $NAMESPACE $global_pod -- wget -q -O- "http://localhost:9090/api/v1/query?query=$availability_query" 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null)
    
    if [ -n "$availability_result" ] && [ "$availability_result" != "null" ]; then
        print_status "Query de disponibilidade funcionando: $availability_result"
    else
        print_warning "Query de disponibilidade não retornou resultados"
    fi
    
    # Query de CPU
    local cpu_query="job:cpu_usage:avg"
    local cpu_result=$(kubectl exec -n $NAMESPACE $global_pod -- wget -q -O- "http://localhost:9090/api/v1/query?query=$cpu_query" 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null)
    
    if [ -n "$cpu_result" ] && [ "$cpu_result" != "null" ]; then
        print_status "Query de CPU funcionando: ${cpu_result}%"
    else
        print_warning "Query de CPU não retornou resultados"
    fi
}

# Função para acessar Prometheus Global
access_prometheus() {
    print_status "Iniciando port-forward para Prometheus Global..."
    
    local global_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$global_pod" ]; then
        print_status "Acesse Prometheus Global em: http://localhost:9090"
        print_status "Pressione Ctrl+C para parar o port-forward"
        kubectl port-forward -n $NAMESPACE $global_pod 9090:9090
    else
        print_error "Não foi possível encontrar Prometheus Global pod"
    fi
}

# Função para acessar Prometheus Local 1
access_prometheus_local1() {
    print_status "Iniciando port-forward para Prometheus Local 1..."
    
    local local1_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local1_pod" ]; then
        print_status "Acesse Prometheus Local 1 em: http://localhost:9091"
        print_status "Pressione Ctrl+C para parar o port-forward"
        kubectl port-forward -n $NAMESPACE $local1_pod 9091:9090
    else
        print_error "Não foi possível encontrar Prometheus Local 1 pod"
    fi
}

# Função para acessar Prometheus Local 2
access_prometheus_local2() {
    print_status "Iniciando port-forward para Prometheus Local 2..."
    
    local local2_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus,component=local-2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$local2_pod" ]; then
        print_status "Acesse Prometheus Local 2 em: http://localhost:9092"
        print_status "Pressione Ctrl+C para parar o port-forward"
        kubectl port-forward -n $NAMESPACE $local2_pod 9092:9090
    else
        print_error "Não foi possível encontrar Prometheus Local 2 pod"
    fi
}

# Função para limpar recursos
cleanup() {
    print_warning "Isso irá remover todos os recursos do Prometheus Federation!"
    read -p "Tem certeza que deseja continuar? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        print_status "Removendo Prometheus Federation..."
        
        # Remover deployments
        kubectl delete deployment prometheus-global prometheus-local-1 prometheus-local-2 -n $NAMESPACE --ignore-not-found=true
        
        # Remover serviços
        kubectl delete service prometheus-global-service prometheus-local-1-service prometheus-local-2-service -n $NAMESPACE --ignore-not-found=true
        
        # Remover PVCs
        kubectl delete pvc prometheus-global-pvc prometheus-local-1-pvc prometheus-local-2-pvc -n $NAMESPACE --ignore-not-found=true
        
        # Remover ConfigMaps
        kubectl delete configmap prometheus-global-config prometheus-local-1-config prometheus-local-2-config -n $NAMESPACE --ignore-not-found=true
        kubectl delete configmap prometheus-global-rules prometheus-local-rules -n $NAMESPACE --ignore-not-found=true
        
        print_status "Prometheus Federation removido com sucesso!"
    else
        print_status "Operação cancelada."
    fi
}

# Função para mostrar uso
show_usage() {
    echo "Uso: $0 [comando]"
    echo
    echo "Comandos disponíveis:"
    echo "  setup        - Configurar Prometheus Federation"
    echo "  status       - Verificar status da federation"
    echo "  test         - Testar federation"
    echo "  access       - Acessar Prometheus Global (port-forward)"
    echo "  access-local1 - Acessar Prometheus Local 1 (port-forward)"
    echo "  access-local2 - Acessar Prometheus Local 2 (port-forward)"
    echo "  cleanup      - Remover todos os recursos"
    echo "  help         - Mostrar esta ajuda"
    echo
    echo "Exemplos:"
    echo "  $0 setup"
    echo "  $0 status"
    echo "  $0 test"
    echo "  $0 access"
}

# Função principal
main() {
    case "${1:-help}" in
        setup)
            setup_federation
            ;;
        status)
            check_federation_status
            ;;
        test)
            test_federation
            ;;
        access)
            access_prometheus
            ;;
        access-local1)
            access_prometheus_local1
            ;;
        access-local2)
            access_prometheus_local2
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Comando desconhecido: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Verificar dependências
if ! command_exists kubectl; then
    print_error "kubectl não está instalado ou não está no PATH"
    exit 1
fi

if ! command_exists jq; then
    print_warning "jq não está instalado - algumas funcionalidades podem não funcionar corretamente"
fi

# Executar função principal
main "$@"

# Detect kubectl (prefere microk8s se disponível)
detect_kubectl() {
  if command -v microk8s >/dev/null 2>&1 && microk8s status --wait-ready >/dev/null 2>&1; then
    echo "microk8s kubectl"
  elif command -v kubectl >/dev/null 2>&1; then
    echo "kubectl"
  else
    echo "Erro: kubectl não encontrado." >&2
    exit 1
  fi
}

KCTL="${KUBECTL_CMD:-$(detect_kubectl)}"

info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERR ]\033[0m $*"; }

ensure_namespace() {
  local ns="monitoring"
  if ! ${KCTL} get ns "${ns}" >/dev/null 2>&1; then
    info "Criando namespace ${ns}..."
    ${KCTL} create namespace "${ns}"
  else
    info "Namespace ${ns} já existe."
  fi
}

ensure_storageclass() {
  local sc="local-hostpath"
  if ${KCTL} get sc "${sc}" >/dev/null 2>&1; then
    info "StorageClass ${sc} encontrado."
    return
  fi

  if ${KCTL} get sc microk8s-hostpath >/dev/null 2>&1; then
    warn "StorageClass ${sc} não encontrado; usando microk8s-hostpath como fallback."
    # Opcionalmente poderíamos patch os PVCs; por ora apenas notificamos.
    return
  fi

  warn "Nenhum StorageClass padrão encontrado. Criando ${sc} (hostPath)."
  ${KCTL} apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-hostpath
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
}

apply_manifests() {
  info "Aplicando ConfigMaps (config e regras)..."
  ${KCTL} apply -f infrastructure/monitoring/prometheus-federation-config.yaml
  ${KCTL} apply -f infrastructure/monitoring/prometheus-federation-rules.yaml

  info "Aplicando Deployments/Services/PVCs..."
  ${KCTL} apply -f infrastructure/monitoring/prometheus-federation-deployment.yaml

  # Aplicar NetworkPolicy se existir
  if [ -f security/network-policies/monitoring-network-policy.yaml ]; then
    info "Aplicando NetworkPolicy de monitoring..."
    ${KCTL} apply -f security/network-policies/monitoring-network-policy.yaml
  fi
}

wait_ready() {
  info "Aguardando Prometheus Global pronto..."
  ${KCTL} -n monitoring rollout status deployment/prometheus-global --timeout=180s || true

  if ${KCTL} -n monitoring get deploy prometheus-local-1 >/dev/null 2>&1; then
    info "Aguardando Prometheus Local 1 pronto..."
    ${KCTL} -n monitoring rollout status deployment/prometheus-local-1 --timeout=180s || true
  fi

  if ${KCTL} -n monitoring get deploy prometheus-local-2 >/dev/null 2>&1; then
    info "Aguardando Prometheus Local 2 pronto..."
    ${KCTL} -n monitoring rollout status deployment/prometheus-local-2 --timeout=180s || true
  fi
}

validate_endpoints() {
  info "Validando serviços e endpoints:"
  ${KCTL} -n monitoring get svc | sed -n '1,200p'
  ${KCTL} -n monitoring get pods -o wide | sed -n '1,200p'

  info "Targets esperados (federation):"
  echo " - prometheus-global-service:9090 (global)"
  echo " - prometheus-local-1-service:9090 (local-1)"
  echo " - prometheus-local-2-service:9090 (local-2, se aplicável)"
  echo
  info "Dica: verifique /federate com port-forward:"
  echo " ${KCTL} -n monitoring port-forward svc/prometheus-global-service 9090:9090"
  echo " Abra http://localhost:9090/targets e http://localhost:9090/federate"
}

main() {
  info "Iniciando setup de Prometheus Federation..."
  ensure_namespace
  ensure_storageclass
  apply_manifests
  wait_ready
  validate_endpoints
  info "Setup concluído."
}

main "$@"