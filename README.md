# fluent-bit-and-k8s
Test out how Fluent Bit handles a very high volume service running in kubernetes.

## Reproducing Log Loss
To reproduce Fluent Bit dropping log segments at high k8s logging rates, run [Getting Started](#getting-started) steps 1-3 below, then run `./start-pods-and-monitor-for-log-loss.sh` in the terminal.

> [!NOTE]
> cpu resources are intentionally contrained to reproduce log loss due to cpu bound ingestion.

### Expected Output
This is what you would see if there was no log loss - log sequence numbers incrementing by 1, with each sequence number being logged 1,000 times.

```
[Tue Aug 26 11:01:25 PM UTC 2025] Count of processed log sequences...
   1000 {"seq":"01017"}
   1000 {"seq":"01018"}
   1000 {"seq":"01019"}
   1000 {"seq":"01020"}
   1000 {"seq":"01021"}
   1000 {"seq":"01022"}
   1000 {"seq":"01023"}
   1000 {"seq":"01024"}
   1000 {"seq":"01025"}
   1000 {"seq":"01026"}
   1000 {"seq":"01027"}
   1000 {"seq":"01028"}
   1000 {"seq":"01029"}
   1000 {"seq":"01030"}
   1000 {"seq":"01031"}
   1000 {"seq":"01032"}
   1000 {"seq":"01033"}
   1000 {"seq":"01034"}
    810 {"seq":"01035"}

[Tue Aug 26 11:01:30 PM UTC 2025] Count of processed log sequences...
...
```

### Actual Output
There are gaps in the sequence number range, and only some sequence numbers were logged 1,000 times.

```
[Tue Aug 26 11:08:05 PM UTC 2025] Count of processed log sequences...
   1000 {"seq":"01163"}
    575 {"seq":"01164"}
   1000 {"seq":"01171"}
    440 {"seq":"01172"}
   1000 {"seq":"01179"}
    530 {"seq":"01180"}
   1000 {"seq":"01187"}
    440 {"seq":"01188"}
   1000 {"seq":"01195"}
    425 {"seq":"01196"}
   1000 {"seq":"01203"}
   1000 {"seq":"01204"}
     10 {"seq":"01205"}
    337 {"seq":"01211"}
   1000 {"seq":"01212"}
     13 {"seq":"01213"}
   1000 {"seq":"01220"}
    185 {"seq":"01221"}
    600 {"seq":"01228"}

[Tue Aug 26 11:08:10 PM UTC 2025] Count of processed log sequences...
...
```

`kubectl logs -n logging -l app=fluent-bit -f | grep purge` shows `[debug] [input:tail:tail.0] purge: monitored file has been deleted` is logged every 10 seconds. 10 seconds aligns with log rotation & deletion.

### Possible `rotate_wait` workaround
`rotate_wait` can be set to a high value like `3600` seconds to potentially reduce calls to [check_purge_deleted_file](https://github.com/fluent/fluent-bit/blob/3254b9ad6fc51a3a6d6b38bfced0c819e0da93ed/plugins/in_tail/tail_file.c#L1995). This allows Fluent Bit to continue to read from deleted log files it has open. If you set this you'll see newer log sequences get picked up, and older log sequences gradually fill in.

```
[Tue Aug 26 11:53:22 PM UTC 2025] Count of processed log sequences...
   1000 {"seq":"01001"}
     65 {"seq":"01002"}
    276 {"seq":"01007"}
    444 {"seq":"01008"}
    390 {"seq":"01015"}
    165 {"seq":"01023"}
   1000 {"seq":"01094"}
    725 {"seq":"01095"}
    720 {"seq":"01102"}
    390 {"seq":"01110"}

[Tue Aug 26 11:53:28 PM UTC 2025] Count of processed log sequences...
   1000 {"seq":"01001"}
    140 {"seq":"01002"} *
    276 {"seq":"01007"}
    519 {"seq":"01008"} *
    465 {"seq":"01015"}
    240 {"seq":"01023"}
     60 {"seq":"01031"}
   1000 {"seq":"01094"}
    800 {"seq":"01095"}
    795 {"seq":"01102"}

...

[Tue Aug 26 11:57:54 PM UTC 2025] Count of processed log sequences...
   1000 {"seq":"01001"} *
   1000 {"seq":"01002"} *
   1000 {"seq":"01003"} *
     75 {"seq":"01004"} *
    276 {"seq":"01007"}
   1000 {"seq":"01008"} *
   1000 {"seq":"01009"} *
    454 {"seq":"01010"} *
    690 {"seq":"01015"}
   1000 {"seq":"01016"}
```

`kubectl logs -n logging -l app=fluent-bit -f | grep purge` no longer shows purges every 10 seconds.

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
head -n 1 $(find . -name '0.log.*-*[0-9]') | cut -c1-70; tail -n 1 $(find . -name '0.log.*-*[0-9]') | cut -c1-70

# check for log loss in the recently logged sequence range
grep 01169 /var/fluent-bit-logs/processed-logs.log | wc -l
grep 01170 /var/fluent-bit-logs/processed-logs.log | wc -l
...
grep 01177 /var/fluent-bit-logs/processed-logs.log | wc -l

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
