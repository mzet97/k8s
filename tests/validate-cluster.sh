#!/bin/bash

# Script para validar o cluster Kubernetes e seus componentes

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Contadores
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

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
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
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

# Função para testar conectividade com cluster
test_cluster_connectivity() {
    print_header "Testando conectividade com cluster..."
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if $KUBECTL_CMD cluster-info >/dev/null 2>&1; then
        print_success "Conectividade com cluster OK"
        return 0
    else
        print_fail "Não foi possível conectar ao cluster"
        return 1
    fi
}

# Função para testar namespaces
test_namespaces() {
    print_header "Testando namespaces..."
    
    local namespaces=("monitoring" "velero" "redis-ha" "argocd")
    
    for ns in "${namespaces[@]}"; do
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        if $KUBECTL_CMD get namespace "$ns" >/dev/null 2>&1; then
            print_success "Namespace $ns existe"
        else
            print_fail "Namespace $ns não encontrado"
        fi
    done
}

# Função para testar pods
test_pods() {
    print_header "Testando pods..."
    
    # Testar pods do Prometheus
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if $KUBECTL_CMD get pods -n monitoring -l app=prometheus --field-selector=status.phase=Running | grep -q "Running"; then
        print_success "Pods do Prometheus estão rodando"
    else
        print_fail "Pods do Prometheus não estão rodando"
    fi
    
    # Testar pods do Velero
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if $KUBECTL_CMD get pods -n velero --field-selector=status.phase=Running | grep -q "velero"; then
        print_success "Pods do Velero estão rodando"
    else
        print_fail "Pods do Velero não estão rodando"
    fi
    
    # Testar pods do Redis
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if $KUBECTL_CMD get pods -n redis-ha --field-selector=status.phase=Running | grep -q "redis"; then
        print_success "Pods do Redis estão rodando"
    else
        print_fail "Pods do Redis não estão rodando"
    fi
    
    # Testar pods do ArgoCD
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if $KUBECTL_CMD get pods -n argocd -l app.kubernetes.io/name=argocd-server --field-selector=status.phase=Running | grep -q "Running"; then
        print_success "Pods do ArgoCD estão rodando"
    else
        print_fail "Pods do ArgoCD não estão rodando"
    fi
}

# Função para testar serviços
test_services() {
    print_header "Testando serviços..."
    
    # Testar serviços do Prometheus
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if $KUBECTL_CMD get svc -n monitoring | grep -q "prometheus-global-service"; then
        print_success "Serviço Prometheus Global existe"
    else
        print_fail "Serviço Prometheus Global não encontrado"
    fi
    
    # Testar serviços do Redis
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if $KUBECTL_CMD get svc -n redis-ha | grep -q "redis-master"; then
        print_success "Serviço Redis Master existe"
    else
        print_fail "Serviço Redis Master não encontrado"
    fi
}

# Função para testar Prometheus Federation
test_prometheus_federation() {
    print_header "Testando Prometheus Federation..."
    
    # Obter pod do Prometheus Global
    local global_pod=$($KUBECTL_CMD get pods -n monitoring -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$global_pod" ]; then
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        
        # Testar endpoint de federation
        if $KUBECTL_CMD exec -n monitoring "$global_pod" -- wget -q -O- "http://localhost:9090/federate?match[]={__name__=~\"job:.*\"}" >/dev/null 2>&1; then
            print_success "Endpoint de federation está funcionando"
        else
            print_fail "Endpoint de federation não está respondendo"
        fi
        
        # Testar queries
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        local query_result=$($KUBECTL_CMD exec -n monitoring "$global_pod" -- wget -q -O- "http://localhost:9090/api/v1/query?query=up" 2>/dev/null | jq -r '.status' 2>/dev/null)
        if [ "$query_result" = "success" ]; then
            print_success "Queries do Prometheus estão funcionando"
        else
            print_fail "Queries do Prometheus não estão funcionando"
        fi
    else
        print_fail "Pod do Prometheus Global não encontrado"
    fi
}

# Função para testar Redis
test_redis() {
    print_header "Testando Redis..."
    
    # Testar Redis Sentinel
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    local sentinel_pod=$($KUBECTL_CMD get pods -n redis-ha -l app=redis-sentinel -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$sentinel_pod" ]; then
        if $KUBECTL_CMD exec -n redis-ha "$sentinel_pod" -- redis-cli -p 26379 ping | grep -q "PONG"; then
            print_success "Redis Sentinel está respondendo"
        else
            print_fail "Redis Sentinel não está respondendo"
        fi
    else
        print_fail "Pod do Redis Sentinel não encontrado"
    fi
    
    # Testar Redis Master
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    local master_pod=$($KUBECTL_CMD get pods -n redis-ha -l app=redis-master -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$master_pod" ]; then
        if $KUBECTL_CMD exec -n redis-ha "$master_pod" -- redis-cli ping | grep -q "PONG"; then
            print_success "Redis Master está respondendo"
        else
            print_fail "Redis Master não está respondendo"
        fi
    else
        print_fail "Pod do Redis Master não encontrado"
    fi
}

# Função para testar Velero
test_velero() {
    print_header "Testando Velero..."
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Testar se o Velero está funcionando
    if $KUBECTL_CMD get deployment velero -n velero >/dev/null 2>&1; then
        print_success "Deployment do Velero existe"
    else
        print_fail "Deployment do Velero não encontrado"
    fi
    
    # Testar backup location
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if $KUBECTL_CMD get backupstoragelocation default -n velero >/dev/null 2>&1; then
        print_success "BackupStorageLocation existe"
    else
        print_fail "BackupStorageLocation não encontrada"
    fi
}

# Função para testar ArgoCD
test_argocd() {
    print_header "Testando ArgoCD..."
    
    # Testar ApplicationSets
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if $KUBECTL_CMD get applicationsets -n argocd | grep -q "infrastructure-apps"; then
        print_success "ApplicationSets estão configurados"
    else
        print_fail "ApplicationSets não encontrados"
    fi
    
    # Testar projetos
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if $KUBECTL_CMD get appprojects -n argocd | grep -q "infrastructure"; then
        print_success "Projetos do ArgoCD estão configurados"
    else
        print_fail "Projetos do ArgoCD não encontrados"
    fi
}

# Função para testar storage
test_storage() {
    print_header "Testando storage..."
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Verificar storage classes
    local storage_classes=$($KUBECTL_CMD get storageclass -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    if [ -n "$storage_classes" ]; then
        print_success "Storage classes disponíveis: $storage_classes"
    else
        print_fail "Nenhuma storage class encontrada"
    fi
    
    # Verificar PVCs
    local pvc_count=$($KUBECTL_CMD get pvc --all-namespaces --no-headers 2>/dev/null | wc -l)
    if [ "$pvc_count" -gt 0 ]; then
        print_success "PVCs encontrados: $pvc_count"
    else
        print_warning "Nenhum PVC encontrado"
    fi
}

# Função para testar rede
test_network() {
    print_header "Testando conectividade de rede..."
    
    # Testar DNS
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    local dns_pod=$($KUBECTL_CMD get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$dns_pod" ]; then
        print_success "DNS do cluster está funcionando"
    else
        print_fail "DNS do cluster não encontrado"
    fi
}

# Função para executar todos os testes
run_all_tests() {
    print_header "Iniciando validação completa do cluster..."
    
    test_cluster_connectivity
    test_namespaces
    test_pods
    test_services
    test_storage
    test_network
    test_prometheus_federation
    test_redis
    test_velero
    test_argocd
    
    print_summary
}

# Função para imprimir resumo
print_summary() {
    echo
    echo "=========================================="
    echo "           RESUMO DOS TESTES              "
    echo "=========================================="
    echo "Total de testes: $TESTS_TOTAL"
    echo "Testes passados: $TESTS_PASSED"
    echo "Testes falhados: $TESTS_FAILED"
    echo
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}✅ Todos os testes passaram!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Alguns testes falharam!${NC}"
        exit 1
    fi
}

# Função para mostrar uso
show_usage() {
    echo "Uso: $0 [opção]"
    echo
    echo "Opções:"
    echo "  all          - Executar todos os testes (padrão)"
    echo "  cluster      - Testar apenas conectividade do cluster"
    echo "  namespaces   - Testar apenas namespaces"
    echo "  pods         - Testar apenas pods"
    echo "  services     - Testar apenas serviços"
    echo "  storage      - Testar apenas storage"
    echo "  network      - Testar apenas rede"
    echo "  prometheus   - Testar apenas Prometheus"
    echo "  redis        - Testar apenas Redis"
    echo "  velero       - Testar apenas Velero"
    echo "  argocd       - Testar apenas ArgoCD"
    echo "  help         - Mostrar esta ajuda"
    echo
    echo "Exemplos:"
    echo "  $0 all"
    echo "  $0 prometheus"
    echo "  $0 redis"
}

# Função principal
main() {
    case "${1:-all}" in
        all)
            run_all_tests
            ;;
        cluster)
            test_cluster_connectivity
            print_summary
            ;;
        namespaces)
            test_namespaces
            print_summary
            ;;
        pods)
            test_pods
            print_summary
            ;;
        services)
            test_services
            print_summary
            ;;
        storage)
            test_storage
            print_summary
            ;;
        network)
            test_network
            print_summary
            ;;
        prometheus)
            test_prometheus_federation
            print_summary
            ;;
        redis)
            test_redis
            print_summary
            ;;
        velero)
            test_velero
            print_summary
            ;;
        argocd)
            test_argocd
            print_summary
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Opção desconhecida: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Verificar dependências
if ! command_exists kubectl && ! command_exists microk8s; then
    print_error "kubectl ou microk8s não encontrado"
    exit 1
fi

if ! command_exists jq; then
    print_warning "jq não está instalado - algumas funcionalidades podem não funcionar corretamente"
fi

# Executar função principal
setup_kubectl
main "$@"