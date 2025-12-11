#!/bin/bash
# Script de teste Redis para executar no CLIENTE (outro Ubuntu)
# Copie este script para o outro computador

# Configuração
REDIS_HOST="${REDIS_HOST:-192.168.1.51}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Teste Redis - Cliente Externo"
echo "========================================="
echo ""

# Verificar se redis-cli está instalado
if ! command -v redis-cli &> /dev/null; then
    echo -e "${RED}❌ redis-cli não encontrado${NC}"
    echo ""
    echo "Instale com:"
    echo "  sudo apt update && sudo apt install -y redis-tools"
    echo ""
    exit 1
fi

# Verificar se senha foi fornecida
if [ -z "$REDIS_PASSWORD" ]; then
    echo -e "${YELLOW}⚠️  Senha não fornecida via variável REDIS_PASSWORD${NC}"
    echo ""
    read -sp "Digite a senha do Redis: " REDIS_PASSWORD
    echo ""
    echo ""
fi

# Teste 1: Ping
echo "🔍 Teste 1: Ping..."
if redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD ping 2>/dev/null | grep -q "PONG"; then
    echo -e "${GREEN}✅ Conexão bem-sucedida! Redis respondeu PONG${NC}"
else
    echo -e "${RED}❌ Falha na conexão${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Verifique se o IP está correto: $REDIS_HOST"
    echo "  2. Teste conectividade: ping $REDIS_HOST"
    echo "  3. Verifique firewall: telnet $REDIS_HOST $REDIS_PORT"
    exit 1
fi
echo ""

# Teste 2: Escrever dados
echo "🔍 Teste 2: Escrever dados..."
TEST_KEY="test-external-$(date +%s)"
TEST_VALUE="Hello from $(hostname) at $(date)"

if redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD SET "$TEST_KEY" "$TEST_VALUE" 2>/dev/null | grep -q "OK"; then
    echo -e "${GREEN}✅ Dados escritos com sucesso${NC}"
else
    echo -e "${RED}❌ Erro ao escrever dados${NC}"
    exit 1
fi
echo ""

# Teste 3: Ler dados
echo "🔍 Teste 3: Ler dados..."
READ_VALUE=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD GET "$TEST_KEY" 2>/dev/null)

if [ "$READ_VALUE" == "$TEST_VALUE" ]; then
    echo -e "${GREEN}✅ Dados lidos corretamente${NC}"
    echo "   Valor: $READ_VALUE"
else
    echo -e "${RED}❌ Erro ao ler dados${NC}"
    exit 1
fi
echo ""

# Teste 4: Info do servidor
echo "🔍 Teste 4: Informações do servidor..."
INFO=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD INFO server 2>/dev/null)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Informações obtidas:${NC}"
    echo "$INFO" | grep "redis_version"
    echo "$INFO" | grep "os"
    echo "$INFO" | grep "uptime_in_days"
else
    echo -e "${RED}❌ Erro ao obter informações${NC}"
fi
echo ""

# Teste 5: Replication info
echo "🔍 Teste 5: Status de replicação..."
REPL_INFO=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD INFO replication 2>/dev/null)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Informações de replicação:${NC}"
    echo "$REPL_INFO" | grep "role"
    echo "$REPL_INFO" | grep "connected_slaves"
else
    echo -e "${YELLOW}⚠️  Não foi possível obter info de replicação${NC}"
fi
echo ""

# Teste 6: Benchmark rápido
echo "🔍 Teste 6: Benchmark rápido (1000 requests)..."
echo ""
redis-benchmark -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD -q -t set,get -n 1000 2>/dev/null
echo ""

# Limpeza
echo "🧹 Limpando dados de teste..."
redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD DEL "$TEST_KEY" > /dev/null 2>&1

echo ""
echo "========================================="
echo -e "${GREEN}✅ Todos os testes concluídos com sucesso!${NC}"
echo "========================================="
echo ""
echo "Configuração testada:"
echo "  Host: $REDIS_HOST"
echo "  Porta: $REDIS_PORT"
echo "  TLS: Não (usar porta 6380 para TLS)"
echo ""
echo "Para teste com TLS, use o script test-redis-tls.sh"
echo ""
