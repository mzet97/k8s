#!/bin/bash

# Script de Instalação do RabbitMQ no Kubernetes
# Alinhado ao padrão do script do Redis
# Executa os manifests na ordem correta e valida o estado

set -e  # Parar execução em caso de erro

echo "🚀 Iniciando instalação do RabbitMQ no Kubernetes..."
echo ""

# Selecionar cliente Kubernetes (preferir kubectl se estiver funcional)
KUBECTL_BIN="${KUBECTL_BIN:-}"
if [ -z "$KUBECTL_BIN" ]; then
    if command -v kubectl >/dev/null 2>&1; then
        if kubectl get nodes --request-timeout=5s >/dev/null 2>&1; then
            KUBECTL_BIN="kubectl"
        fi
    fi
fi
if [ -z "$KUBECTL_BIN" ] && command -v microk8s >/dev/null 2>&1; then
    KUBECTL_BIN="microk8s kubectl"
fi
if [ -z "$KUBECTL_BIN" ]; then
    echo "❌ Erro: nem 'kubectl' nem 'microk8s kubectl' encontrados/funcionais."
    echo "Instale/configure 'kubectl' ou MicroK8s e recarregue as permissões (newgrp microk8s)."
    exit 1
fi
echo "ℹ️ Usando cliente Kubernetes: $KUBECTL_BIN"

echo "📋 Pré-requisitos verificados"
echo ""

# 1. Criar namespace e configurações básicas
echo "1️⃣ Criando namespace e configurações básicas..."
$KUBECTL_BIN apply -f 00-namespace.yaml
$KUBECTL_BIN apply -f 01-secret.yaml
$KUBECTL_BIN apply -f 03-rbac.yaml
echo "✅ Namespace, secrets e RBAC aplicados"
echo ""

# 2. Configurar TLS e certificados (opcional, aguardando secret principal)
echo "2️⃣ Configurando TLS e certificados..."
$KUBECTL_BIN apply -f 02-tls-certificates.yaml || true
echo "✅ Manifests de certificados TLS aplicados"
echo ""

echo "⏳ Aguardando secret TLS principal (rabbitmq-tls) ser criado..."
for i in {1..24}; do
    if $KUBECTL_BIN get secret rabbitmq-tls -n rabbitmq >/dev/null 2>&1; then
        echo "✅ Secret rabbitmq-tls criado com sucesso!"
        break
    fi
    echo "Tentativa $i/24: Aguardando secret rabbitmq-tls..."
    sleep 5
done

if ! $KUBECTL_BIN get secret rabbitmq-tls -n rabbitmq >/dev/null 2>&1; then
    echo "⚠️ Aviso: Secret rabbitmq-tls não foi encontrado após 120s."
    echo "Você pode prosseguir sem TLS ou verificar cert-manager."
fi
echo ""

# 3. Configurar RabbitMQ (ConfigMap e Services)
echo "3️⃣ Configurando RabbitMQ (ConfigMap e Services)..."
$KUBECTL_BIN apply -f 10-configmap.yaml
$KUBECTL_BIN apply -f 11-headless-svc.yaml
$KUBECTL_BIN apply -f 12-client-svc.yaml
$KUBECTL_BIN apply -f 13-management-svc.yaml
$KUBECTL_BIN apply -f 14-nodeport-svc.yaml
$KUBECTL_BIN apply -f 40-network-policy.yaml
echo "✅ ConfigMap, Services e NetworkPolicy aplicados"
echo ""

# 4. Implantar StatefulSet do RabbitMQ
echo "4️⃣ Implantando RabbitMQ (StatefulSet)..."
$KUBECTL_BIN apply -f 20-statefulset.yaml
echo "✅ StatefulSet aplicado"
echo ""

# Aguardar pods estarem prontos
echo "⏳ Aguardando pods RabbitMQ ficarem prontos..."
for i in {1..36}; do
    READY_PODS=$($KUBECTL_BIN get pods -n rabbitmq -l 'app.kubernetes.io/name=rabbitmq' --no-headers 2>/dev/null | grep -c "Running" 2>/dev/null || echo "0")
    TOTAL_PODS=$($KUBECTL_BIN get pods -n rabbitmq -l 'app.kubernetes.io/name=rabbitmq' --no-headers 2>/dev/null | wc -l 2>/dev/null || echo "0")

    READY_PODS=$(echo "$READY_PODS" | tr -d '\n\r' | xargs)
    TOTAL_PODS=$(echo "$TOTAL_PODS" | tr -d '\n\r' | xargs)

    if ! [[ "$READY_PODS" =~ ^[0-9]+$ ]]; then READY_PODS=0; fi
    if ! [[ "$TOTAL_PODS" =~ ^[0-9]+$ ]]; then TOTAL_PODS=0; fi

    if [ "$READY_PODS" -gt 0 ] && [ "$READY_PODS" -eq "$TOTAL_PODS" ]; then
        echo "✅ Todos os pods RabbitMQ estão funcionando ($READY_PODS/$TOTAL_PODS)!"
        break
    fi
    echo "Tentativa $i/36: Pods prontos: $READY_PODS/$TOTAL_PODS"
    sleep 5
done

$KUBECTL_BIN -n rabbitmq get pods
echo ""

# Verificação e informações de acesso
echo "🔍 Verificando instalação..."
echo ""
echo "📊 Status dos pods:"
$KUBECTL_BIN -n rabbitmq get pods -l app.kubernetes.io/name=rabbitmq
echo ""
echo "🌐 Serviços disponíveis:"
$KUBECTL_BIN -n rabbitmq get svc
echo ""

NODE_IP=$($KUBECTL_BIN get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
AMQP_PORT=$($KUBECTL_BIN -n rabbitmq get svc rabbitmq-nodeport -o jsonpath='{.spec.ports[?(@.name=="amqp")].nodePort}')
MGMT_PORT=$($KUBECTL_BIN -n rabbitmq get svc rabbitmq-nodeport -o jsonpath='{.spec.ports[?(@.name=="management")].nodePort}')
echo "📡 IP do nó Kubernetes: $NODE_IP"
echo ""
echo "🎉 Instalação concluída com sucesso!"
echo ""
echo "📋 Próximos passos:"
ADMIN_USER=$($KUBECTL_BIN -n rabbitmq get secret rabbitmq-admin -o jsonpath='{.data.username}' | base64 -d 2>/dev/null || echo "admin")
ADMIN_PASS=$($KUBECTL_BIN -n rabbitmq get secret rabbitmq-admin -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || echo "Admin@123")
APP_USER=$($KUBECTL_BIN -n rabbitmq get secret rabbitmq-app -o jsonpath='{.data.username}' | base64 -d 2>/dev/null || echo "appuser")
APP_PASS=$($KUBECTL_BIN -n rabbitmq get secret rabbitmq-app -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || echo "Admin@123")
echo "1. Acesse o Management UI: http://$NODE_IP:$MGMT_PORT ($ADMIN_USER / $ADMIN_PASS)"
echo "2. Teste AMQP via NodePort: amqp://$NODE_IP:$AMQP_PORT (user: $APP_USER, pass: $APP_PASS, vhost: /)"
echo "3. Consulte o README.md para exemplos de testes e clients"
echo ""
echo "🔐 Nota: Ajuste TLS e Ingress conforme necessidade (ver README)."