# Guia de Acesso e Uso - MongoDB

Este documento detalha como acessar e conectar ao MongoDB implantado no cluster Kubernetes.

## 1. Console Web (Mongo Express)

Interface gráfica para gerenciamento de bancos de dados, coleções e documentos.

- **URL:** [https://mongodb-console.home.arpa](https://mongodb-console.home.arpa)
- **Usuário:** `admin`
- **Senha:** `Admin@123`

> **Nota:** Se o DNS não estiver configurado, adicione ao seu `/etc/hosts`:
> `192.168.1.51 mongodb-console.home.arpa`

## 2. Acesso Interno (Aplicações no Cluster)

Para aplicações rodando dentro do mesmo cluster Kubernetes.

- **Host (Service):** `mongodb-client.mongodb.svc.cluster.local`
- **Porta:** `27017`
- **Usuário:** `admin`
- **Senha:** `Admin@123`

### Connection Strings

**Formato Padrão:**
```
mongodb://admin:Admin%40123@mongodb-client.mongodb.svc.cluster.local:27017/
```

> **⚠️ IMPORTANTE:** A senha `Admin@123` contém o caractere `@`. Em connection strings, ele **DEVE** ser codificado como `%40` para não quebrar a URL.

**Exemplo NodeJS:**
```javascript
const client = new MongoClient('mongodb://admin:Admin%40123@mongodb-client.mongodb.svc.cluster.local:27017/');
```

## 3. Acesso Externo (via DNS)

Configure seu DNS ou arquivo `/etc/hosts` para apontar `mongodb.home.arpa` para o IP do cluster (`192.168.1.51`).

- **Host:** `mongodb.home.arpa`
- **Porta:** `27017`
- **Connection String:**
  ```
  mongodb://admin:Admin%40123@mongodb.home.arpa:27017/?authSource=admin
  ```

> **Configuração de Hosts:**
> ```bash
> # Linux/Mac
> echo '192.168.1.51 mongodb.home.arpa' | sudo tee -a /etc/hosts
> ```

## 4. Testando a Conexão (CLI)

Para testar rapidamente se o banco está respondendo de dentro do cluster:

```bash
# Entrar no pod do MongoDB
kubectl exec -it mongodb-0 -n mongodb -- bash

# Conectar via CLI local (dentro do pod)
mongo -u admin -p 'Admin@123'
```

## 5. Resumo de Recursos

| Recurso | Nome Kubernetes | Descrição |
|---------|-----------------|-----------|
| **Service (Escrita/Leitura)** | `mongodb-client` | Service estável para conexões |
| **Service (Headless)** | `mongodb-headless` | Para descoberta de nós internos |
| **Secret** | `mongodb-creds` | Armazena usuário e senha |
| **Storage** | `data-mongodb-0` | PVC de 10Gi para persistência |
