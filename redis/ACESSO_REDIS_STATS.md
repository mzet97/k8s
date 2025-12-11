# Como Acessar o Redis Stats (Redis Commander)

## ✅ Interface Web Instalada

O **Redis Commander** foi instalado com sucesso e está disponível em:

**URL**: https://redis-stats.home.arpa/

## 🔐 Credenciais de Acesso

Para acessar a interface web:
- **Usuário**: `admin`
- **Senha**: `Admin@123` (mesma senha do Redis)

## 📋 Informações da Instalação

| Item | Valor |
|------|-------|
| **URL Externa** | https://redis-stats.home.arpa/ |
| **Ingress IP** | 192.168.1.51 |
| **Namespace** | redis |
| **Pod** | redis-commander |
| **Service** | redis-commander:8081 |
| **TLS** | ✅ Sim (cert-manager local-ca) |

## 🌐 Configuração DNS

### Se já configurou no roteador:
✅ Você já apontou `*.home.arpa` para `192.168.1.51` no roteador
✅ Pode acessar diretamente: https://redis-stats.home.arpa/

### Se ainda não configurou localmente:

**Linux/Mac**:
```bash
echo "192.168.1.51 redis-stats.home.arpa" | sudo tee -a /etc/hosts
```

**Windows** (como Administrador):
```powershell
Add-Content C:\Windows\System32\drivers\etc\hosts "192.168.1.51 redis-stats.home.arpa"
```

## 🧪 Testar Acesso

### Método 1: Browser
1. Abra o navegador
2. Acesse: https://redis-stats.home.arpa/
3. Aceite o certificado autoassinado (é esperado)
4. Login: `admin` / `Admin@123`

### Método 2: curl
```bash
# Testar se o endpoint responde
curl -k https://redis-stats.home.arpa/

# Resultado esperado: HTML da página de login
```

### Método 3: Verificar DNS
```bash
# Verificar se o domínio resolve
nslookup redis-stats.home.arpa

# Ou
ping redis-stats.home.arpa
```

## 🎯 O que você pode fazer no Redis Commander

✅ **Visualizar todas as chaves** do Redis
✅ **Criar, editar e deletar** chaves
✅ **Buscar chaves** por padrão
✅ **Ver informações** do servidor Redis
✅ **Explorar diferentes bancos de dados** (DB 0-15)
✅ **Ver estatísticas** de memória e comandos
✅ **Monitorar comandos** em tempo real
✅ **Importar/Exportar** dados

## 📊 Recursos da Interface

### Página Principal
- Lista de todas as chaves no Redis
- Filtro e busca de chaves
- Organização por tipo (String, Hash, List, Set, ZSet)

### Informações do Servidor
- Versão do Redis
- Memória utilizada
- Número de clientes conectados
- Estatísticas de comandos
- Configurações do servidor

### Console CLI
- Execute comandos Redis diretamente da interface
- Histórico de comandos
- Autocompletar

## 🔧 Status do Serviço

Verificar se o Redis Commander está rodando:

```bash
# Como usuário k8s1
kubectl get pods -n redis -l app=redis-commander
kubectl get ingress -n redis redis-stats
```

Ver logs:
```bash
kubectl logs -n redis -l app=redis-commander -f
```

Reiniciar (se necessário):
```bash
kubectl rollout restart deployment/redis-commander -n redis
```

## 🚨 Troubleshooting

### Erro: "Página não encontrada" (404)
✅ **RESOLVIDO**: O Redis Commander foi instalado e está funcionando agora!

### Erro: "Connection refused"
**Causa**: DNS não configurado
**Solução**: Configure o /etc/hosts ou DNS do roteador

### Erro: "Certificate error"
**Causa**: Certificado autoassinado (esperado)
**Solução**: Aceite o certificado no navegador (clique em "Avançado" → "Continuar")

### Login não funciona
**Causa**: Senha incorreta
**Solução**: Use as credenciais corretas:
- Usuário: `admin`
- Senha: `Admin@123`

### Interface não conecta ao Redis
**Verificar**:
```bash
# Ver logs do Redis Commander
kubectl logs -n redis -l app=redis-commander --tail=20

# Verificar se o Redis Master está rodando
kubectl get pods -n redis -l app=redis-cluster,role=master

# Testar conexão direta com Redis
kubectl exec -it -n redis redis-master-0 -- redis-cli -a Admin@123 ping
```

## 📱 Acesso de Outros Dispositivos

### Mesmo Computador
✅ Acesse: https://redis-stats.home.arpa/

### Outro Computador na Mesma Rede

**Opção 1 - Usando DNS do Roteador** (você já fez isso):
```
Acesse diretamente: https://redis-stats.home.arpa/
```

**Opção 2 - Configurar /etc/hosts localmente**:
```bash
# No outro computador
echo "192.168.1.51 redis-stats.home.arpa" | sudo tee -a /etc/hosts
```

### Smartphone/Tablet

**Opção 1 - DNS do Roteador** (se configurou wildcard):
```
Acesse: https://redis-stats.home.arpa/
```

**Opção 2 - IP direto** (não funciona com TLS):
```
Não recomendado - o certificado TLS requer o domínio correto
```

**Opção 3 - Configurar DNS no dispositivo**:
- Android: Configurações → Wi-Fi → DNS privado
- iOS: Configurações → Wi-Fi → Configurar DNS

## 🔒 Segurança

### Credenciais Padrão
⚠️ **IMPORTANTE**: Por padrão, o Redis Commander usa:
- Usuário: `admin`
- Senha: mesma do Redis (`Admin@123`)

### Recomendações
✅ Acesso via TLS (HTTPS) ativado
✅ Autenticação básica habilitada
⚠️ Considere trocar a senha em produção
⚠️ Não exponha para internet pública

### Alterar Senha (opcional)

Para usar uma senha diferente do Redis:

```bash
# Editar o deployment
kubectl edit deployment redis-commander -n redis

# Procure por HTTP_PASSWORD e mude para o valor desejado
# Ou use um secret separado
```

## 📚 Referências

- **Redis Commander GitHub**: https://github.com/joeferner/redis-commander
- **Documentação Redis**: https://redis.io/docs/
- **Redis Commands**: https://redis.io/commands/

## 🎉 Resumo

✅ Redis Commander instalado com sucesso
✅ Acessível via: https://redis-stats.home.arpa/
✅ Login: admin / Admin@123
✅ TLS configurado com cert-manager
✅ Conectado ao Redis Master (192.168.1.51:6379)

**Aproveite sua interface web para gerenciar o Redis!** 🚀
