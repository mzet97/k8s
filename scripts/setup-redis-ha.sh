#!/bin/bash
set -e

echo "=== Configurando Redis High Availability ==="

# Função para verificar se o Redis está pronto
wait_for_redis() {
    local pod=$1
    local namespace=$2
    local timeout=$3
    
    echo "Aguardando Redis pod $pod ficar pronto..."
    kubectl wait --for=condition=ready --timeout="${timeout}s" pod/"$pod" -n "$namespace"
}

# Função para configurar Redis Sentinel
setup_sentinel() {
    echo "=== Configurando Redis com Sentinel ==="
    
    # Aplicar configurações
    kubectl apply -f applications/redis-ha/redis-sentinel-config.yaml
    kubectl apply -f applications/redis-ha/redis-sentinel-deployment.yaml
    
    echo "Aguardando Redis Master ficar pronto..."
    kubectl wait --for=condition=available --timeout=300s deployment/redis-master -n default
    
    echo "Aguardando Redis Slaves ficarem prontos..."
    kubectl wait --for=condition=available --timeout=300s deployment/redis-slave -n default
    
    echo "Aguardando Redis Sentinels ficarem prontos..."
    kubectl wait --for=condition=available --timeout=300s deployment/redis-sentinel -n default
    
    echo "Verificando status do Redis Sentinel..."
    
    # Verificar master
    echo "Verificando Redis Master:"
    kubectl exec -it deployment/redis-master -- redis-cli info replication
    
    # Verificar sentinels
    echo "Verificando Redis Sentinels:"
    for i in {0..2}; do
        echo "Sentinel $i:"
        kubectl exec -it deployment/redis-sentinel -- redis-cli -p 26379 sentinel get-master-addr-by-name mymaster
    done
    
    echo "✓ Redis Sentinel configurado com sucesso!"
}

# Função para configurar Redis Cluster
setup_cluster() {
    echo "=== Configurando Redis Cluster ==="
    
    # Aplicar configurações do cluster
    kubectl apply -f applications/redis-ha/redis-cluster.yaml
    
    echo "Aguardando pods do Redis Cluster ficarem prontos..."
    kubectl wait --for=condition=ready --timeout=300s pod -l app=redis-cluster -n default
    
    echo "Inicializando cluster..."
    
    # Obter os IPs dos pods
    echo "Obtendo informações dos pods..."
    PODS=$(kubectl get pods -l app=redis-cluster -n default -o jsonpath='{.items[*].metadata.name}')
    
    # Criar comando de inicialização do cluster
    CLUSTER_CMD="redis-cli --cluster create"
    for pod in $PODS; do
        IP=$(kubectl get pod "$pod" -n default -o jsonpath='{.status.podIP}')
        CLUSTER_CMD="$CLUSTER_CMD $IP:6379"
    done
    CLUSTER_CMD="$CLUSTER_CMD --cluster-replicas 1 --cluster-yes"
    
    echo "Executando comando de criação do cluster:"
    echo "$CLUSTER_CMD"
    
    # Executar comando no primeiro pod
    FIRST_POD=$(echo "$PODS" | awk '{print $1}')
    kubectl exec -it "$FIRST_POD" -n default -- sh -c "$CLUSTER_CMD"
    
    echo "Verificando status do cluster..."
    kubectl exec -it "$FIRST_POD" -n default -- redis-cli cluster info
    kubectl exec -it "$FIRST_POD" -n default -- redis-cli cluster nodes
    
    echo "✓ Redis Cluster configurado com sucesso!"
}

# Função para testar Redis
 test_redis() {
    echo "=== Testando Redis ==="
    
    if kubectl get deployment redis-master &> /dev/null; then
        echo "Testando Redis Sentinel..."
        
        # Testar escrita no master
        kubectl exec -it deployment/redis-master -- redis-cli set test-key "Hello from Redis Sentinel"
        
        # Testar leitura do slave
        kubectl exec -it deployment/redis-slave -- redis-cli get test-key
        
        # Testar sentinel
        kubectl exec -it deployment/redis-sentinel -- redis-cli -p 26379 sentinel get-master-addr-by-name mymaster
        
        echo "✓ Redis Sentinel testado com sucesso!"
    fi
    
    if kubectl get statefulset redis-cluster &> /dev/null; then
        echo "Testando Redis Cluster..."
        
        # Obter um pod do cluster
        CLUSTER_POD=$(kubectl get pods -l app=redis-cluster -n default -o jsonpath='{.items[0].metadata.name}')
        
        # Testar escrita e leitura no cluster
        kubectl exec -it "$CLUSTER_POD" -n default -- redis-cli -c set cluster-key "Hello from Redis Cluster"
        kubectl exec -it "$CLUSTER_POD" -n default -- redis-cli -c get cluster-key
        
        # Verificar slots
        kubectl exec -it "$CLUSTER_POD" -n default -- redis-cli cluster slots
        
        echo "✓ Redis Cluster testado com sucesso!"
    fi
}

# Função para verificar status
check_status() {
    echo "=== Verificando Status do Redis ==="
    
    echo "Pods Redis:"
    kubectl get pods -l app=redis -n default
    
    echo ""
    echo "Pods Redis Cluster:"
    kubectl get pods -l app=redis-cluster -n default
    
    echo ""
    echo "Services:"
    kubectl get svc -l app=redis -n default
    
    echo ""
    echo "Services Redis Cluster:"
    kubectl get svc -l app=redis-cluster -n default
}

# Função para limpar recursos
cleanup() {
    echo "=== Limpando Recursos Redis ==="
    
    read -p "Tem certeza que deseja remover todos os recursos Redis? (s/N): " confirm
    if [[ $confirm =~ ^[Ss]$ ]]; then
        kubectl delete -f applications/redis-ha/ --ignore-not-found=true
        echo "Recursos Redis removidos com sucesso!"
    else
        echo "Operação cancelada."
    fi
}

# Menu principal
show_menu() {
    echo ""
    echo "=== Configuração Redis High Availability ==="
    echo "1. Configurar Redis Sentinel"
    echo "2. Configurar Redis Cluster"
    echo "3. Testar Redis"
    echo "4. Verificar Status"
    echo "5. Limpar Recursos"
    echo "6. Sair"
    echo ""
}

# Loop principal
while true; do
    show_menu
    read -p "Escolha uma opção: " choice
    
    case $choice in
        1)
            setup_sentinel
            ;;
        2)
            setup_cluster
            ;;
        3)
            test_redis
            ;;
        4)
            check_status
            ;;
        5)
            cleanup
            ;;
        6)
            echo "Saindo..."
            exit 0
            ;;
        *)
            echo "Opção inválida. Por favor, tente novamente."
            ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
done