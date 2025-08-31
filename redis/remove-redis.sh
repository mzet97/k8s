#!/bin/bash

# Script de Remoção do Redis Master-Replica no Kubernetes
# Baseado na documentação do README.md
# Executa os comandos na ordem reversa para remoção completa

set -e  # Parar execução em caso de erro

echo "🗑️ Iniciando remoção do Redis Master-Replica no Kubernetes..."
echo ""

# Verificar se microk8s está disponível
if ! command -v microk8s &> /dev/null; then
    echo "❌ Erro: microk8s não encontrado."
    exit 1
fi

# Verificar se o namespace redis existe
if ! microk8s kubectl get namespace redis &> /dev/null; then
    echo "⚠️ Namespace 'redis' não encontrado. Nada para remover."
    exit 0
fi

echo "📋 Namespace 'redis' encontrado. Iniciando remoção..."
echo ""

# Mostrar recursos atuais antes da remoção
echo "📊 Recursos atuais no namespace redis:"
microk8s kubectl -n redis get all
echo ""

# Confirmar remoção
read -p "⚠️ Tem certeza que deseja remover TODOS os recursos do Redis? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Remoção cancelada pelo usuário."
    exit 0
fi

echo "🚀 Iniciando remoção dos recursos (ordem reversa)..."
echo ""

# Remover todos os recursos (ordem reversa da instalação)
echo "1️⃣ Removendo alta disponibilidade..."
if microk8s kubectl get -f 70-high-availability.yaml &> /dev/null; then
    microk8s kubectl delete -f 70-high-availability.yaml
    echo "✅ Alta disponibilidade removida"
else
    echo "⚠️ Arquivo 70-high-availability.yaml não encontrado ou já removido"
fi
echo ""

echo "2️⃣ Removendo monitoramento..."
if microk8s kubectl get -f 60-monitoring.yaml &> /dev/null; then
    microk8s kubectl delete -f 60-monitoring.yaml
    echo "✅ Monitoramento removido"
else
    echo "⚠️ Arquivo 60-monitoring.yaml não encontrado ou já removido"
fi
echo ""

echo "3️⃣ Removendo backup..."
if microk8s kubectl get -f 50-backup-cronjob.yaml &> /dev/null; then
    microk8s kubectl delete -f 50-backup-cronjob.yaml
    echo "✅ Backup removido"
else
    echo "⚠️ Arquivo 50-backup-cronjob.yaml não encontrado ou já removido"
fi
echo ""

echo "4️⃣ Removendo configuração DNS..."
if microk8s kubectl get -f 43-dns-config.yaml &> /dev/null; then
    microk8s kubectl delete -f 43-dns-config.yaml
    echo "✅ Configuração DNS removida"
else
    echo "⚠️ Arquivo 43-dns-config.yaml não encontrado ou já removido"
fi
echo ""

echo "5️⃣ Removendo proxy Redis..."
if microk8s kubectl get -f 42-redis-proxy-tls.yaml &> /dev/null; then
    microk8s kubectl delete -f 42-redis-proxy-tls.yaml
    echo "✅ Proxy Redis removido"
else
    echo "⚠️ Arquivo 42-redis-proxy-tls.yaml não encontrado ou já removido"
fi
echo ""

echo "6️⃣ Removendo job de configuração de replicação..."
if microk8s kubectl get -f 31-replication-setup-job.yaml &> /dev/null; then
    microk8s kubectl delete -f 31-replication-setup-job.yaml
    echo "✅ Job de replicação removido"
else
    echo "⚠️ Arquivo 31-replication-setup-job.yaml não encontrado ou já removido"
fi
echo ""

echo "7️⃣ Removendo StatefulSets Redis..."
if microk8s kubectl get -f 22-replica-statefulset.yaml &> /dev/null; then
    microk8s kubectl delete -f 22-replica-statefulset.yaml
    echo "✅ StatefulSet das réplicas removido"
else
    echo "⚠️ Arquivo 22-replica-statefulset.yaml não encontrado ou já removido"
fi

if microk8s kubectl get -f 21-master-statefulset.yaml &> /dev/null; then
    microk8s kubectl delete -f 21-master-statefulset.yaml
    echo "✅ StatefulSet do master removido"
else
    echo "⚠️ Arquivo 21-master-statefulset.yaml não encontrado ou já removido"
fi
echo ""

# Aguardar pods serem terminados
echo "⏳ Aguardando pods serem terminados..."
sleep 15
echo ""

echo "8️⃣ Removendo Services..."
if microk8s kubectl get -f 13-master-svc.yaml &> /dev/null; then
    microk8s kubectl delete -f 13-master-svc.yaml
    echo "✅ Service do master removido"
else
    echo "⚠️ Arquivo 13-master-svc.yaml não encontrado ou já removido"
fi

if microk8s kubectl get -f 12-client-svc.yaml &> /dev/null; then
    microk8s kubectl delete -f 12-client-svc.yaml
    echo "✅ Service do cliente removido"
else
    echo "⚠️ Arquivo 12-client-svc.yaml não encontrado ou já removido"
fi

if microk8s kubectl get -f 11-headless-svc.yaml &> /dev/null; then
    microk8s kubectl delete -f 11-headless-svc.yaml
    echo "✅ Service headless removido"
else
    echo "⚠️ Arquivo 11-headless-svc.yaml não encontrado ou já removido"
fi
echo ""

echo "9️⃣ Removendo ConfigMaps..."
if microk8s kubectl get -f 10-configmap.yaml &> /dev/null; then
    microk8s kubectl delete -f 10-configmap.yaml
    echo "✅ ConfigMaps removidos"
else
    echo "⚠️ Arquivo 10-configmap.yaml não encontrado ou já removido"
fi
echo ""

echo "🔟 Removendo certificados TLS..."
if microk8s kubectl get -f 02-tls-certificates.yaml &> /dev/null; then
    microk8s kubectl delete -f 02-tls-certificates.yaml
    echo "✅ Certificados TLS removidos"
else
    echo "⚠️ Arquivo 02-tls-certificates.yaml não encontrado ou já removido"
fi
echo ""

echo "1️⃣1️⃣ Removendo RBAC..."
if microk8s kubectl get -f 03-rbac.yaml &> /dev/null; then
    microk8s kubectl delete -f 03-rbac.yaml
    echo "✅ RBAC removido"
else
    echo "⚠️ Arquivo 03-rbac.yaml não encontrado ou já removido"
fi
echo ""

echo "1️⃣2️⃣ Removendo secrets..."
if microk8s kubectl get -f 01-secret.yaml &> /dev/null; then
    microk8s kubectl delete -f 01-secret.yaml
    echo "✅ Secrets removidos"
else
    echo "⚠️ Arquivo 01-secret.yaml não encontrado ou já removido"
fi
echo ""

# Verificar se ainda há recursos no namespace
echo "🔍 Verificando recursos restantes..."
REMAINING=$(microk8s kubectl -n redis get all --no-headers 2>/dev/null | wc -l)
if [ "$REMAINING" -gt 0 ]; then
    echo "⚠️ Ainda existem $REMAINING recursos no namespace:"
    microk8s kubectl -n redis get all
    echo ""
    read -p "🗑️ Deseja remover o namespace completo (remove TUDO)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️ Removendo namespace completo..."
        microk8s kubectl delete namespace redis
        echo "✅ Namespace redis removido completamente"
    else
        echo "⚠️ Namespace mantido com recursos restantes"
    fi
else
    echo "1️⃣3️⃣ Removendo namespace..."
    microk8s kubectl delete -f 00-namespace.yaml
    echo "✅ Namespace removido"
fi
echo ""

# Verificação final
echo "🔍 Verificação final..."
if microk8s kubectl get namespace redis &> /dev/null; then
    echo "⚠️ Namespace 'redis' ainda existe com alguns recursos"
    microk8s kubectl -n redis get all 2>/dev/null || echo "Namespace vazio"
else
    echo "✅ Namespace 'redis' removido completamente"
fi
echo ""

echo "🎉 Remoção concluída!"
echo ""
echo "📋 Limpeza adicional recomendada:"
echo "1. Remover entradas DNS do arquivo hosts:"
echo "   - redis.home.arpa"
echo "   - redis-proxy.home.arpa"
echo ""
echo "2. Verificar se não há PersistentVolumes órfãos:"
echo "   microk8s kubectl get pv"
echo ""
echo "📚 Consulte o README.md para reinstalação se necessário."