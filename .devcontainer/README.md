# K3s Development Container

This devcontainer provides a complete Kubernetes development environment using K3s, perfect for testing Fluent Bit and other Kubernetes applications.

## Features

- **K3s Kubernetes cluster** - Lightweight Kubernetes distribution
- **Docker-in-Docker** - For building and running containers
- **kubectl and Helm** - Pre-installed Kubernetes tools
- **VS Code extensions** - Kubernetes Tools, YAML support
- **Port forwarding** - Easy access to services
- **Persistent storage** - K3s data persists across container restarts

## Quick Start

1. **Open in VS Code**: Use "Reopen in Container" when prompted, or use the Command Palette (`Cmd+Shift+P`) and select "Dev Containers: Reopen in Container"

2. **Wait for setup**: The container will automatically install and configure K3s (this takes a few minutes)

3. **Verify installation**:
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

## Configuration Details

### K3s Setup
- Runs without Traefik (ingress controller disabled)
- Service Load Balancer disabled
- Metrics server disabled
- Write kubeconfig with proper permissions

### Port Forwarding
- `6443` - Kubernetes API Server
- `8080` - Common HTTP port
- `30000-30005` - NodePort services

### Volumes
- `k3s-server-data` - Persistent storage for K3s data

## Useful Commands

```bash
# Check cluster status
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Create a namespace for your work
kubectl create namespace myapp

# Set default namespace
kubectl config set-context --current --namespace=myapp

# Deploy a simple test pod
kubectl run nginx --image=nginx --port=80
kubectl expose pod nginx --type=NodePort --port=80

# View services
kubectl get svc
```

## Testing Fluent Bit

Since this project is about testing Fluent Bit with high volume services, here are some useful commands:

```bash
# Deploy Fluent Bit as a DaemonSet
kubectl apply -f https://raw.githubusercontent.com/fluent/fluent-bit-kubernetes-logging/master/fluent-bit-daemonset.yaml

# Check Fluent Bit pods
kubectl get pods -n kube-system | grep fluent-bit

# View Fluent Bit logs
kubectl logs -n kube-system -l k8s-app=fluent-bit

# Create a high-volume log generator for testing
kubectl create deployment log-generator --image=chentex/random-logger
kubectl scale deployment log-generator --replicas=5
```

## Alternative: Docker Compose Setup

If you prefer to run K3s via Docker Compose instead of the native installation:

```bash
# Stop the native k3s service
sudo systemctl stop k3s

# Start with docker-compose
cd .devcontainer
docker-compose up -d

# Configure kubectl
./configure-kubectl.sh
```

## Troubleshooting

### K3s not starting
```bash
# Check k3s status
sudo systemctl status k3s

# Restart k3s
sudo systemctl restart k3s

# Check logs
sudo journalctl -u k3s
```

### kubectl connection issues
```bash
# Reconfigure kubectl
.devcontainer/configure-kubectl.sh

# Check kubeconfig
kubectl config view
```

### Container resources
The container runs in privileged mode to allow K3s to function properly. If you experience issues, ensure Docker Desktop has sufficient resources allocated (4GB+ RAM recommended).

## Development Workflow

1. **Create your Kubernetes manifests** in the workspace
2. **Apply them to the cluster**: `kubectl apply -f your-manifest.yaml`
3. **Test your application** using port forwarding or NodePort services
4. **Monitor with kubectl** or the VS Code Kubernetes extension
5. **Iterate quickly** - the cluster persists across container restarts

## Next Steps

- Deploy your Fluent Bit configuration
- Create high-volume test workloads
- Monitor log processing performance
- Test different Fluent Bit output configurations
