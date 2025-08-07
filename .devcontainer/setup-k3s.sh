#!/bin/bash
set -e

echo "🚀 Setting up K3s development environment..."

# Update package list
sudo apt-get update

# Install additional tools that might be useful
sudo apt-get install -y \
    curl \
    wget \
    jq \
    htop \
    net-tools \
    dnsutils

# Download and install k3s
echo "📦 Installing K3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --disable traefik --disable servicelb --disable metrics-server" sh -

# Start K3s server directly in the background (no systemd)
echo "🚀 Starting K3s server..."
sudo touch /var/log/k3s.log
sudo chown -R vscode:vscode /var/log/k3s.log
nohup sudo k3s server \
    --write-kubeconfig-mode 644 \
    --disable traefik \
    --disable servicelb \
    --disable metrics-server \
    --data-dir /var/lib/rancher/k3s \
    > /var/log/k3s.log 2>&1 &

# Wait for the node to be ready
timeout=60
while [ $timeout -gt 0 ]; do
    if sudo k3s kubectl get nodes | grep -q "Ready"; then
        echo "✅ K3s node is ready!"
        break
    fi
    echo "Waiting for K3s node to be ready... ($timeout seconds remaining)"
    sleep 5
    timeout=$((timeout - 5))
done

if [ $timeout -le 0 ]; then
    echo "❌ Timeout waiting for K3s to be ready"
    exit 1
fi

# Set up kubeconfig for the vscode user
echo "🔧 Setting up kubeconfig..."
mkdir -p /home/vscode/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vscode/.kube/config
sudo chown vscode:vscode /home/vscode/.kube/config
chmod 600 /home/vscode/.kube/config

# Update the kubeconfig to use localhost instead of the internal IP
sed -i 's/127.0.0.1/localhost/g' /home/vscode/.kube/config

# Create kubectl alias
echo "alias k='kubectl'" >> /home/vscode/.bashrc
echo "alias k='kubectl'" >> /home/vscode/.zshrc

# Install Helm (if not already installed by feature)
if ! command -v helm &> /dev/null; then
    echo "📦 Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Create a default namespace for development
kubectl create namespace dev || true

# Display cluster info
echo "🎉 K3s setup complete!"
echo ""
echo "Cluster Information:"
kubectl cluster-info
echo ""
echo "Nodes:"
kubectl get nodes -o wide
echo ""
echo "Available namespaces:"
kubectl get namespaces
echo ""
echo "🔧 Useful commands:"
echo "  kubectl get nodes          - Check cluster nodes"
echo "  kubectl get pods -A        - List all pods"
echo "  kubectl get svc -A         - List all services"
echo "  kubectl create namespace <name>  - Create a new namespace"
echo ""
echo "💡 The 'dev' namespace has been created for your development work."
echo "💡 Use 'kubectl config set-context --current --namespace=dev' to set it as default."
