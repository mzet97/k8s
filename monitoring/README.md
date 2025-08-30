# 📊 Sistema de Monitoramento Completo - Grafana + Prometheus

## 🎯 **O que é este projeto?**

Este é um sistema completo de **monitoramento** para Kubernetes que permite:
- 📈 **Visualizar métricas** do seu cluster em dashboards bonitos
- 🚨 **Receber alertas** quando algo não está funcionando bem
- 📊 **Acompanhar performance** de aplicações e servidores
- 🔍 **Analisar histórico** de uso de recursos

### 🏗️ **Componentes Incluídos:**
- **Grafana**: Interface web para criar dashboards e visualizar dados
- **Prometheus**: Coleta e armazena métricas do cluster
- **Loki**: Sistema de agregação de logs distribuído
- **Mimir**: Armazenamento de métricas de longo prazo
- **Tempo**: Sistema de distributed tracing
- **Pyroscope**: Continuous profiling para análise de performance
- **Node Exporter**: Monitora recursos dos servidores (CPU, memória, disco)
- **Kube State Metrics**: Monitora recursos do Kubernetes (pods, services, etc.)

### ✨ **O que você terá após a instalação:**
- 🌐 **Interface web do Grafana** acessível via navegador
- 📊 **Dashboards pré-configurados** para monitorar o cluster
- 📝 **Sistema completo de logs** com Loki
- 📈 **Métricas de longo prazo** com Mimir
- 🔍 **Distributed tracing** com Tempo
- ⚡ **Continuous profiling** com Pyroscope
- 🔒 **Certificados TLS** para acesso seguro
- 💾 **Armazenamento persistente** para não perder dados
- 🚀 **Coleta automática** de métricas, logs, traces e profiles

## 📋 **Requisitos do Sistema**

### ✅ **Verificar se o MicroK8s está funcionando:**
```bash
microk8s status --wait-ready
```

### 🔧 **Habilitar addons necessários:**
```bash
# Habilitar ingress (para acesso web)
microk8s enable ingress

# Habilitar cert-manager (para certificados TLS)
microk8s enable cert-manager

# Habilitar storage (para salvar dados)
microk8s enable storage
```

### 🌐 **Verificar se os addons estão ativos:**
```bash
microk8s status
```
Devem aparecer como `enabled`: ingress, cert-manager, storage

## 🚀 **Instalação Passo a Passo**

### 📁 **1. Navegar para o diretório:**
```bash
cd d:\TI\git\k8s
```

### 🔐 **2. Configurar senha do Grafana (IMPORTANTE!):**
Antes de instalar, edite o arquivo `monitoring/01-grafana-admin-secret.yaml` e altere a senha padrão:
```bash
notepad monitoring/01-grafana-admin-secret.yaml
```
> 💡 **Dica**: Procure por `GF_SECURITY_ADMIN_PASSWORD` e coloque sua senha desejada

### 🏗️ **3. Instalar componentes básicos:**
```bash
# Criar namespace para monitoramento
microk8s kubectl apply -f monitoring/00-namespace.yaml

# Configurar senha do Grafana
microk8s kubectl apply -f monitoring/01-grafana-admin-secret.yaml

# Configurar conexão Grafana -> Prometheus
microk8s kubectl apply -f monitoring/02-grafana-config-datasource.yaml
```

### 📊 **4. Instalar Prometheus:**
```bash
# Permissões de segurança
microk8s kubectl apply -f monitoring/10-prometheus-rbac.yaml

# Configuração do Prometheus
microk8s kubectl apply -f monitoring/11-prometheus-config.yaml

# Servidor Prometheus
microk8s kubectl apply -f monitoring/12-prometheus-statefulset.yaml

# Serviço de rede do Prometheus
microk8s kubectl apply -f monitoring/40-prometheus-service.yaml
```

### 📈 **5. Instalar coletores de métricas:**
```bash
# Node Exporter (métricas do servidor)
microk8s kubectl apply -f monitoring/20-node-exporter-daemonset.yaml

# Kube State Metrics (métricas do Kubernetes)
microk8s kubectl apply -f monitoring/21-kube-state-metrics.yaml
```

### 🎨 **6. Instalar Grafana:**
```bash
# Servidor Grafana
microk8s kubectl apply -f monitoring/30-grafana-deployment.yaml

# Acesso web do Grafana
microk8s kubectl apply -f monitoring/31-grafana-ingress.yaml

# Certificado TLS do Grafana
microk8s kubectl apply -f monitoring/32-grafana-certificate.yaml
```

### 🌐 **7. Configurar acesso web do Prometheus:**
```bash
# Acesso web do Prometheus
microk8s kubectl apply -f monitoring/41-prometheus-ingress.yaml

# Certificado TLS do Prometheus
microk8s kubectl apply -f monitoring/42-prometheus-certificate.yaml
```

### 📝 **8. Instalar Loki (Sistema de Logs):**
```bash
# Servidor Loki para agregação de logs
microk8s kubectl apply -f monitoring/50-loki-config.yaml
```

### 📊 **9. Instalar Mimir (Métricas de Longo Prazo):**
```bash
# Servidor Mimir para armazenamento de métricas
microk8s kubectl apply -f monitoring/51-mimir-config.yaml
```

### 🔍 **10. Instalar Tempo (Distributed Tracing):**
```bash
# Servidor Tempo para rastreamento distribuído
microk8s kubectl apply -f monitoring/52-tempo-config.yaml
```

### ⚡ **11. Instalar Pyroscope (Continuous Profiling):**
```bash
# Servidor Pyroscope para profiling contínuo
microk8s kubectl apply -f monitoring/53-pyroscope-config.yaml
```

### 🌐 **12. Configurar acesso web para novos serviços:**
```bash
# Ingress e certificados TLS para todos os novos serviços
microk8s kubectl apply -f monitoring/54-ingress-certificates.yaml
```

### 📊 **13. Configurar monitoramento dos novos serviços:**
```bash
# ServiceMonitors para coleta de métricas
microk8s kubectl apply -f monitoring/55-servicemonitors.yaml

# Regras de alerta para os novos serviços
microk8s kubectl apply -f monitoring/56-alert-rules.yaml
```

## ✅ **Verificar se a instalação funcionou**

### 🔍 **1. Verificar se todos os pods estão rodando:**
```bash
microk8s kubectl get pods -n monitoring
```
**Resultado esperado**: Todos os pods devem estar com status `Running`

### 📊 **2. Verificar se os serviços estão ativos:**
```bash
microk8s kubectl get svc -n monitoring
```

### 🌐 **3. Verificar se os certificados foram criados:**
```bash
microk8s kubectl get certificates -n monitoring
```
**Resultado esperado**: Status `True` para `grafana-tls` e `prometheus-tls`

## 🌐 **Configurar Acesso Web**

### 📝 **1. Descobrir o IP do seu MicroK8s:**
```bash
microk8s kubectl get nodes -o wide
```
> 💡 **Anote o IP** que aparece na coluna `INTERNAL-IP`

### 🖥️ **2. Configurar arquivo hosts no Windows:**

**Abrir como Administrador:**
1. Pressione `Win + R`, digite `notepad` e pressione `Ctrl + Shift + Enter`
2. No Notepad, vá em `Arquivo > Abrir`
3. Navegue até: `C:\Windows\System32\drivers\etc\hosts`
4. Adicione estas linhas (substitua `SEU_IP` pelo IP do passo anterior):

```
SEU_IP  grafana.home.arpa
SEU_IP  prometheus.home.arpa
```

**Exemplo:**
```
192.168.1.100  grafana.home.arpa
192.168.1.100  prometheus.home.arpa
192.168.1.100  loki.home.arpa
192.168.1.100  mimir.home.arpa
192.168.1.100  tempo.home.arpa
192.168.1.100  pyroscope.home.arpa
```

### 🔐 **3. Acessar as interfaces web:**

**Grafana (Dashboards e Visualizações):**
- URL: `https://grafana.home.arpa`
- Usuário: `admin`
- Senha: A que você configurou no arquivo `01-grafana-admin-secret.yaml`
- 📊 **Funcionalidades**: Dashboards, alertas, exploração de dados

**Prometheus (Métricas):**
- URL: `https://prometheus.home.arpa`
- Não precisa de login
- 📈 **Funcionalidades**: Consultas PromQL, targets, alertas

**Loki (Logs):**
- URL: `https://loki.home.arpa`
- Não precisa de login
- 📝 **Funcionalidades**: API de logs, consultas LogQL

**Mimir (Métricas de Longo Prazo):**
- URL: `https://mimir.home.arpa`
- Não precisa de login
- 📊 **Funcionalidades**: API compatível com Prometheus, retenção estendida

**Tempo (Distributed Tracing):**
- URL: `https://tempo.home.arpa`
- Não precisa de login
- 🔍 **Funcionalidades**: API de traces, consultas TraceQL

**Pyroscope (Continuous Profiling):**
- URL: `https://pyroscope.home.arpa`
- Não precisa de login
- ⚡ **Funcionalidades**: Profiles de CPU/memória, flame graphs

> ⚠️ **Certificado**: Seu navegador pode mostrar aviso de certificado. Clique em "Avançado" e "Continuar" (é normal para certificados locais)

## 📊 **Como Usar o Sistema de Monitoramento**

### 🎨 **Primeiros Passos no Grafana:**

1. **Acesse o Grafana**: `https://grafana.home.arpa`
2. **Faça login** com usuário `admin` e sua senha
3. **Explore os dados**:
   - Vá em `Explore` no menu lateral
   - **Para Métricas**: Selecione `Prometheus` ou `Mimir`
     - Digite métricas como: `up`, `node_cpu_seconds_total`, `node_memory_MemAvailable_bytes`
   - **Para Logs**: Selecione `Loki`
     - Digite consultas como: `{namespace="monitoring"}`, `{app="grafana"} |= "error"`
   - **Para Traces**: Selecione `Tempo`
     - Busque por trace IDs ou explore service maps
   - **Para Profiling**: Selecione `Pyroscope`
     - Visualize flame graphs de CPU e memória

### 📈 **Criar seu primeiro dashboard:**

1. **Clique em `+`** no menu lateral → `Dashboard`
2. **Clique em `Add visualization`**
3. **Escolha métricas úteis**:
   
   **📊 Métricas de Sistema (Prometheus/Mimir):**
   - **CPU do servidor**: `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`
   - **Memória usada**: `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100`
   - **Pods rodando**: `kube_pod_status_phase{phase="Running"}`
   - **Espaço em disco**: `100 - ((node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100)`
   
   **📝 Logs (Loki):**
   - **Logs de erro**: `count_over_time({namespace="monitoring"} |= "error" [5m])`
   - **Taxa de logs**: `rate({namespace="monitoring"}[5m])`
   
   **🔍 Traces (Tempo):**
   - **Latência de serviços**: Visualize através do service map
   - **Contagem de spans**: Explore traces por serviço
   
   **⚡ Profiling (Pyroscope):**
   - **CPU usage**: Flame graphs por aplicação
   - **Memory allocation**: Profiles de alocação de memória

### 🚨 **Configurar alertas simples:**

1. **No dashboard**, clique em uma visualização
2. **Vá na aba `Alert`**
3. **Configure condições** (ex: CPU > 80%)
4. **Adicione canais de notificação** (email, Slack, etc.)

## 🔧 **Resolução de Problemas**

### ❌ **Pods não estão iniciando:**
```bash
# Ver detalhes dos pods com problema
microk8s kubectl describe pods -n monitoring

# Ver logs de um pod específico
microk8s kubectl logs -n monitoring <nome-do-pod>
```

### 🌐 **Não consigo acessar Grafana/Prometheus:**
```bash
# Verificar se o ingress está funcionando
microk8s kubectl get ingress -n monitoring

# Verificar se os certificados estão prontos
microk8s kubectl describe certificates -n monitoring

# Verificar arquivo hosts do Windows
type C:\Windows\System32\drivers\etc\hosts
```

### 📊 **Grafana não mostra dados:**
```bash
# Verificar se Prometheus está coletando dados
microk8s kubectl logs -n monitoring prometheus-0

# Verificar se os exporters estão rodando
microk8s kubectl get pods -n monitoring | findstr exporter
```

### 💾 **Problemas de armazenamento:**
```bash
# Verificar volumes persistentes
microk8s kubectl get pvc -n monitoring

# Ver detalhes de um volume
microk8s kubectl describe pvc -n monitoring <nome-do-pvc>
```

## 📋 **Lista de Arquivos do Projeto**

### 📁 **Arquivos Principais:**

| Arquivo | O que faz | Quando usar |
|---------|-----------|-------------|
| `00-namespace.yaml` | Cria o "espaço" do monitoramento | Sempre (primeiro arquivo) |
| `01-grafana-admin-secret.yaml` | Senha do Grafana | Sempre (configure sua senha) |
| `02-grafana-config-datasource.yaml` | Conecta Grafana aos datasources | Sempre |
| `10-prometheus-rbac.yaml` | Permissões do Prometheus | Sempre |
| `11-prometheus-config.yaml` | Configuração do Prometheus | Sempre |
| `12-prometheus-statefulset.yaml` | Servidor Prometheus | Sempre |
| `20-node-exporter-daemonset.yaml` | Monitor do servidor | Sempre |
| `21-kube-state-metrics.yaml` | Monitor do Kubernetes | Sempre |
| `30-grafana-deployment.yaml` | Servidor Grafana | Sempre |
| `31-grafana-ingress.yaml` | Acesso web do Grafana | Sempre |
| `32-grafana-certificate.yaml` | Certificado TLS do Grafana | Sempre |
| `40-prometheus-service.yaml` | Rede do Prometheus | Sempre |
| `41-prometheus-ingress.yaml` | Acesso web do Prometheus | Sempre |
| `42-prometheus-certificate.yaml` | Certificado TLS do Prometheus | Sempre |
| `50-loki-config.yaml` | Servidor Loki (logs) | Sempre |
| `51-mimir-config.yaml` | Servidor Mimir (métricas longo prazo) | Sempre |
| `52-tempo-config.yaml` | Servidor Tempo (tracing) | Sempre |
| `53-pyroscope-config.yaml` | Servidor Pyroscope (profiling) | Sempre |
| `54-ingress-certificates.yaml` | Acesso web dos novos serviços | Sempre |
| `55-servicemonitors.yaml` | Monitoramento dos novos serviços | Sempre |
| `56-alert-rules.yaml` | Regras de alerta para novos serviços | Sempre |

## 🗑️ **Como Remover o Sistema**

### 🧹 **Remover tudo:**
```bash
# Remover todos os recursos
microk8s kubectl delete namespace monitoring

# Remover volumes persistentes (CUIDADO: apaga todos os dados!)
microk8s kubectl delete pvc -n monitoring --all
```

### 📝 **Remover apenas configuração de hosts:**
1. Abra o Notepad como Administrador
2. Abra `C:\Windows\System32\drivers\etc\hosts`
3. Remova as linhas com:
   - `grafana.home.arpa`
   - `prometheus.home.arpa`
   - `loki.home.arpa`
- `mimir.home.arpa`
- `tempo.home.arpa`
- `pyroscope.home.arpa`

## ❓ **Perguntas Frequentes (FAQ)**

### **Q: O que são esses serviços de monitoramento?**
**A:** 
- **Grafana**: Interface web para criar dashboards e visualizar dados
- **Prometheus**: Coleta e armazena métricas do sistema
- **Loki**: Agrega e consulta logs de todas as aplicações
- **Mimir**: Armazena métricas por longos períodos (meses/anos)
- **Tempo**: Rastreia requisições através de múltiplos serviços (distributed tracing)
- **Pyroscope**: Analisa performance de código em tempo real (profiling)

### **Q: Posso usar em produção?**
**A:** Sim! Esta configuração inclui armazenamento persistente, certificados TLS e coleta automática de métricas. É adequada para ambientes de produção pequenos a médios.

### **Q: Como adicionar mais dados?**
**A:** 
- **Métricas**: Edite `11-prometheus-config.yaml` e adicione novos "jobs" na seção `scrape_configs`
- **Logs**: Configure suas aplicações para enviar logs para Loki (porta 3100)
- **Traces**: Instrumente suas aplicações com OpenTelemetry apontando para Tempo
- **Profiling**: Adicione annotations `pyroscope.io/scrape: "true"` nos seus pods

### **Q: Quanto espaço em disco usa?**
**A:** Por padrão:
- **Prometheus**: 20GB (retenção de 15 dias)
- **Grafana**: 10GB
- **Loki**: 20GB (retenção de 30 dias)
- **Mimir**: 50GB (retenção estendida)
- **Tempo**: 10GB (retenção de 24 horas)
- **Pyroscope**: 20GB (retenção de 30 dias)

**Total aproximado**: ~130GB

### **Q: Como fazer backup dos dashboards?**
**A:** No Grafana, vá em `Settings > Export` para cada dashboard. Salve os arquivos JSON como backup.

### **Q: Posso acessar de outros computadores?**
**A:** Sim! Adicione as mesmas linhas no arquivo hosts de outros computadores na rede, usando o IP do servidor MicroK8s.

## 🚀 **Próximos Passos**

### 👶 **Para Iniciantes:**
- Explore as métricas no Grafana
- Crie seu primeiro dashboard personalizado
- Configure alertas simples

### 👨‍💻 **Para Desenvolvedores:**
- Adicione métricas das suas aplicações
- Configure alertas avançados
- Integre com sistemas de notificação

### 👨‍💼 **Para Administradores:**
- Configure retenção de dados personalizada
- Implemente backup automatizado
- Configure alta disponibilidade

## 📞 **Suporte e Contribuições**

Este projeto foi criado para facilitar o monitoramento em ambientes Kubernetes. Se encontrar problemas ou tiver sugestões:

- 📖 Consulte a documentação oficial do [Grafana](https://grafana.com/docs/) e [Prometheus](https://prometheus.io/docs/)
- 🐛 Reporte bugs ou problemas
- 💡 Contribua com melhorias

---

## 📄 **Informações Técnicas**

### 🏗️ **Arquitetura:**
- **Prometheus**: Coleta métricas via HTTP scraping (retenção curta)
- **Mimir**: Armazenamento de métricas de longo prazo
- **Loki**: Agregação e consulta de logs distribuídos
- **Tempo**: Distributed tracing com suporte a múltiplos protocolos
- **Pyroscope**: Continuous profiling com auto-discovery
- **Node Exporter**: Expõe métricas do sistema operacional
- **Kube State Metrics**: Expõe métricas dos recursos Kubernetes
- **Grafana**: Interface web unificada para visualização e alertas
- **Armazenamento**: Volumes persistentes com `microk8s-hostpath`
- **Segurança**: Certificados TLS via cert-manager
- **Rede**: Ingress para acesso web externo

### ⚙️ **Configurações padrão:**
- **Prometheus**: 15 dias de retenção, 20GB de armazenamento
- **Mimir**: Retenção estendida, 50GB de armazenamento
- **Loki**: 30 dias de retenção, 20GB de armazenamento
- **Tempo**: 24 horas de retenção, 10GB de armazenamento
- **Pyroscope**: 30 dias de retenção, 20GB de armazenamento
- **Grafana**: 10GB de armazenamento
- **Intervalo de coleta**: 15 segundos (métricas), variável (logs/traces)
- **Timeout de scrape**: 10 segundos
- **Protocolos suportados**: Prometheus, Jaeger, Zipkin, OTLP, OpenCensus
