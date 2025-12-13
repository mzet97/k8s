# Como Testar Redis de Outro Computador

Este guia mostra como testar o Redis instalado no K3s a partir de outro computador Ubuntu na mesma rede.

---

## 📋 Informações do Redis

### Endereços Disponíveis

| Tipo | IP | Porta | TLS | Descrição |
|------|-----|-------|-----|-----------|
| **LoadBalancer** | `192.168.1.51` | 6379 | ❌ Não | Conexão sem TLS |
| **LoadBalancer** | `192.168.1.51` | 6380 | ✅ Sim | Conexão com TLS |
| **NodePort** | `<node-ip>` | 30379 | ❌ Não | Conexão sem TLS |
| **NodePort** | `<node-ip>` | 30380 | ✅ Sim | Conexão com TLS |

### Obter Senha

No servidor K3s, execute:

```bash
kubectl get secret redis-auth -n redis -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d
echo
```

**Anote essa senha!** Você vai precisar dela.

---

## 🖥️ MÉTODO 1: Teste Rápido (Sem TLS) - Recomendado para Início

### Passo 1: Instalar redis-cli no Cliente

No **outro Ubuntu** (cliente), execute:

```bash
sudo apt update
sudo apt install -y redis-tools
```

### Passo 2: Testar Conexão Simples (Porta 6379)

```bash
# Substituir <SENHA> pela senha obtida acima
redis-cli -h 192.168.1.51 -p 6379 -a <SENHA> ping
```

**Resultado esperado**: `PONG`

### Passo 3: Testar Comandos Básicos

```bash
# Conectar interativamente
redis-cli -h 192.168.1.51 -p 6379 -a <SENHA>

# Dentro do redis-cli:
SET teste "Hello from outro Ubuntu"
GET teste
KEYS *
INFO replication
QUIT
```

### Exemplo Completo

```bash
# Substituir pela senha real
REDIS_PASSWORD="sua-senha-aqui"

# Teste ping
redis-cli -h 192.168.1.51 -p 6379 -a $REDIS_PASSWORD ping

# Criar e ler dados
redis-cli -h 192.168.1.51 -p 6379 -a $REDIS_PASSWORD SET mykey "teste-externo"
redis-cli -h 192.168.1.51 -p 6379 -a $REDIS_PASSWORD GET mykey

# Ver informações do servidor
redis-cli -h 192.168.1.51 -p 6379 -a $REDIS_PASSWORD INFO server
```

---

## 🔒 MÉTODO 2: Teste com TLS (Porta 6380) - Mais Seguro

### Passo 1: Exportar Certificados TLS do K3s

No **servidor K3s** (k8s1), execute este script:

```bash
#!/bin/bash
# Criar diretório para certificados
mkdir -p ~/redis-certs
cd ~/redis-certs

# Exportar certificados
kubectl get secret redis-tls-secret -n redis -o jsonpath='{.data.tls\.crt}' | base64 -d > tls.crt
kubectl get secret redis-tls-secret -n redis -o jsonpath='{.data.tls\.key}' | base64 -d > tls.key
kubectl get secret redis-tls-secret -n redis -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt

# Verificar
ls -lh tls.crt tls.key ca.crt

echo ""
echo "✅ Certificados exportados em ~/redis-certs/"
echo ""
echo "Agora copie esses arquivos para o outro Ubuntu:"
echo "  scp ~/redis-certs/*.crt outro-ubuntu:/tmp/"
echo "  scp ~/redis-certs/*.key outro-ubuntu:/tmp/"
```

### Passo 2: Copiar Certificados para o Cliente

**Opção A - Via SCP** (no servidor K3s):

```bash
# Substituir 'usuario' e 'outro-ubuntu' pelos valores corretos
scp ~/redis-certs/tls.crt usuario@outro-ubuntu:/tmp/
scp ~/redis-certs/tls.key usuario@outro-ubuntu:/tmp/
scp ~/redis-certs/ca.crt usuario@outro-ubuntu:/tmp/
```

**Opção B - Via Pen Drive ou Compartilhamento de Rede**

Copie os 3 arquivos de `~/redis-certs/` para o outro computador.

### Passo 3: Testar Conexão TLS (Porta 6380)

No **outro Ubuntu** (cliente):

```bash
# Testar com TLS
redis-cli --tls \
  --cert /tmp/tls.crt \
  --key /tmp/tls.key \
  --cacert /tmp/ca.crt \
  -h 192.168.1.51 \
  -p 6380 \
  -a <SENHA> \
  ping
```

**Resultado esperado**: `PONG`

### Exemplo Completo com TLS

```bash
# Variáveis
REDIS_HOST="192.168.1.51"
REDIS_PORT="6380"
REDIS_PASSWORD="sua-senha-aqui"
CERT_DIR="/tmp"

# Teste ping
redis-cli --tls \
  --cert $CERT_DIR/tls.crt \
  --key $CERT_DIR/tls.key \
  --cacert $CERT_DIR/ca.crt \
  -h $REDIS_HOST \
  -p $REDIS_PORT \
  -a $REDIS_PASSWORD \
  ping

# Criar e ler dados
redis-cli --tls \
  --cert $CERT_DIR/tls.crt \
  --key $CERT_DIR/tls.key \
  --cacert $CERT_DIR/ca.crt \
  -h $REDIS_HOST \
  -p $REDIS_PORT \
  -a $REDIS_PASSWORD \
  SET secure-key "dados-criptografados"

redis-cli --tls \
  --cert $CERT_DIR/tls.crt \
  --key $CERT_DIR/tls.key \
  --cacert $CERT_DIR/ca.crt \
  -h $REDIS_HOST \
  -p $REDIS_PORT \
  -a $REDIS_PASSWORD \
  GET secure-key
```

---

## 🐍 MÉTODO 3: Teste com Python

### Instalar Bibliotecas Python

No **outro Ubuntu**:

```bash
sudo apt install -y python3 python3-pip
pip3 install redis
```

### Script Python - Sem TLS

Crie o arquivo `test_redis.py`:

```python
#!/usr/bin/env python3
import redis

# Configuração
REDIS_HOST = '192.168.1.51'
REDIS_PORT = 6379
REDIS_PASSWORD = 'sua-senha-aqui'  # SUBSTITUA!

# Conectar
print(f"Conectando ao Redis em {REDIS_HOST}:{REDIS_PORT}...")
r = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    password=REDIS_PASSWORD,
    decode_responses=True
)

# Testar conexão
try:
    pong = r.ping()
    print(f"✅ Conexão bem-sucedida! Resposta: {pong}")

    # Escrever dados
    r.set('python-test', 'Hello from Python!')
    print("✅ Dados escritos")

    # Ler dados
    value = r.get('python-test')
    print(f"✅ Dados lidos: {value}")

    # Informações do servidor
    info = r.info('server')
    print(f"✅ Redis Version: {info['redis_version']}")

except Exception as e:
    print(f"❌ Erro: {e}")
```

Execute:

```bash
python3 test_redis.py
```

### Script Python - Com TLS

Crie o arquivo `test_redis_tls.py`:

```python
#!/usr/bin/env python3
import redis

# Configuração
REDIS_HOST = '192.168.1.51'
REDIS_PORT = 6380
REDIS_PASSWORD = 'sua-senha-aqui'  # SUBSTITUA!

# Conectar com TLS
print(f"Conectando ao Redis com TLS em {REDIS_HOST}:{REDIS_PORT}...")
r = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    password=REDIS_PASSWORD,
    ssl=True,
    ssl_cert_reqs='required',
    ssl_ca_certs='/tmp/ca.crt',
    ssl_certfile='/tmp/tls.crt',
    ssl_keyfile='/tmp/tls.key',
    decode_responses=True
)

# Testar
try:
    pong = r.ping()
    print(f"✅ Conexão TLS bem-sucedida! Resposta: {pong}")

    r.set('secure-python-test', 'Encrypted data from Python!')
    value = r.get('secure-python-test')
    print(f"✅ Dados: {value}")

except Exception as e:
    print(f"❌ Erro: {e}")
```

Execute:

```bash
python3 test_redis_tls.py
```

---

## 🧪 MÉTODO 4: Benchmark de Performance

### Testar Performance do Redis

```bash
# Sem TLS (mais rápido)
redis-benchmark -h 192.168.1.51 -p 6379 -a <SENHA> -q -t set,get

# Com TLS
redis-benchmark --tls \
  --cert /tmp/tls.crt \
  --key /tmp/tls.key \
  --cacert /tmp/ca.crt \
  -h 192.168.1.51 \
  -p 6380 \
  -a <SENHA> \
  -q -t set,get
```

---

## 🔍 Troubleshooting

### Erro: "Connection refused"

**Causas possíveis**:

1. **Firewall bloqueando**
   ```bash
   # No servidor K3s, verificar firewall
   sudo ufw status

   # Se necessário, liberar portas
   sudo ufw allow 6379/tcp
   sudo ufw allow 6380/tcp
   sudo ufw allow 30379/tcp
   sudo ufw allow 30380/tcp
   ```

2. **IP incorreto**
   ```bash
   # Verificar IP do LoadBalancer
   kubectl get svc redis-master-lb -n redis -o wide
   ```

3. **Redis não está rodando**
   ```bash
   # Verificar pods
   kubectl get pods -n redis
   ```

### Erro: "NOAUTH Authentication required"

**Causa**: Senha incorreta ou não fornecida

**Solução**: Certifique-se de usar a flag `-a <SENHA>` ou `--pass <SENHA>`

### Erro: "SSL certificate problem"

**Causa**: Certificados TLS incorretos ou não encontrados

**Solução**:
1. Verifique se os arquivos existem: `ls -lh /tmp/*.crt /tmp/*.key`
2. Verifique permissões: `chmod 644 /tmp/*.crt && chmod 600 /tmp/*.key`
3. Re-exporte os certificados do K3s

### Erro: "Connection timeout"

**Causa**: Rede não alcançável

**Soluções**:

1. **Testar conectividade de rede**
   ```bash
   ping 192.168.1.51
   telnet 192.168.1.51 6379
   ```

2. **Testar via NodePort** (alternativa)
   ```bash
   # Obter IP do node K3s
   NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

   # Testar via NodePort
   redis-cli -h $NODE_IP -p 30379 -a <SENHA> ping
   ```

---

## 📊 Scripts Úteis

### Script Completo de Teste

Salve como `test_redis_complete.sh` no **outro Ubuntu**:

```bash
#!/bin/bash

# Configuração
REDIS_HOST="192.168.1.51"
REDIS_PORT_NOTLS="6379"
REDIS_PORT_TLS="6380"
REDIS_PASSWORD="sua-senha-aqui"  # SUBSTITUA!

echo "========================================="
echo "Teste Completo do Redis Externo"
echo "========================================="
echo ""

# Teste 1: Ping sem TLS
echo "🔍 Teste 1: Conexão sem TLS (porta $REDIS_PORT_NOTLS)..."
if redis-cli -h $REDIS_HOST -p $REDIS_PORT_NOTLS -a $REDIS_PASSWORD ping > /dev/null 2>&1; then
    echo "✅ Conexão sem TLS: OK"
else
    echo "❌ Conexão sem TLS: FALHOU"
fi
echo ""

# Teste 2: Escrever e ler dados
echo "🔍 Teste 2: Escrever e ler dados..."
redis-cli -h $REDIS_HOST -p $REDIS_PORT_NOTLS -a $REDIS_PASSWORD SET test-key "teste-$(date +%s)" > /dev/null
VALUE=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT_NOTLS -a $REDIS_PASSWORD GET test-key)
if [ ! -z "$VALUE" ]; then
    echo "✅ Leitura/Escrita: OK (valor: $VALUE)"
else
    echo "❌ Leitura/Escrita: FALHOU"
fi
echo ""

# Teste 3: Info do servidor
echo "🔍 Teste 3: Informações do servidor..."
redis-cli -h $REDIS_HOST -p $REDIS_PORT_NOTLS -a $REDIS_PASSWORD INFO server | grep redis_version
echo ""

# Teste 4: Ping com TLS (se certificados disponíveis)
if [ -f /tmp/tls.crt ] && [ -f /tmp/tls.key ] && [ -f /tmp/ca.crt ]; then
    echo "🔍 Teste 4: Conexão com TLS (porta $REDIS_PORT_TLS)..."
    if redis-cli --tls --cert /tmp/tls.crt --key /tmp/tls.key --cacert /tmp/ca.crt \
       -h $REDIS_HOST -p $REDIS_PORT_TLS -a $REDIS_PASSWORD ping > /dev/null 2>&1; then
        echo "✅ Conexão com TLS: OK"
    else
        echo "❌ Conexão com TLS: FALHOU"
    fi
else
    echo "⚠️  Teste 4: Certificados TLS não encontrados em /tmp/"
    echo "   Para testar TLS, exporte os certificados do K3s primeiro"
fi

echo ""
echo "========================================="
echo "Testes concluídos!"
echo "========================================="
```

Execute:

```bash
chmod +x test_redis_complete.sh
./test_redis_complete.sh
```

---

## 🎯 Resumo Rápido

### Para teste rápido (sem TLS):

```bash
# 1. Instalar redis-cli
sudo apt install -y redis-tools

# 2. Obter senha do Redis no servidor K3s
kubectl get secret redis-auth -n redis -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d

# 3. Testar do outro Ubuntu
redis-cli -h 192.168.1.51 -p 6379 -a <SENHA> ping
```

### Para teste seguro (com TLS):

```bash
# 1. Exportar certificados no servidor K3s
kubectl get secret redis-tls-secret -n redis -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/tls.crt
kubectl get secret redis-tls-secret -n redis -o jsonpath='{.data.tls\.key}' | base64 -d > /tmp/tls.key
kubectl get secret redis-tls-secret -n redis -o jsonpath='{.data.ca\.crt}' | base64 -d > /tmp/ca.crt

# 2. Copiar para outro Ubuntu
scp /tmp/*.{crt,key} usuario@outro-ubuntu:/tmp/

# 3. Testar do outro Ubuntu
redis-cli --tls --cert /tmp/tls.crt --key /tmp/tls.key --cacert /tmp/ca.crt \
  -h 192.168.1.51 -p 6380 -a <SENHA> ping
```

---

**Boa sorte com os testes!** 🚀
