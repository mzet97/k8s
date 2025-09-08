#!/bin/bash

# Redis Network Connectivity Diagnostic Script
# Comprehensive diagnostic for Redis external access issues

set -e

echo "🔍 Redis Network Connectivity Diagnostic"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

print_section() {
    echo -e "${PURPLE}📋 $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Determine kubectl command
get_kubectl_cmd() {
    if command_exists kubectl; then
        echo "kubectl"
    elif command_exists microk8s; then
        echo "microk8s kubectl"
    else
        print_error "Nem kubectl nem microk8s encontrados"
        exit 1
    fi
}

# Get cluster information
diagnose_cluster() {
    local kubectl_cmd="$1"
    
    print_section "Diagnóstico do Cluster Kubernetes"
    
    # Check cluster connectivity
    if $kubectl_cmd cluster-info >/dev/null 2>&1; then
        print_success "Conexão com cluster OK"
        $kubectl_cmd cluster-info
    else
        print_error "Não é possível conectar ao cluster Kubernetes"
        return 1
    fi
    
    echo ""
    
    # Check nodes
    print_info "Nodes do cluster:"
    $kubectl_cmd get nodes -o wide
    
    echo ""
    
    # Get node IPs
    print_info "IPs dos nodes:"
    $kubectl_cmd get nodes -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.status.addresses[?(@.type=="InternalIP")].address}{" (Internal), "}{.status.addresses[?(@.type=="ExternalIP")].address}{" (External)"}{"\n"}{end}'
    
    echo ""
}

# Check Redis namespace and resources
diagnose_redis_namespace() {
    local kubectl_cmd="$1"
    
    print_section "Diagnóstico do Namespace Redis"
    
    # Check if namespace exists
    if $kubectl_cmd get namespace redis >/dev/null 2>&1; then
        print_success "Namespace 'redis' existe"
    else
        print_error "Namespace 'redis' não encontrado"
        print_info "Execute: $kubectl_cmd apply -f 00-namespace.yaml"
        return 1
    fi
    
    echo ""
    
    # Check pods
    print_info "Pods no namespace redis:"
    $kubectl_cmd get pods -n redis -o wide
    
    echo ""
    
    # Check services
    print_info "Services no namespace redis:"
    $kubectl_cmd get svc -n redis -o wide
    
    echo ""
    
    # Check secrets
    print_info "Secrets no namespace redis:"
    $kubectl_cmd get secrets -n redis
    
    echo ""
    
    # Check configmaps
    print_info "ConfigMaps no namespace redis:"
    $kubectl_cmd get configmaps -n redis
    
    echo ""
}

# Check specific Redis services and pods
diagnose_redis_services() {
    local kubectl_cmd="$1"
    
    print_section "Diagnóstico dos Serviços Redis"
    
    # Expected services
    local services=("redis-master" "redis-replica" "redis-cluster" "redis-proxy-service" "redis-proxy-external")
    
    for service in "${services[@]}"; do
        if $kubectl_cmd get svc "$service" -n redis >/dev/null 2>&1; then
            print_success "Service '$service' encontrado"
            $kubectl_cmd get svc "$service" -n redis -o wide
        else
            print_warning "Service '$service' não encontrado"
        fi
        echo ""
    done
    
    # Check NodePort services specifically
    print_info "Services do tipo NodePort:"
    $kubectl_cmd get svc -n redis --field-selector spec.type=NodePort -o wide
    
    echo ""
    
    # Check endpoints
    print_info "Endpoints dos services:"
    $kubectl_cmd get endpoints -n redis
    
    echo ""
}

# Check pods health and logs
diagnose_redis_pods() {
    local kubectl_cmd="$1"
    
    print_section "Diagnóstico dos Pods Redis"
    
    # Get all Redis pods
    local pods
    pods=$($kubectl_cmd get pods -n redis -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    if [ -z "$pods" ]; then
        print_error "Nenhum pod encontrado no namespace redis"
        return 1
    fi
    
    for pod in $pods; do
        echo "================================"
        print_info "Diagnóstico do pod: $pod"
        
        # Pod status
        local status
        status=$($kubectl_cmd get pod "$pod" -n redis -o jsonpath='{.status.phase}')
        
        if [ "$status" = "Running" ]; then
            print_success "Status: $status"
        else
            print_error "Status: $status"
        fi
        
        # Pod details
        $kubectl_cmd describe pod "$pod" -n redis | grep -A 10 -B 5 "Events:\|Conditions:\|Status:"
        
        echo ""
        
        # Recent logs
        print_info "Logs recentes (últimas 10 linhas):"
        $kubectl_cmd logs "$pod" -n redis --tail=10 2>/dev/null || print_warning "Não foi possível obter logs"
        
        echo ""
    done
}

# Check network connectivity
diagnose_network_connectivity() {
    local kubectl_cmd="$1"
    
    print_section "Diagnóstico de Conectividade de Rede"
    
    # Get node IP
    local node_ip
    node_ip=$($kubectl_cmd get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    
    if [ -z "$node_ip" ]; then
        print_error "Não foi possível obter IP do node"
        return 1
    fi
    
    print_success "IP do node principal: $node_ip"
    
    echo ""
    
    # Check if ports are listening
    print_info "Verificando portas NodePort do Redis:"
    
    local redis_ports=("30379" "30380" "30381" "30382" "30404")
    
    for port in "${redis_ports[@]}"; do
        echo -n "  Porta $port: "
        
        # Try to connect to the port
        if timeout 5 bash -c "</dev/tcp/$node_ip/$port" 2>/dev/null; then
            print_success "ABERTA"
        else
            print_error "FECHADA ou INACESSÍVEL"
        fi
    done
    
    echo ""
    
    # Test external connectivity using netcat if available
    if command_exists nc; then
        print_info "Testando conectividade TCP com netcat:"
        
        for port in "${redis_ports[@]}"; do
            echo -n "  TCP $node_ip:$port: "
            if timeout 5 nc -z "$node_ip" "$port" 2>/dev/null; then
                print_success "OK"
            else
                print_error "FALHOU"
            fi
        done
    else
        print_warning "netcat não disponível para teste TCP"
    fi
    
    echo ""
}

# Test Redis connectivity
test_redis_connectivity() {
    local kubectl_cmd="$1"
    
    print_section "Teste de Conectividade Redis"
    
    # Get node IP
    local node_ip
    node_ip=$($kubectl_cmd get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    
    if [ -z "$node_ip" ]; then
        print_error "Não foi possível obter IP do node"
        return 1
    fi
    
    if ! command_exists redis-cli; then
        print_warning "redis-cli não instalado. Pulando testes de conectividade Redis."
        print_info "Para instalar: sudo apt install redis-tools (Ubuntu/Debian)"
        return 0
    fi
    
    print_info "Testando conectividade Redis com redis-cli..."
    
    local password="Admin@123"
    local tests=(
        "Redis Proxy (sem TLS)|$node_ip|30379|false"
        "Redis Master (com TLS)|$node_ip|30380|true"
        "Redis Réplicas (sem TLS)|$node_ip|30381|false"
        "Redis Réplicas (com TLS)|$node_ip|30382|true"
    )
    
    local success_count=0
    local total_tests=${#tests[@]}
    
    for test in "${tests[@]}"; do
        IFS='|' read -r description host port use_tls <<< "$test"
        
        echo -n "  $description ($host:$port): "
        
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
    print_info "Resultado: $success_count/$total_tests testes bem-sucedidos"
    
    if [ "$success_count" -eq 0 ]; then
        print_error "Nenhuma conexão Redis funcionou"
    elif [ "$success_count" -lt "$total_tests" ]; then
        print_warning "Algumas conexões Redis falharam"
    else
        print_success "Todas as conexões Redis funcionaram!"
    fi
    
    echo ""
}

# Test HAProxy stats dashboard
test_haproxy_stats() {
    local kubectl_cmd="$1"
    
    print_section "Teste do Dashboard HAProxy"
    
    # Get node IP
    local node_ip
    node_ip=$($kubectl_cmd get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    
    if [ -z "$node_ip" ]; then
        print_error "Não foi possível obter IP do node"
        return 1
    fi
    
    if command_exists curl; then
        print_info "Testando dashboard HAProxy em http://$node_ip:30404/stats"
        
        if curl -s --connect-timeout 10 --max-time 30 "http://$node_ip:30404/stats" >/dev/null; then
            print_success "Dashboard HAProxy acessível"
            print_info "URL: http://$node_ip:30404/stats"
            print_info "Usuário: admin | Senha: admin123"
        else
            print_error "Dashboard HAProxy inacessível"
        fi
    else
        print_warning "curl não disponível para teste do dashboard"
        print_info "Teste manualmente: http://$node_ip:30404/stats"
    fi
    
    echo ""
}

# Check DNS configuration
diagnose_dns() {
    print_section "Diagnóstico de Configuração DNS"
    
    # Check hosts file
    if [ -f /etc/hosts ]; then
        print_info "Verificando /etc/hosts para entradas Redis:"
        
        if grep -q "redis.home.arpa\|redis-proxy.home.arpa" /etc/hosts; then
            print_success "Entradas Redis encontradas em /etc/hosts:"
            grep -E "redis.*\.home\.arpa" /etc/hosts | while read -r line; do
                echo "    $line"
            done
        else
            print_warning "Nenhuma entrada Redis encontrada em /etc/hosts"
            print_info "Execute setup-external-client.sh para configurar automaticamente"
        fi
    else
        print_error "/etc/hosts não encontrado"
    fi
    
    echo ""
    
    # Test DNS resolution
    local hosts=("redis.home.arpa" "redis-proxy.home.arpa" "redis-master.home.arpa")
    
    print_info "Testando resolução DNS:"
    
    for host in "${hosts[@]}"; do
        echo -n "  $host: "
        
        if getent hosts "$host" >/dev/null 2>&1; then
            local resolved_ip
            resolved_ip=$(getent hosts "$host" | awk '{print $1}')
            print_success "resolve para $resolved_ip"
        else
            print_error "não resolve"
        fi
    done
    
    echo ""
}

# Generate fix recommendations
generate_recommendations() {
    local kubectl_cmd="$1"
    
    print_section "Recomendações de Correção"
    
    echo "Com base no diagnóstico, aqui estão as ações recomendadas:"
    echo ""
    
    # Check if Redis is running
    local redis_pods_running
    redis_pods_running=$($kubectl_cmd get pods -n redis -l 'app in (redis-master,redis-replica)' --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    
    if [ "$redis_pods_running" -eq 0 ]; then
        print_error "CRÍTICO: Nenhum pod Redis está executando"
        echo "  1. Verifique os logs dos pods: $kubectl_cmd logs -n redis -l app=redis-master"
        echo "  2. Execute o script de correção: ./fix-installation-issues.sh"
        echo "  3. Reinstale se necessário: ./install-redis.sh"
        echo ""
    fi
    
    # Check HAProxy proxy
    local proxy_pods_running
    proxy_pods_running=$($kubectl_cmd get pods -n redis -l app=redis-proxy --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    
    if [ "$proxy_pods_running" -eq 0 ]; then
        print_warning "HAProxy proxy não está executando"
        echo "  1. Execute o script de correção: ./fix-redis-proxy.sh"
        echo "  2. Verifique se os certificados foram criados: $kubectl_cmd get secret redis-proxy-tls -n redis"
        echo "  3. Reinicie o deployment: $kubectl_cmd rollout restart deployment/redis-proxy -n redis"
        echo ""
    fi
    
    # Check external access setup
    if ! grep -q "redis.home.arpa" /etc/hosts 2>/dev/null; then
        print_warning "DNS não configurado para acesso externo"
        echo "  1. Execute o script de setup: ./setup-external-client.sh"
        echo "  2. Ou configure manualmente o /etc/hosts"
        echo ""
    fi
    
    # Check Redis CLI
    if ! command_exists redis-cli; then
        print_warning "Redis CLI não está instalado"
        echo "  1. Ubuntu/Debian: sudo apt install redis-tools"
        echo "  2. RHEL/CentOS: sudo yum install redis"
        echo "  3. macOS: brew install redis"
        echo ""
    fi
    
    # Network troubleshooting
    echo "💡 Para problemas de rede:"
    echo "  1. Verifique se as portas NodePort estão abertas no firewall"
    echo "  2. Teste conectividade: telnet <NODE_IP> 30379"
    echo "  3. Verifique se o cluster está acessível externamente"
    echo "  4. Em clouds (AWS, GCP, Azure), configure Security Groups/Firewalls"
    echo ""
    
    # Quick test commands
    local node_ip
    node_ip=$($kubectl_cmd get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    
    if [ -n "$node_ip" ]; then
        echo "🧪 Comandos para teste rápido:"
        echo "  # Teste básico:"
        echo "  redis-cli -h $node_ip -p 30379 -a Admin@123 ping"
        echo ""
        echo "  # Dashboard HAProxy:"
        echo "  curl http://$node_ip:30404/stats"
        echo ""
        echo "  # Teste de portas:"
        echo "  nc -zv $node_ip 30379"
        echo ""
    fi
}

# Main execution
main() {
    local kubectl_cmd
    kubectl_cmd=$(get_kubectl_cmd)
    
    print_info "Usando comando: $kubectl_cmd"
    echo ""
    
    # Run all diagnostics
    diagnose_cluster "$kubectl_cmd" || true
    echo ""
    
    diagnose_redis_namespace "$kubectl_cmd" || true
    echo ""
    
    diagnose_redis_services "$kubectl_cmd" || true
    echo ""
    
    diagnose_redis_pods "$kubectl_cmd" || true
    echo ""
    
    diagnose_network_connectivity "$kubectl_cmd" || true
    echo ""
    
    test_redis_connectivity "$kubectl_cmd" || true
    echo ""
    
    test_haproxy_stats "$kubectl_cmd" || true
    echo ""
    
    diagnose_dns || true
    echo ""
    
    generate_recommendations "$kubectl_cmd"
    
    echo ""
    print_success "Diagnóstico completo!"
    print_info "Salve esta saída para análise posterior ou para reportar problemas"
}

# Run main function
main "$@"