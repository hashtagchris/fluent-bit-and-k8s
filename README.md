# fluent-bit-and-k8s
Test out how fluent-bit handles a very high volume service running in kubernetes

## Quick Start with Devcontainer

This project includes a fully configured devcontainer that runs a K3s Kubernetes cluster, perfect for testing Fluent Bit configurations.

### Prerequisites
- Visual Studio Code
- Docker Desktop
- Dev Containers extension

### Getting Started

1. **Open in Dev Container**
   - Open this repository in VS Code
   - When prompted, click "Reopen in Container"
   - Or use Command Palette: `Dev Containers: Reopen in Container`

2. **Wait for Setup**
   - The container will automatically install K3s (takes 2-3 minutes)
   - You'll see setup progress in the terminal

3. **Verify Installation**
   ```bash
   kubectl get nodes
   kubectl cluster-info
   ```

4. **Deploy Fluent Bit**
   ```bash
   kubectl apply -f k8s-manifests/fluent-bit.yaml
   ```

5. **Create High-Volume Test Workloads**
   ```bash
   kubectl apply -f k8s-manifests/log-generators.yaml
   ```

6. **Monitor Pod Logs**
   ```bash
   # Check Fluent Bit status
   kubectl get pods -n logging

   # View Fluent Bit logs
   kubectl logs -n logging -l app=fluent-bit -f

   # Check log generators
   kubectl get pods
   kubectl logs -f deployment/high-volume-logger
   ```

7. **Monitor Fluent Bit Output**

`fluent-bit.yaml` specifies a [`file`](https://docs.fluentbit.io/manual/data-pipeline/outputs/file) output.

   ```bash
   # tail fluent bit's output
   tail -f /var/fluent-bit-logs/processed-logs.log

   # check for log loss
   # every sequence number should show up 1,000 times
   cat /var/fluent-bit-logs/processed-logs.log | sort | uniq -c | tail -n 40
   ```

## Quickly iterating
### fluent-bit config

Edit `k8s-manifests/fluent-bit.yaml`, followed by:

```
kubectl apply -f k8s-manifests/fluent-bit.yaml && kubectl rollout restart daemonset/fluent-bit -n logging && kubectl rollout status daemonset/fluent-bit -n logging && kubectl logs -n logging -l app=fluent-bit -f
```

### log generators

Edit `k8s-manifests/log-generators.yaml`, followed by:

```
kubectl apply -f k8s-manifests/log-generators.yaml && kubectl rollout restart deployment/high-volume-logger -n default
```

## Comparing k8s logs and fluent-bit output

```
sudo su -
cd /var/log/pods/default_high-volume-logger-*/logger
head -n 1 $(find . -name '0.log.20250823-[0-9][0-9][0-9][0-9][0-9][0-9]') | cut -c1-70; tail -n 1 $(find . -name '0.log.20250823-[0-9][0-9][0-9][0-9][0-9][0-9]') | cut -c1-70

# check for log loss in the recently logged sequence range
grep '"1-45"' /var/fluent-bit-logs/processed-logs.log | wc -l
grep '"1-46"' /var/fluent-bit-logs/processed-logs.log | wc -l
...
grep '"1-52"' /var/fluent-bit-logs/processed-logs.log | wc -l

# Or count distinct lines
# This may show a processing rate of roughly 300 msg/sec
cat /var/fluent-bit-logs/processed-logs.log | sort | uniq -c | tail -n 40
```

## Project Structure

```
├── .devcontainer/          # Dev container configuration
│   ├── devcontainer.json   # Main devcontainer config
│   ├── setup-k3s.sh       # K3s installation script
│   └── README.md           # Detailed devcontainer docs
├── k8s-manifests/          # Kubernetes manifests
│   ├── fluent-bit.yaml     # Fluent Bit DaemonSet
│   └── log-generators.yaml # High-volume log generators
└── README.md              # This file
```

## Testing Scenarios

### High Volume Continuous Logging
The `high-volume-logger` deployment generates continuous log streams to test Fluent Bit's handling of sustained high-volume logging.

### Custom Testing
Modify the log generators in `k8s-manifests/log-generators.yaml` to test specific scenarios:
- Different log formats (JSON, plain text, structured)
- Various log volumes and patterns
- Different container restart behaviors
- Resource constraint scenarios

## Monitoring and Debugging

Access Fluent Bit's built-in HTTP server for metrics and debugging:
```bash
# Port forward to access Fluent Bit HTTP server
kubectl port-forward -n logging svc/fluent-bit 2020:2020

# View metrics (in another terminal or browser)
curl http://localhost:2020/api/v1/metrics
curl http://localhost:2020/api/v1/uptime
```

## Next Steps

1. **Customize Fluent Bit Configuration**: Edit the ConfigMap in `k8s-manifests/fluent-bit.yaml`
2. **Add Output Destinations**: Configure outputs to send logs to your preferred destination
3. **Scale Testing**: Increase replicas of log generators to test higher volumes
4. **Performance Tuning**: Adjust Fluent Bit buffer settings and resource limits
5. **Advanced Scenarios**: Test pod restarts, node failures, and other real-world conditions
