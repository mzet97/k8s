# Guia de Acesso - NATS

Este documento detalha como acessar o NATS Server implantado no cluster.

## 1. Configuração de DNS

Para acessar via nome de domínio, adicione ao seu `/etc/hosts` ou servidor DNS local:

```bash
# Substitua 192.168.1.51 pelo IP do seu cluster se for diferente
echo '192.168.1.51 nats.home.arpa' | sudo tee -a /etc/hosts
echo '192.168.1.51 nats-monitor.home.arpa' | sudo tee -a /etc/hosts
```

## 2. Acesso ao Servidor (Clientes)

O servidor NATS está exposto via LoadBalancer na porta padrão **4222**.

- **URL:** `nats://nats.home.arpa:4222`
- **Usuário:** `admin`
- **Senha:** `Admin@123`

### Exemplo de conexão (NATS CLI)
```bash
nats context save local --server nats://nats.home.arpa:4222 --user admin --password Admin@123
nats pub teste "Ola NATS"
```

## 3. Monitoramento

O NATS expõe endpoints de monitoramento (varz, connz, routez, etc.) via HTTP.

- **URL:** [https://nats-monitor.home.arpa](https://nats-monitor.home.arpa)
- **Endpoints úteis:**
  - `/varz`: Variáveis gerais do servidor
  - `/connz`: Informações de conexões
  - `/jsz`: Informações do JetStream

## 4. JetStream

O JetStream está habilitado e configurado para persistência.

- **Store:** File
- **Diretório:** `/data` (Persistido no PVC `nats-data`)
- **Limites:** 1GB Memória / 5GB Arquivo
