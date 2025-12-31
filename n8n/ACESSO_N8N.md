# Guia de Acesso - n8n

Este documento detalha como acessar o n8n implantado no cluster.

## 1. Configuração de DNS

Para acessar via nome de domínio, adicione ao seu `/etc/hosts` ou servidor DNS local:

```bash
# Substitua 192.168.1.51 pelo IP do seu cluster se for diferente
echo '192.168.1.51 n8n.home.arpa' | sudo tee -a /etc/hosts
```

## 2. Acesso Web

- **URL:** [https://n8n.home.arpa](https://n8n.home.arpa)

> **Primeiro Acesso:** Ao acessar pela primeira vez, você verá a tela de "Setup owner account". Crie seu usuário e senha.

## 3. Webhooks

Seus webhooks terão o formato:
- `https://n8n.home.arpa/webhook/...`

Como configuramos a variável `WEBHOOK_URL`, o n8n já gerará as URLs corretas na interface.

## 4. Persistência

Os dados (banco SQLite, workflows salvos, credenciais) estão persistidos no PVC `n8n-data`. O pod pode ser reiniciado sem perda de dados.
