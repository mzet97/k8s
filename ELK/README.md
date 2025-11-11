# ELK Stack no Kubernetes (Homelab)

Provisiona Elasticsearch (cluster 3 nós), Kibana, Logstash e Filebeat, seguindo o padrão dos diretórios `rabbitmq` e `redis` para homelab.

## Visão Rápida
- Namespace: `elk`
- Elasticsearch: StatefulSet `elasticsearch` com 3 réplicas, `ClusterIP` e `NodePort` (9200→30920)
- Kibana: Deployment `kibana`, `Service` e `NodePort` (5601→31601), Ingress TLS (`kibana.home.arpa`)
- Logstash: Deployment `logstash`, `Service` e `NodePort` (5044→30044)
- Filebeat: DaemonSet coletando logs de `/var/log/containers` e enviando para Logstash
- TLS: apenas para Kibana via cert-manager; Elasticsearch sem segurança para simplificar (7.17)

## Manifests Principais
- `00-namespace.yaml`: cria `elk`
- `10-elasticsearch-configmap.yaml`: `elasticsearch.yml` com `xpack.security: false`
- `11-headless-svc.yaml`, `12-client-svc.yaml`, `13-nodeport-svc.yaml`: serviços do ES
- `20-elasticsearch-statefulset.yaml`: cluster com 3 nós e `emptyDir` para dados
- `30-kibana-deployment.yaml`, `31-kibana-svc.yaml`, `32-kibana-nodeport.yaml`: Kibana
- `33-kibana-ingress.yaml`, `34-tls-certificates.yaml`: Ingress + TLS para `kibana.home.arpa`
- `40-logstash-configmap.yaml`, `41-logstash-deployment.yaml`, `42-logstash-svc.yaml`, `43-logstash-nodeport.yaml`
- `50-filebeat-configmap.yaml`, `51-filebeat-daemonset.yaml`, `03-rbac.yaml`: Filebeat + RBAC
- `60-network-policy.yaml`: permite acesso da LAN às portas principais

## Instalação
```bash
cd ELK

kubectl apply -f 00-namespace.yaml
kubectl apply -f 03-rbac.yaml

# Elasticsearch
kubectl apply -f 10-elasticsearch-configmap.yaml
kubectl apply -f 11-headless-svc.yaml
kubectl apply -f 12-client-svc.yaml
kubectl apply -f 13-nodeport-svc.yaml
kubectl apply -f 20-elasticsearch-statefulset.yaml

# Kibana
kubectl apply -f 31-kibana-svc.yaml
kubectl apply -f 32-kibana-nodeport.yaml
kubectl apply -f 30-kibana-deployment.yaml
kubectl apply -f 34-tls-certificates.yaml || true
kubectl apply -f 33-kibana-ingress.yaml

# Logstash
kubectl apply -f 40-logstash-configmap.yaml
kubectl apply -f 42-logstash-svc.yaml
kubectl apply -f 43-logstash-nodeport.yaml
kubectl apply -f 41-logstash-deployment.yaml

# Filebeat
kubectl apply -f 50-filebeat-configmap.yaml
kubectl apply -f 51-filebeat-daemonset.yaml

# NetworkPolicy
kubectl apply -f 60-network-policy.yaml
```

## Verificação
```bash
kubectl -n elk get pods -o wide
kubectl -n elk get svc -o wide
kubectl -n elk get ingress
```

## Testes
- Elasticsearch (HTTP API):
  - Interno: `curl -s http://elasticsearch.elk.svc.cluster.local:9200`
  - NodePort: `NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}') && curl -s http://$NODE_IP:30920`
- Kibana:
  - NodePort: `http://<NODE_IP>:31601`
  - Ingress TLS: `https://kibana.home.arpa` (adicione `/etc/hosts` se necessário)
    ```bash
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    echo "$NODE_IP kibana.home.arpa" | sudo tee -a /etc/hosts
    curl -Ik --resolve kibana.home.arpa:443:$NODE_IP https://kibana.home.arpa/
    ```
- Logstash/Beats:
  - Portas: `5044` (Service `logstash`, NodePort `30044`)
  - Filebeat deve enviar logs de pods automaticamente para Logstash → ES. Valide índices:
    ```bash
    curl -s http://elasticsearch.elk.svc.cluster.local:9200/_cat/indices?v | grep logs-
    ```

## Troubleshooting
- ES não forma cluster:
  - Verifique `cluster.initial_master_nodes` e `discovery.seed_hosts`
  - `kubectl -n elk logs statefulset/elasticsearch`
- Kibana 502/404:
  - Aguarde readiness; verifique `ELASTICSEARCH_HOSTS`
- Filebeat sem enviar:
  - Confirme montagens de `/var/log/containers` e RBAC

## Remoção
```bash
kubectl delete -n elk -f 51-filebeat-daemonset.yaml -f 50-filebeat-configmap.yaml -f 03-rbac.yaml
kubectl delete -n elk -f 41-logstash-deployment.yaml -f 43-logstash-nodeport.yaml -f 42-logstash-svc.yaml -f 40-logstash-configmap.yaml
kubectl delete -n elk -f 30-kibana-deployment.yaml -f 32-kibana-nodeport.yaml -f 31-kibana-svc.yaml -f 33-kibana-ingress.yaml -f 34-tls-certificates.yaml
kubectl delete -n elk -f 20-elasticsearch-statefulset.yaml -f 13-nodeport-svc.yaml -f 12-client-svc.yaml -f 11-headless-svc.yaml -f 10-elasticsearch-configmap.yaml
kubectl delete namespace elk
```

## Notas
- Esta stack usa Elasticsearch 7.17 com `xpack.security` desabilitado para simplicidade em homelab.
- Para persistência, substitua `emptyDir` por `PersistentVolumeClaim` no StatefulSet.
- Ajuste recursos conforme capacidade do cluster.