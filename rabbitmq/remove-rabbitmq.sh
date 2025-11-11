#!/bin/bash

# Script de Remoção do RabbitMQ no Kubernetes
# Alinhado ao padrão do script do Redis
# Remove os recursos na ordem reversa

set -e  # Parar execução em caso de erro

# Flag opcional --force para remover sem confirmação
FORCE=false
if [[ "$1" == "--force" ]]; then
    FORCE=true
fi

echo "🗑️ Iniciando remoção do RabbitMQ no Kubernetes..."
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
    exit 1
fi
echo "ℹ️ Usando cliente Kubernetes: $KUBECTL_BIN"

# Verificar se o namespace existe
if ! $KUBECTL_BIN get namespace rabbitmq &> /dev/null; then
    echo "⚠️ Namespace 'rabbitmq' não encontrado. Nada para remover."
    exit 0
fi

echo "📋 Namespace 'rabbitmq' encontrado. Iniciando remoção..."
echo ""

# Mostrar recursos atuais antes da remoção
echo "📊 Recursos atuais no namespace rabbitmq:"
$KUBECTL_BIN -n rabbitmq get all
echo ""

# Confirmar remoção
if [[ "$FORCE" != true ]]; then
  read -p "⚠️ Tem certeza que deseja remover TODOS os recursos do RabbitMQ? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "❌ Remoção cancelada pelo usuário."
      exit 0
  fi
else
  echo "⚙️ Remoção forçada (--force) habilitada, pulando confirmação."
fi

echo "🚀 Removendo recursos (ordem reversa)..."
echo ""

# Remover Ingress e monitoramento
echo "1️⃣ Removendo Ingress e monitoramento..."
$KUBECTL_BIN delete -f 30-management-ingress.yaml --ignore-not-found=true
$KUBECTL_BIN delete -f 31-amqp-ingress.yaml --ignore-not-found=true
$KUBECTL_BIN delete -f 61-prometheus-rules.yaml --ignore-not-found=true
$KUBECTL_BIN delete -f 60-monitoring.yaml --ignore-not-found=true
echo "✅ Ingress e monitoramento removidos"
echo ""

# Remover NetworkPolicy
echo "2️⃣ Removendo NetworkPolicy..."
$KUBECTL_BIN delete -f 40-network-policy.yaml --ignore-not-found=true
echo "✅ NetworkPolicy removida"
echo ""

# Remover StatefulSet
echo "3️⃣ Removendo StatefulSet do RabbitMQ..."
$KUBECTL_BIN delete -f 20-statefulset.yaml --ignore-not-found=true
echo "✅ StatefulSet removido"
echo ""

# Aguardar pods serem terminados
echo "⏳ Aguardando pods serem terminados..."
sleep 15
echo ""

# Remover Services
echo "4️⃣ Removendo Services..."
$KUBECTL_BIN delete -f 14-nodeport-svc.yaml --ignore-not-found=true
$KUBECTL_BIN delete -f 13-management-svc.yaml --ignore-not-found=true
$KUBECTL_BIN delete -f 12-client-svc.yaml --ignore-not-found=true
$KUBECTL_BIN delete -f 11-headless-svc.yaml --ignore-not-found=true
echo "✅ Services removidos"
echo ""

# Remover ConfigMap
echo "5️⃣ Removendo ConfigMap..."
$KUBECTL_BIN delete -f 10-configmap.yaml --ignore-not-found=true
echo "✅ ConfigMap removido"
echo ""

# Remover TLS
echo "6️⃣ Removendo certificados TLS..."
$KUBECTL_BIN delete -f 02-tls-certificates.yaml --ignore-not-found=true
echo "✅ Certificados TLS removidos"
echo ""

# Remover RBAC e secrets
echo "7️⃣ Removendo RBAC e secrets..."
$KUBECTL_BIN delete -f 03-rbac.yaml --ignore-not-found=true
$KUBECTL_BIN delete -f 01-secret.yaml --ignore-not-found=true
echo "✅ RBAC e secrets removidos"
echo ""

# Remover recursos opcionais não aplicados no fluxo básico
echo "🧹 Removendo recursos opcionais (se existirem)..."
for f in 41-pod-disruption-budget.yaml 42-horizontal-pod-autoscaler.yaml 43-vertical-pod-autoscaler.yaml 50-federation-config.yaml 51-disaster-recovery-config.yaml 52-cluster-crd.yaml 53-performance-tuning.yaml 54-persistent-volumes.yaml 55-backup-automation.yaml 56-environment-config.yaml; do
  $KUBECTL_BIN delete -f "$f" --ignore-not-found=true || true
done
echo "✅ Recursos opcionais removidos (quando presentes)"
echo ""

# Verificar recursos restantes
echo "🔍 Verificando recursos restantes..."
REMAINING=$($KUBECTL_BIN -n rabbitmq get all --no-headers 2>/dev/null | wc -l)
if [ "$REMAINING" -gt 0 ]; then
    echo "⚠️ Ainda existem $REMAINING recursos no namespace:"
    $KUBECTL_BIN -n rabbitmq get all
    echo ""
    read -p "🗑️ Deseja remover o namespace completo (remove TUDO)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️ Removendo namespace completo..."
        $KUBECTL_BIN delete namespace rabbitmq
        echo "✅ Namespace rabbitmq removido completamente"
    else
        echo "⚠️ Namespace mantido com recursos restantes"
        read -p "🧹 Deseja remover os PVCs do namespace 'rabbitmq'? (y/N): " -n 1 -r REPLY2
        echo
        if [[ $REPLY2 =~ ^[Yy]$ ]]; then
            $KUBECTL_BIN -n rabbitmq delete pvc --all
            echo "✅ PVCs removidos"
        fi
    fi
else
    echo "8️⃣ Removendo namespace..."
    $KUBECTL_BIN delete -f 00-namespace.yaml
    echo "✅ Namespace removido"
fi
echo ""

# Verificação final
echo "🔍 Verificação final..."
if $KUBECTL_BIN get namespace rabbitmq &> /dev/null; then
    echo "⚠️ Namespace 'rabbitmq' ainda existe com alguns recursos"
    $KUBECTL_BIN -n rabbitmq get all 2>/dev/null || echo "Namespace vazio"
else
    echo "✅ Namespace 'rabbitmq' removido completamente"
fi
echo ""

echo "🎉 Remoção concluída!"
echo ""
echo "📋 Limpeza adicional recomendada:"
echo "1. Remover entradas DNS locais, se criadas (hosts):"
echo "   - rabbitmq.home.arpa"
echo "   - rabbitmq-mgmt.home.arpa"
echo ""
echo "2. Verificar se não há PersistentVolumes órfãos:"
echo "$KUBECTL_BIN get pv"
echo ""
echo "📚 Consulte o README.md para reinstalação se necessário."