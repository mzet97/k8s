# Como Testar Redis Usando Domínio

Este guia mostra como configurar e testar o Redis usando domínios ao invés de IPs.

---

## 📋 Domínios Redis Conforme DNS-STANDARDS.md

Segundo o padrão do projeto, o Redis usa:

| Tipo | Domínio | Uso |
|------|---------|-----|
| **TCP (Redis)** | `redis.home.arpa` | Acesso direto ao Redis (porta 6379/6380) |
| **HTTP (Stats)** | `redis-stats.home.arpa` | Dashboard de estatísticas (via Ingress) |
| **Interno K8s** | `redis-master.redis.svc.cluster.local` | Acesso interno no cluster |

---

## 🌍 MÉTODO 1: Configurar /etc/hosts (Mais Simples)

### No Servidor K3s (k8s1)

```bash
# Obter IP do LoadBalancer
REDIS_IP=$(kubectl get svc redis-master-lb -n redis -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Adicionar ao /etc/hosts
echo "$REDIS_IP redis.home.arpa" | sudo tee -a /etc/hosts

# Verificar
cat /etc/hosts | grep redis
```

### No Outro Ubuntu (Cliente)

```bash
# Adicionar ao /etc/hosts (use o mesmo IP)
echo "192.168.1.51 redis.home.arpa" | sudo tee -a /etc/hosts

# Verificar
ping redis.home.arpa
```

### Testar com Domínio

```bash
# Teste ping
redis-cli -h redis.home.arpa -p 6379 -a Admin@123 ping

# Escrever/Ler dados
redis-cli -h redis.home.arpa -p 6379 -a Admin@123 SET teste-dominio "Usando domínio!"
redis-cli -h redis.home.arpa -p 6379 -a Admin@123 GET teste-dominio

# Com TLS
redis-cli --tls \
  --cert /tmp/tls.crt \
  --key /tmp/tls.key \
  --cacert /tmp/ca.crt \
  -h redis.home.arpa \
  -p 6380 \
  -a Admin@123 \
  ping
```

---

## 🔧 MÉTODO 2: DNS Server Local (Recomendado para Produção)

Se você tem um servidor DNS local (Pi-hole, dnsmasq, BIND9), configure lá:

### Pi-hole

```bash
# No servidor Pi-hole, editar:
sudo nano /etc/dnsmasq.d/02-homelab.conf

# Adicionar:
address=/redis.home.arpa/192.168.1.51
address=/redis-stats.home.arpa/192.168.1.51

# Reiniciar
sudo systemctl restart pihole-FTL
```

### dnsmasq

```bash
# Editar configuração
sudo nano /etc/dnsmasq.conf

# Adicionar:
address=/redis.home.arpa/192.168.1.51
address=/redis-stats.home.arpa/192.168.1.51

# Reiniciar
sudo systemctl restart dnsmasq
```

### BIND9

```bash
# Adicionar zona no arquivo de zona
redis.home.arpa.  IN  A  192.168.1.51
redis-stats.home.arpa.  IN  A  192.168.1.51

# Reiniciar
sudo systemctl restart named
```

---

## 🧪 MÉTODO 3: Script de Teste com Domínio

Criei um script que testa automaticamente usando domínio:

### No Servidor K3s

Execute para gerar o script de teste:

```bash
cd ~/k8s/redis
./generate-domain-test.sh
```

### Copiar para Outro Ubuntu

```bash
# Copiar script
scp ~/k8s/redis/test-redis-domain.sh usuario@outro-ubuntu:/tmp/

# No outro Ubuntu, executar:
cd /tmp
chmod +x test-redis-domain.sh
./test-redis-domain.sh
```

---

## 📝 Exemplo Completo - Passo a Passo

### Passo 1: Configurar DNS no Servidor K3s

```bash
# Como usuário k8s1
REDIS_IP=$(kubectl get svc redis-master-lb -n redis -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "$REDIS_IP redis.home.arpa" | sudo tee -a /etc/hosts
echo "$REDIS_IP redis-stats.home.arpa" | sudo tee -a /etc/hosts

# Testar localmente
ping -c 2 redis.home.arpa
redis-cli -h redis.home.arpa -p 6379 -a Admin@123 ping
```

### Passo 2: Configurar DNS no Cliente (Outro Ubuntu)

```bash
# No outro Ubuntu
echo "192.168.1.51 redis.home.arpa" | sudo tee -a /etc/hosts
echo "192.168.1.51 redis-stats.home.arpa" | sudo tee -a /etc/hosts

# Testar conectividade
ping -c 2 redis.home.arpa
```

### Passo 3: Testar Redis com Domínio

```bash
# Instalar redis-cli (se ainda não tem)
sudo apt install -y redis-tools

# Teste 1: Ping
redis-cli -h redis.home.arpa -p 6379 -a Admin@123 ping
# Esperado: PONG

# Teste 2: Escrever dados
redis-cli -h redis.home.arpa -p 6379 -a Admin@123 SET domain-test "Testing with domain $(date)"

# Teste 3: Ler dados
redis-cli -h redis.home.arpa -p 6379 -a Admin@123 GET domain-test

# Teste 4: Info do servidor
redis-cli -h redis.home.arpa -p 6379 -a Admin@123 INFO replication

# Teste 5: Benchmark
redis-benchmark -h redis.home.arpa -p 6379 -a Admin@123 -q -t set,get -n 1000
```

---

## 🔒 Teste com TLS Usando Domínio

### Requisitos

1. Certificados TLS exportados (veja `export-certificates.sh`)
2. Arquivos em `/tmp/` no cliente: `tls.crt`, `tls.key`, `ca.crt`

### Comandos

```bash
# Teste ping com TLS
redis-cli --tls \
  --cert /tmp/tls.crt \
  --key /tmp/tls.key \
  --cacert /tmp/ca.crt \
  -h redis.home.arpa \
  -p 6380 \
  -a Admin@123 \
  ping

# Escrever/Ler com TLS
redis-cli --tls \
  --cert /tmp/tls.crt \
  --key /tmp/tls.key \
  --cacert /tmp/ca.crt \
  -h redis.home.arpa \
  -p 6380 \
  -a Admin@123 \
  SET secure-domain "TLS com domínio"

redis-cli --tls \
  --cert /tmp/tls.crt \
  --key /tmp/tls.key \
  --cacert /tmp/ca.crt \
  -h redis.home.arpa \
  -p 6380 \
  -a Admin@123 \
  GET secure-domain
```

---

## 🐍 Python com Domínio

### Sem TLS

```python
#!/usr/bin/env python3
import redis

# Conectar usando domínio
r = redis.Redis(
    host='redis.home.arpa',
    port=6379,
    password='Admin@123',
    decode_responses=True
)

# Testar
print(f"Ping: {r.ping()}")
r.set('python-domain-test', 'Hello from domain!')
print(f"Get: {r.get('python-domain-test')}")

# Info
info = r.info('replication')
print(f"Role: {info['role']}")
print(f"Slaves: {info['connected_slaves']}")
```

### Com TLS

```python
#!/usr/bin/env python3
import redis

# Conectar usando domínio com TLS
r = redis.Redis(
    host='redis.home.arpa',
    port=6380,
    password='Admin@123',
    ssl=True,
    ssl_cert_reqs='required',
    ssl_ca_certs='/tmp/ca.crt',
    ssl_certfile='/tmp/tls.crt',
    ssl_keyfile='/tmp/tls.key',
    decode_responses=True
)

# Testar
print(f"Ping TLS: {r.ping()}")
r.set('python-tls-domain', 'Secure connection with domain!')
print(f"Get TLS: {r.get('python-tls-domain')}")
```

---

## 🔍 Verificar Resolução DNS

### Verificar se o domínio está resolvendo

```bash
# Método 1: ping
ping -c 2 redis.home.arpa

# Método 2: nslookup
nslookup redis.home.arpa

# Método 3: dig (mais detalhado)
dig redis.home.arpa

# Método 4: host
host redis.home.arpa
```

### Resolver para IP específico

```bash
# Verificar qual IP o domínio está resolvendo
getent hosts redis.home.arpa

# Deve retornar: 192.168.1.51 redis.home.arpa
```

---

## 🧪 Script de Teste Automático com Domínio

Salve como `test-redis-with-domain.sh`:

```bash
#!/bin/bash

# Configuração
REDIS_DOMAIN="${REDIS_DOMAIN:-redis.home.arpa}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-Admin@123}"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================="
echo "Teste Redis com Domínio"
echo -e "=========================================\n${NC}"

# Verificar redis-cli
if ! command -v redis-cli &> /dev/null; then
    echo -e "${RED}❌ redis-cli não encontrado${NC}"
    echo "Instale: sudo apt install -y redis-tools"
    exit 1
fi

# Teste 1: Resolução DNS
echo -e "${BLUE}🔍 Teste 1: Resolução DNS...${NC}"
DNS_IP=$(getent hosts $REDIS_DOMAIN | awk '{print $1}')
if [ ! -z "$DNS_IP" ]; then
    echo -e "${GREEN}✅ Domínio resolvido: $REDIS_DOMAIN → $DNS_IP${NC}"
else
    echo -e "${RED}❌ Domínio não resolve${NC}"
    echo "Configure /etc/hosts ou DNS local"
    exit 1
fi
echo ""

# Teste 2: Conectividade
echo -e "${BLUE}🔍 Teste 2: Conectividade de rede...${NC}"
if ping -c 2 -W 2 $REDIS_DOMAIN > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Host alcançável via ping${NC}"
else
    echo -e "${YELLOW}⚠️  Ping falhou (pode ser firewall)${NC}"
fi
echo ""

# Teste 3: Redis Ping
echo -e "${BLUE}🔍 Teste 3: Redis ping...${NC}"
if redis-cli -h $REDIS_DOMAIN -p $REDIS_PORT -a $REDIS_PASSWORD ping 2>/dev/null | grep -q "PONG"; then
    echo -e "${GREEN}✅ Redis respondeu PONG${NC}"
else
    echo -e "${RED}❌ Redis não respondeu${NC}"
    exit 1
fi
echo ""

# Teste 4: Escrever/Ler
echo -e "${BLUE}🔍 Teste 4: Escrever e ler dados...${NC}"
TEST_KEY="domain-test-$(date +%s)"
TEST_VALUE="Teste com domínio em $(date)"

redis-cli -h $REDIS_DOMAIN -p $REDIS_PORT -a $REDIS_PASSWORD SET "$TEST_KEY" "$TEST_VALUE" > /dev/null 2>&1
READ_VALUE=$(redis-cli -h $REDIS_DOMAIN -p $REDIS_PORT -a $REDIS_PASSWORD GET "$TEST_KEY" 2>/dev/null)

if [ "$READ_VALUE" == "$TEST_VALUE" ]; then
    echo -e "${GREEN}✅ Escrita/Leitura OK${NC}"
    echo "   Chave: $TEST_KEY"
else
    echo -e "${RED}❌ Erro na escrita/leitura${NC}"
fi
echo ""

# Teste 5: Info servidor
echo -e "${BLUE}🔍 Teste 5: Info do servidor...${NC}"
INFO=$(redis-cli -h $REDIS_DOMAIN -p $REDIS_PORT -a $REDIS_PASSWORD INFO server 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Informações obtidas:${NC}"
    echo "$INFO" | grep "redis_version"
    echo "$INFO" | grep "os"
fi
echo ""

# Teste 6: Replicação
echo -e "${BLUE}🔍 Teste 6: Status de replicação...${NC}"
REPL=$(redis-cli -h $REDIS_DOMAIN -p $REDIS_PORT -a $REDIS_PASSWORD INFO replication 2>/dev/null)
echo "$REPL" | grep "role"
echo "$REPL" | grep "connected_slaves"
echo ""

# Limpeza
redis-cli -h $REDIS_DOMAIN -p $REDIS_PORT -a $REDIS_PASSWORD DEL "$TEST_KEY" > /dev/null 2>&1

echo -e "${BLUE}========================================="
echo -e "${GREEN}✅ Todos os testes concluídos!"
echo -e "${BLUE}=========================================\n${NC}"

echo "Configuração testada:"
echo "  Domínio: $REDIS_DOMAIN"
echo "  IP: $DNS_IP"
echo "  Porta: $REDIS_PORT"
echo ""
```

Execute:

```bash
chmod +x test-redis-with-domain.sh
./test-redis-with-domain.sh
```

---

## 🌐 Configuração de DNS em Roteador (Opcional)

Se você tem acesso administrativo ao seu roteador:

1. **Acesse o painel do roteador** (geralmente `192.168.1.1`)
2. **Vá em "DNS Estático"** ou "DNS Local"
3. **Adicione entrada**:
   - Nome: `redis.home.arpa`
   - IP: `192.168.1.51`
4. **Salvar e aplicar**

Agora todos os computadores na rede resolverão `redis.home.arpa` automaticamente!

---

## 📊 Comparação: IP vs Domínio

| Aspecto | IP (192.168.1.51) | Domínio (redis.home.arpa) |
|---------|-------------------|---------------------------|
| **Facilidade** | ✅ Imediato | ⚠️ Requer configuração DNS |
| **Manutenção** | ❌ Mudar IP = atualizar tudo | ✅ Mudar IP = atualizar só DNS |
| **Legibilidade** | ❌ Difícil lembrar | ✅ Fácil lembrar |
| **Profissional** | ❌ Não | ✅ Sim |
| **Padrão RFC 8375** | ❌ Não | ✅ Sim (.home.arpa) |

**Recomendação**: Use domínio para ambientes mais permanentes!

---

## 🚨 Troubleshooting

### Erro: "could not connect"

**Verificar resolução DNS**:
```bash
nslookup redis.home.arpa
# Deve retornar 192.168.1.51
```

**Se não resolver**:
```bash
# Verificar /etc/hosts
cat /etc/hosts | grep redis

# Se não está lá, adicionar
echo "192.168.1.51 redis.home.arpa" | sudo tee -a /etc/hosts
```

### Erro: "Name or service not known"

O domínio não está configurado. Opções:

1. Adicionar ao `/etc/hosts`
2. Configurar servidor DNS
3. Usar IP diretamente

### Certificado TLS não valida com domínio

O certificado TLS foi gerado para incluir o domínio. Verifique:

```bash
# Ver SANs do certificado
openssl x509 -in /tmp/tls.crt -noout -text | grep DNS
```

Deve incluir `redis.home.arpa` ou wildcards.

---

## 🎯 Resumo Rápido

**Configuração mais rápida**:

```bash
# 1. No servidor K3s e no cliente
echo "192.168.1.51 redis.home.arpa" | sudo tee -a /etc/hosts

# 2. Testar
redis-cli -h redis.home.arpa -p 6379 -a Admin@123 ping
```

**Pronto!** Agora você pode usar `redis.home.arpa` ao invés de IP! 🎉

---

## 📚 Referências

- **DNS Standards**: `~/k8s/DNS-STANDARDS.md`
- **Teste Externo**: `~/k8s/redis/TESTE_EXTERNO.md`
- **RFC 8375**: Special-Use Domain 'home.arpa'
