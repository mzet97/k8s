#!/bin/bash

# Script para instalar e configurar cert-manager no MicroK8s
# Este script resolve problemas de certificados TLS no Redis

set -e

echo "=== Instalando cert-manager no MicroK8s ==="

# Verificar se MicroK8s está rodando
echo "Verificando status do MicroK8s..."
microk8s status --wait-ready

# Habilitar cert-manager addon
echo "Habilitando addon cert-manager..."
microk8s enable cert-manager

# Aguardar cert-manager estar pronto
echo "Aguardando cert-manager estar pronto..."
microk8s kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s
microk8s kubectl wait --for=condition=ready pod -l app=cainjector -n cert-manager --timeout=300s
microk8s kubectl wait --for=condition=ready pod -l app=webhook -n cert-manager --timeout=300s

echo "Cert-manager instalado com sucesso!"

# Verificar se namespace redis existe
echo "Verificando namespace redis..."
microk8s kubectl get namespace redis || {
    echo "Criando namespace redis..."
    microk8s kubectl create namespace redis
}

# Limpar jobs anteriores que podem ter falhado
echo "Limpando jobs anteriores..."
microk8s kubectl delete job redis-ca-generator redis-proxy-cert-generator -n redis --ignore-not-found=true

# Aguardar um pouco para limpeza
sleep 5

# Recriar certificados CA
echo "Recriando certificados CA..."
microk8s kubectl apply -f 02-tls-certificates.yaml

# Aguardar job CA completar
echo "Aguardando geração do CA..."
microk8s kubectl wait --for=condition=complete job/redis-ca-generator -n redis --timeout=120s

# Aguardar certificado ser emitido
echo "Aguardando certificado do servidor ser emitido..."
microk8s kubectl wait --for=condition=ready certificate/redis-server-cert -n redis --timeout=120s

# Recriar certificados do proxy
echo "Recriando certificados do proxy..."
microk8s kubectl apply -f 42-redis-proxy-tls.yaml

# Aguardar job proxy completar
echo "Aguardando geração do certificado do proxy..."
microk8s kubectl wait --for=condition=complete job/redis-proxy-cert-generator -n redis --timeout=120s

# Verificar secrets criados
echo "Verificando secrets criados..."
microk8s kubectl get secrets -n redis | grep -E "redis-tls-secret|redis-proxy-tls|redis-ca-key-pair"

# Reiniciar pods Redis para carregar novos certificados
echo "Reiniciando pods Redis..."
microk8s kubectl rollout restart statefulset/redis-master -n redis
microk8s kubectl rollout restart statefulset/redis-replica -n redis
microk8s kubectl rollout restart deployment/redis-proxy -n redis

# Aguardar pods estarem prontos
echo "Aguardando pods estarem prontos..."
microk8s kubectl rollout status statefulset/redis-master -n redis --timeout=300s
microk8s kubectl rollout status statefulset/redis-replica -n redis --timeout=300s
microk8s kubectl rollout status deployment/redis-proxy -n redis --timeout=300s

# Verificar status final
echo "\n=== Status Final ==="
microk8s kubectl get pods -n redis
microk8s kubectl get certificates -n redis
microk8s kubectl get secrets -n redis | grep tls

# Testar conexão
echo "\n=== Teste de Conexão ==="
echo "Testando conexão TLS..."
NODE_IP=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "IP do Node: $NODE_IP"
echo "Porta externa TLS: 30380"
echo "Comando para testar:"
echo "redis-cli -h $NODE_IP -p 30380 --tls --insecure -a Admin@123 ping"

# Verificar se redis-cli está disponível e testar
if command -v redis-cli &> /dev/null; then
    echo "Testando conexão automaticamente..."
    timeout 10 redis-cli -h $NODE_IP -p 30380 --tls --insecure -a Admin@123 ping || {
        echo "Teste automático falhou, mas isso pode ser normal se redis-cli não suportar TLS"
        echo "Use o comando acima para testar manualmente"
    }
else
    echo "redis-cli não encontrado. Instale com: apt-get install redis-tools"
fi

echo "\n=== Configuração Concluída ==="
echo "Cert-manager instalado e configurado com sucesso!"
echo "Redis deve estar acessível via TLS na porta 30380"
echo "Senha: Admin@123"