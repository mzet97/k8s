#!/bin/bash
# Script para exportar certificados TLS do Redis

set -e

CERT_DIR="$HOME/redis-certs"

echo "========================================="
echo "Exportando Certificados TLS do Redis"
echo "========================================="
echo ""

# Criar diretório
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# Exportar certificados
echo "📝 Exportando certificados..."
kubectl get secret redis-tls-secret -n redis -o jsonpath='{.data.tls\.crt}' | base64 -d > tls.crt
kubectl get secret redis-tls-secret -n redis -o jsonpath='{.data.tls\.key}' | base64 -d > tls.key
kubectl get secret redis-tls-secret -n redis -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt

# Ajustar permissões
chmod 644 tls.crt ca.crt
chmod 600 tls.key

# Verificar
echo ""
echo "✅ Certificados exportados em: $CERT_DIR"
echo ""
ls -lh "$CERT_DIR"
echo ""

# Obter senha
REDIS_PASSWORD=$(kubectl get secret redis-auth -n redis -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d)

echo "========================================="
echo "✅ Pronto para usar!"
echo "========================================="
echo ""
echo "📂 Certificados: $CERT_DIR"
echo "🔑 Senha Redis: $REDIS_PASSWORD"
echo ""
echo "🌍 Para copiar para outro computador:"
echo ""
echo "  scp $CERT_DIR/tls.crt usuario@outro-ubuntu:/tmp/"
echo "  scp $CERT_DIR/tls.key usuario@outro-ubuntu:/tmp/"
echo "  scp $CERT_DIR/ca.crt usuario@outro-ubuntu:/tmp/"
echo ""
echo "💡 Ou use o comando completo:"
echo ""
echo "  scp $CERT_DIR/*.{crt,key} usuario@outro-ubuntu:/tmp/"
echo ""
