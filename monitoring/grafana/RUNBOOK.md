# Grafana Monitoring Runbook for EventSphere

Complete guide to using Grafana dashboards to meet project requirements and monitor your application.

## 📋 Table of Contents

1. [Accessing Grafana](#accessing-grafana)
2. [Project Requirements Coverage](#project-requirements-coverage)
3. [Dashboard Overview](#dashboard-overview)
4. [Key Metrics to Monitor](#key-metrics-to-monitor)
5. [Troubleshooting Guide](#troubleshooting-guide)
6. [Creating Custom Dashboards](#creating-custom-dashboards)

---

## 🚀 Accessing Grafana

### Method 1: Port Forward (Local Access)

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Then open: **http://localhost:3000**

### Method 2: Public URL (After DNS Setup)

```
https://monitoring.enpm818rgroup7.work.gd
```

### Login Credentials

```
Username: admin
Password: EventSphere2024
```

**⚠️ Change the password after first login!**

---

## ✅ Project Requirements Coverage

### Requirement: "Apply Observability Tools (CloudWatch, Prometheus, Grafana)"

| Requirement | Location in Grafana | Dashboard/Feature |
|-------------|---------------------|-------------------|
| **Metrics Dashboards** | `EventSphere Dashboard` | All panels show live metrics |
| **Latency Monitoring** | N/A (requires app metrics) | Can be added via custom queries |
| **Error Rate** | N/A (requires app metrics) | Can be added via custom queries |
| **Resource Utilization** | `CPU Usage by Pod`, `Memory Usage by Pod` | Real-time CPU/Memory graphs |
| **Health Checks** | `Running Pods`, `Unhealthy Pods` stats | Pod status overview |
| **Rolling Updates** | `Available Replicas by Deployment` | Track deployment rollout |

### Where to Find Each Requirement

#### 1. Resource Utilization ✅
- **Dashboard:** EventSphere Dashboard
- **Panels:** 
  - "CPU Usage by Pod" (line chart)
  - "Memory Usage by Pod" (line chart)
- **Location:** Middle section of dashboard
- **What it shows:** Real-time CPU and memory usage for each pod

#### 2. Pod Health Monitoring ✅
- **Dashboard:** EventSphere Dashboard  
- **Panels:**
  - "Running Pods" (stat panel, top left)
  - "Unhealthy Pods" (stat panel, top right)
  - "Restarts (1h)" (stat panel, top center)
- **Location:** Top row of dashboard
- **What it shows:** Overall cluster health at a glance

#### 3. Deployment Status ✅
- **Dashboard:** EventSphere Dashboard
- **Panels:**
  - "Available Replicas by Deployment" (line chart)
  - "HPA Status" (line chart showing current vs max replicas)
- **Location:** Bottom section
- **What it shows:** Replica counts and autoscaling status

#### 4. Alert Monitoring ✅
- **Dashboard:** EventSphere Dashboard
- **Panels:** "Firing Alerts" (stat panel, top right)
- **Location:** Top row
- **What it shows:** Number of active alerts

---

## 📊 Dashboard Overview

### EventSphere Application Dashboard

**Location:** Dashboards → EventSphere → EventSphere Dashboard

#### Top Row - Health Overview (4 Stat Panels)

1. **Running Pods**
   - Shows count of pods in "Running" state
   - **Green = Healthy**
   - **Red = Problem** (if count drops)

2. **Unhealthy Pods**
   - Shows pods in Pending/Failed/Unknown state
   - **Red = Problem** (any value > 0)

3. **Restarts (1h)**
   - Total pod restarts in last hour
   - **Yellow/Red = Problem** (>3 restarts)

4. **Firing Alerts**
   - Active Prometheus alerts
   - **Red = Problem** (any alerts firing)

#### Middle Section - Resource Metrics (2 Line Charts)

5. **CPU Usage by Pod**
   - Real-time CPU consumption
   - Shows all pods in `prod` namespace
   - **Watch for:** Sustained >80% usage

6. **Memory Usage by Pod**
   - Real-time memory consumption in MB
   - Shows all pods in `prod` namespace
   - **Watch for:** Approaching memory limits

#### Bottom Section - Deployment Metrics (2 Line Charts)

7. **Available Replicas by Deployment**
   - Shows current replica count for each deployment
   - **Watch for:** Replicas dropping or not matching desired

8. **HPA Status**
   - Shows current vs maximum replicas for HPA
   - **Watch for:** HPA stuck at max (cannot scale further)

---

## 🎯 Key Metrics to Monitor

### Daily Checks

#### Morning Check (9 AM)
1. **Open Grafana Dashboard**
2. **Check Top Row Stats:**
   - Running Pods = Expected count?
   - Unhealthy Pods = 0?
   - Restarts = Low (< 3)?
   - Firing Alerts = 0?

3. **Review Resource Usage:**
   - Are CPU/Memory graphs stable?
   - Any spikes or anomalies?

#### During Business Hours
- Monitor "Restarts" - sudden increases indicate issues
- Watch "Unhealthy Pods" - should always be 0
- Check "Firing Alerts" - investigate immediately if > 0

### Weekly Review

1. **Trend Analysis:**
   - CPU usage trends over week
   - Memory usage patterns
   - Restart frequency

2. **Capacity Planning:**
   - Are we approaching resource limits?
   - Do we need to adjust HPA settings?

---

## 🔍 Troubleshooting Guide

### Issue: High Pod Restart Count

**Symptoms:** "Restarts (1h)" showing high number

**Steps:**
1. Click on the stat panel to see which pods
2. Go to **Explore** tab in Grafana
3. Query: `increase(kube_pod_container_status_restarts_total{namespace="prod"}[1h])`
4. Identify pod with most restarts
5. Check logs: `kubectl logs <pod-name> -n prod`

**Common Causes:**
- Application errors
- Memory limits too low (OOMKilled)
- Liveness probe too aggressive

### Issue: Pods Not Ready

**Symptoms:** "Unhealthy Pods" > 0

**Steps:**
1. Go to **Explore** tab
2. Query: `kube_pod_status_phase{namespace="prod", phase!="Running", phase!="Succeeded"}`
3. Check pod status: `kubectl describe pod <pod-name> -n prod`
4. Check events: `kubectl get events -n prod --field-selector involvedObject.name=<pod-name>`

**Common Causes:**
- Image pull errors
- Resource constraints
- Configuration errors

### Issue: High CPU/Memory Usage

**Symptoms:** CPU or Memory graphs showing >80% consistently

**Steps:**
1. Identify which pod from the graph
2. Check resource limits: `kubectl describe pod <pod-name> -n prod | grep Limits`
3. Consider:
   - Increasing resource limits
   - Optimizing application code
   - Scaling horizontally (more replicas)

### Issue: Deployment Not Scaling

**Symptoms:** HPA Status shows stuck at max replicas

**Steps:**
1. Check HPA configuration: `kubectl describe hpa <hpa-name> -n prod`
2. Check if cluster has capacity: `kubectl top nodes`
3. Check HPA metrics: `kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/prod/pods`

---

## 📈 Creating Custom Dashboards

### Step 1: Create New Dashboard

1. Click **"+"** → **"Dashboard"** (or **Dashboards** → **New**)
2. Click **"Add visualization"**

### Step 2: Configure Data Source

1. Select **Prometheus** as data source
2. Ensure it's connected (should show "Success")

### Step 3: Add Query

Example: Pod CPU Usage Query

```promql
sum(rate(container_cpu_usage_seconds_total{namespace="prod", container!=""}[5m])) by (pod) * 100
```

### Step 4: Customize Visualization

1. **Time Series:** Line chart over time
2. **Stat:** Single number display
3. **Bar Gauge:** Percentage bars
4. **Table:** Tabular data

### Step 5: Set Panel Title & Save

1. Click panel title → Edit
2. Set descriptive title
3. Click **Save dashboard**

---

## 🎓 Useful Prometheus Queries for Grafana

Copy these into Grafana's query editor:

### Pod CPU Usage (%)
```promql
sum(rate(container_cpu_usage_seconds_total{namespace="prod", container!=""}[5m])) by (pod) / sum(container_spec_cpu_quota{namespace="prod", container!=""}/container_spec_cpu_period{namespace="prod", container!=""}) by (pod) * 100
```

### Pod Memory Usage (MB)
```promql
sum(container_memory_working_set_bytes{namespace="prod", container!=""}) by (pod) / 1024 / 1024
```

### Deployment Replicas
```promql
kube_deployment_status_replicas_available{namespace="prod"}
```

### Pod Restart Count
```promql
sum(increase(kube_pod_container_status_restarts_total{namespace="prod"}[1h])) by (pod)
```

---

## 📋 Pre-built Dashboards

### Available Built-in Dashboards

1. **EventSphere Dashboard** (Custom)
   - Application-specific metrics
   - Pod health and resource usage

2. **Kubernetes / Compute Resources / Pod** (Built-in)
   - Detailed pod metrics
   - CPU, memory, network, filesystem

3. **Kubernetes / Compute Resources / Cluster** (Built-in)
   - Cluster-wide resource usage
   - Node metrics

4. **Kubernetes / Networking / Pod** (Built-in)
   - Network I/O metrics
   - Connection statistics

5. **Node Exporter / Nodes** (Built-in)
   - Node-level metrics
   - System resource usage

**Access:** Dashboards → Browse → Select dashboard

---

## 🔐 Security Best Practices

1. **Change Default Password:**
   - Profile → Preferences → Change Password

2. **Limit Public Access:**
   - Consider using port-forward only in production
   - Or add authentication layer (OAuth, etc.)

3. **Dashboard Permissions:**
   - Create read-only users for team members
   - Settings → Users → Add user

---

## 📞 Support & Resources

### Getting Help

1. **Check Prometheus Targets:**
   - Go to Prometheus UI → Status → Targets
   - Ensure all targets are "UP"

2. **Check Data Source:**
   - Grafana → Configuration → Data Sources → Prometheus
   - Test connection

3. **View Logs:**
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
   ```

### Additional Resources

- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [PromQL Query Examples](../../prometheus/QUERIES.md)
- [Prometheus Documentation](https://prometheus.io/docs/)

---

## ✅ Checklist: Project Requirements Met

- [x] **Metrics Dashboards:** EventSphere Dashboard with 8 panels
- [x] **Resource Utilization:** CPU and Memory graphs
- [x] **Health Checks:** Pod status panels
- [x] **Rolling Updates:** Deployment replica tracking
- [x] **Alert Monitoring:** Firing alerts counter
- [x] **HPA Status:** Autoscaler monitoring
- [x] **Historical Data:** 7-day retention (Prometheus)
- [x] **Public Access:** Available via ingress (with DNS)

---

**Last Updated:** 2025-01-12  
**Version:** 1.0  
**Maintained By:** EventSphere DevOps Team

