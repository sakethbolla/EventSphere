# Prometheus Queries for EventSphere

Useful PromQL queries for monitoring your EventSphere application.

## 📊 Cluster & Node Metrics

### Node CPU Usage
```promql
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### Node Memory Usage
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

### Node Disk Usage
```promql
(1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100
```

## 🐳 Pod & Container Metrics

### Pod CPU Usage by Namespace
```promql
sum(rate(container_cpu_usage_seconds_total{namespace="prod"}[5m])) by (pod, namespace)
```

### Pod Memory Usage by Namespace
```promql
sum(container_memory_working_set_bytes{namespace="prod", container!=""}) by (pod, namespace) / 1024 / 1024
```

### Pod Restart Count (Last Hour)
```promql
sum(increase(kube_pod_container_status_restarts_total{namespace="prod"}[1h])) by (pod)
```

### Pod Status Count
```promql
count(kube_pod_status_phase{namespace="prod"}) by (phase)
```

## 📦 Deployment Metrics

### Deployment Replica Status
```promql
kube_deployment_status_replicas{namespace="prod"}
```

### Deployment Replicas Desired vs Available
```promql
kube_deployment_status_replicas_available{namespace="prod"}
```

### Deployment Replicas Mismatch
```promql
kube_deployment_spec_replicas{namespace="prod"} - kube_deployment_status_replicas_available{namespace="prod"}
```

## ⚖️ HPA Metrics

### HPA Current vs Desired Replicas
```promql
kube_horizontalpodautoscaler_status_current_replicas{namespace="prod"}
```

### HPA Target CPU Utilization
```promql
kube_horizontalpodautoscaler_status_target_metric{namespace="prod", metric_name="cpu"}
```

### HPA at Max Replicas
```promql
kube_horizontalpodautoscaler_status_current_replicas{namespace="prod"} == kube_horizontalpodautoscaler_spec_max_replicas{namespace="prod"}
```

## 🔧 Service-Specific Queries

### Service Pod Count
```promql
count(kube_pod_info{namespace="prod"}) by (label_app)
```

### Service CPU Usage
```promql
sum(rate(container_cpu_usage_seconds_total{namespace="prod", pod=~".*"}[5m])) by (label_app)
```

### Service Memory Usage
```promql
sum(container_memory_working_set_bytes{namespace="prod", container!=""}) by (label_app) / 1024 / 1024
```

## 📈 Resource Limits & Requests

### CPU Requests vs Limits
```promql
sum(container_spec_cpu_quota{namespace="prod"}/container_spec_cpu_period{namespace="prod"}) by (pod)
```

### Memory Requests vs Limits
```promql
sum(container_spec_memory_limit_bytes{namespace="prod"}) by (pod) / 1024 / 1024
```

### CPU Utilization Percentage
```promql
(sum(rate(container_cpu_usage_seconds_total{namespace="prod", container!=""}[5m])) by (pod) / sum(container_spec_cpu_quota{namespace="prod", container!=""}/container_spec_cpu_period{namespace="prod", container!=""}) by (pod)) * 100
```

### Memory Utilization Percentage
```promql
(sum(container_memory_working_set_bytes{namespace="prod", container!=""}) by (pod) / sum(container_spec_memory_limit_bytes{namespace="prod", container!=""}) by (pod)) * 100
```

## 🌐 Network Metrics

### Network I/O Rate (Bytes/sec)
```promql
sum(rate(container_network_receive_bytes_total{namespace="prod"}[5m])) by (pod)
```

### Network Transmit Rate
```promql
sum(rate(container_network_transmit_bytes_total{namespace="prod"}[5m])) by (pod)
```

## 🚨 Alert-Related Queries

### Firing Alerts Count
```promql
count(ALERTS{alertstate="firing", namespace="prod"})
```

### Alert by Severity
```promql
count by (severity) (ALERTS{alertstate="firing", namespace="prod"})
```

## 💾 Storage Metrics

### PVC Usage
```promql
kubelet_volume_stats_used_bytes{namespace="prod"} / kubelet_volume_stats_capacity_bytes{namespace="prod"} * 100
```

## 🔍 Troubleshooting Queries

### Pods Not Ready
```promql
kube_pod_status_phase{namespace="prod", phase!="Running", phase!="Succeeded"}
```

### Pods with Recent Restarts
```promql
rate(kube_pod_container_status_restarts_total{namespace="prod"}[15m]) > 0
```

### High Memory Usage Pods (> 80%)
```promql
(container_memory_working_set_bytes{namespace="prod", container!=""} / container_spec_memory_limit_bytes{namespace="prod", container!=""}) > 0.8
```

### High CPU Usage Pods (> 80%)
```promql
(sum(rate(container_cpu_usage_seconds_total{namespace="prod", container!=""}[5m])) by (pod) / sum(container_spec_cpu_quota{namespace="prod", container!=""}/container_spec_cpu_period{namespace="prod", container!=""}) by (pod)) > 0.8
```

## 📝 How to Use These Queries

1. **Access Prometheus UI:**
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
   # Open: http://localhost:9090
   ```

2. **Paste Query:**
   - Go to the Prometheus UI
   - Paste the query in the query box
   - Click "Execute"
   - View results in table or graph format

3. **Create Alerts:**
   - Go to "Alerts" tab
   - Use these queries as alert conditions
   - Set thresholds based on your requirements

4. **Add to Grafana:**
   - Copy the query
   - Create a new panel in Grafana
   - Paste query in the Prometheus data source
   - Visualize the results

## 🎯 Example: Create Custom Alert

1. Go to Prometheus UI → **Alerts** → **New Alert Rule**
2. Set alert name: `HighPodMemoryUsage`
3. Use query:
   ```promql
   (container_memory_working_set_bytes{namespace="prod", container!=""} / container_spec_memory_limit_bytes{namespace="prod", container!=""}) > 0.9
   ```
4. Set condition: `for: 5m`
5. Add annotations for description

## 📚 Additional Resources

- [PromQL Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Prometheus Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [Kubernetes Metrics](https://github.com/kubernetes/kube-state-metrics/tree/master/docs)

