# 🚀 **MinIO - Object Storage**

## 📋 **Visão Geral**

Este diretório contém as configurações para deploy do MinIO no Kubernetes, fornecendo armazenamento de objetos compatível com S3.

## 🚀 **Componentes Incluídos**

- **MinIO Server**: Servidor de armazenamento de objetos
- **MinIO Console**: Interface web para administração
- **Certificados TLS**: Segurança com HTTPS
- **Ingress**: Acesso externo configurado
- **Volumes Persistentes**: Armazenamento durável

## 📦 **O que você terá após a instalação**

- ✅ **Armazenamento S3-compatible** completo
- ✅ **Interface web** para gerenciamento
- ✅ **API S3** para aplicações
- ✅ **Buckets** e políticas de acesso
- ✅ **Backup e versionamento** de objetos
- ✅ **Certificados TLS** automáticos

---

## 🛠️ **Instalação**

### **Pré-requisitos**
- Kubernetes cluster funcionando
- cert-manager instalado
- Ingress controller configurado
- Volumes persistentes disponíveis

```bash
microk8s enable ingress
microk8s enable cert-manager
microk8s enable hostpath-storage
```

### **Passo a passo:**

1. **Aplicar as configurações:**
   ```bash
   # Aplicar namespace
   kubectl apply -f 00-namespace.yaml
   
   # Aplicar todas as configurações
   kubectl apply -f .
   ```

2. **Verificar a instalação:**
   ```bash
   kubectl get pods -n minio
   kubectl get svc -n minio
   kubectl get ingress -n minio
   ```

3. **Verificar certificados:**
   ```bash
   kubectl get certificates -n minio
   ```

4. **Verificar volumes:**
   ```bash
   kubectl get pvc -n minio
   ```

---

## 🌐 **Acesso Web**

### **Configurar arquivo hosts**

Adicione estas linhas ao arquivo hosts do Windows (`C:\Windows\System32\drivers\etc\hosts`):

```
192.168.1.100  minio-console.home.arpa
192.168.1.100  minio-s3.home.arpa
```

### **URLs de Acesso**

**MinIO Console (Administração):**
- URL: `https://minio-console.home.arpa`
- 🔐 **Login**: minioadmin / minioadmin (altere após primeiro acesso)
- 🎛️ **Funcionalidades**: Gerenciamento de buckets, usuários, políticas

**MinIO S3 API:**
- URL: `https://minio-s3.home.arpa`
- 🔗 **Endpoint**: Para aplicações e clientes S3
- 📡 **Protocolos**: REST API compatível com Amazon S3

---

## 🎯 **Primeiros Passos no MinIO**

### **1. Acessar Console Web**
1. Acesse `https://minio-console.home.arpa`
2. Login: `minioadmin` / `minioadmin`
3. **IMPORTANTE**: Altere a senha padrão
4. Explore a interface de administração

### **2. Criar Primeiro Bucket**
1. Clique em "Buckets" → "Create Bucket"
2. Digite o nome do bucket (ex: `my-app-data`)
3. Configure políticas de acesso se necessário
4. Clique em "Create Bucket"

### **3. Upload de Arquivos**
1. Selecione o bucket criado
2. Clique em "Upload" → "Upload Files"
3. Selecione arquivos do seu computador
4. Monitore o progresso do upload

### **4. Configurar Acesso via API**
1. Vá em "Access Keys" → "Create Access Key"
2. Anote o Access Key e Secret Key
3. Use essas credenciais em suas aplicações
4. Configure endpoint: `https://minio-s3.home.arpa`

---

## 📁 **Arquivos Principais**

| Arquivo | Descrição | Quando usar |
|---------|-----------|-------------|
| `00-namespace.yaml` | Namespace do MinIO | Sempre primeiro |
| `20-minio-console-svc.yaml` | Service do Console | Para acesso interno |
| `21-minio-console-ingress.yaml` | Ingress do Console | Para acesso web |
| `22-minio-s3-ingress.yaml` | Ingress da API S3 | Para aplicações |
| `23-minio-console-certificate.yaml` | Certificado do Console | Para HTTPS |
| `24-minio-s3-certificate.yaml` | Certificado da API | Para HTTPS |

---

## 🔧 **Configuração Avançada**

### **Credenciais de Acesso**

Para alterar as credenciais padrão, crie um Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  namespace: minio
type: Opaque
data:
  MINIO_ROOT_USER: <base64-encoded-username>
  MINIO_ROOT_PASSWORD: <base64-encoded-password>
```

### **Configuração de Buckets via CLI**

Instale e configure o cliente `mc`:

```bash
# Instalar mc client
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Configurar alias
mc alias set myminio https://minio-s3.home.arpa minioadmin minioadmin

# Criar bucket
mc mb myminio/my-bucket

# Definir política pública
mc policy set public myminio/my-bucket

# Listar buckets
mc ls myminio
```

### **Políticas de Acesso**

Configure políticas IAM personalizadas:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::my-bucket/*"]
    }
  ]
}
```

---

## 🗑️ **Remoção**

### **Remover completamente:**
```bash
kubectl delete -f .
```

### **Remover configuração de hosts:**
Remova estas linhas do arquivo hosts:
- `minio-console.home.arpa`
- `minio-s3.home.arpa`

---

## ❓ **Perguntas Frequentes (FAQ)**

### **Q: O que é MinIO?**
**A:** MinIO é um servidor de armazenamento de objetos de alta performance, compatível com Amazon S3. Ideal para armazenar arquivos, backups, logs e dados não estruturados.

### **Q: Como usar com aplicações?**
**A:** Configure suas aplicações para usar o endpoint `https://minio-s3.home.arpa` com credenciais do MinIO.

### **Q: Suporta versionamento?**
**A:** Sim! MinIO suporta versionamento de objetos, retenção e lifecycle policies.

### **Q: Como fazer backup?**
**A:** Use `mc mirror` para sincronizar buckets ou configure replicação entre instâncias MinIO.

### **Q: É compatível com AWS S3?**
**A:** Sim! MinIO é 100% compatível com a API do Amazon S3.

### **Q: Como integrar com aplicações Python?**
**A:** Use a biblioteca `boto3` ou `minio-py` com endpoint personalizado.

### **Q: Posso usar com Docker?**
**A:** Sim! MinIO funciona perfeitamente em containers Docker e Kubernetes.

---

## 🚀 **Próximos Passos**

### **Para Iniciantes:**
- Explore a interface web do Console
- Crie seus primeiros buckets
- Teste upload/download de arquivos
- Configure políticas básicas de acesso

### **Para Desenvolvedores:**
- Integre com aplicações usando SDK S3
- Configure lifecycle policies
- Implemente versionamento
- Use event notifications
- Configure backup automático

### **Para Administradores:**
- Configure usuários e políticas IAM
- Implemente backup e replicação
- Configure monitoramento
- Otimize performance e storage
- Configure alta disponibilidade

---

## 🤝 **Suporte e Contribuições**

- 📖 **Documentação**: [MinIO Documentation](https://docs.min.io/)
- 🐛 **Issues**: Reporte problemas no repositório
- 💡 **Sugestões**: Contribua com melhorias
- 🛠️ **SDKs**: Disponível para Python, Java, Go, .NET, JavaScript

---

## 📊 **Informações Técnicas**

### 🏗️ **Arquitetura:**
- **MinIO Server**: Servidor de armazenamento distribuído
- **MinIO Console**: Interface web para administração
- **Volumes Persistentes**: Armazenamento durável no Kubernetes
- **Certificados TLS**: Segurança via cert-manager
- **Ingress**: Roteamento para Console e API S3
- **Load Balancer**: Distribuição de carga entre pods
- **IAM**: Sistema de identidade e políticas de acesso
- **Event Notifications**: Webhooks para eventos de bucket

### ⚙️ **Configurações padrão:**
- **Protocolo**: HTTPS com certificados automáticos
- **Retenção**: Configurável por bucket
- **Versionamento**: Habilitado por bucket
- **Backup**: Manual via mc client
- **Replicação**: Configurável entre instâncias
- **Armazenamento**: Volumes persistentes do Kubernetes
- **Compressão**: Automática para objetos elegíveis
- **Criptografia**: Server-side encryption disponível

### 📝 **Notas Técnicas:**
- Console acessível via `minio-console.home.arpa`
- API S3 acessível via `minio-s3.home.arpa`
- Certificados TLS automáticos via cert-manager
- Para alterar hostnames: edite arquivos de Ingress e Certificate
- Credenciais padrão: minioadmin/minioadmin (**ALTERE IMEDIATAMENTE!**)
- Suporte a erasure coding para redundância
- Compatible com ferramentas AWS CLI e SDKs