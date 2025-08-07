#!/bin/bash
# Quick setup script for accessing k3s cluster

echo "🔧 Configuring kubectl access to k3s cluster..."

# Create .kube directory if it doesn't exist
mkdir -p ~/.kube

# Copy kubeconfig if running with docker-compose
if [ -f "/workspaces/fluent-bit-and-k8s/.devcontainer/k3s-config/kubeconfig.yaml" ]; then
    cp /workspaces/fluent-bit-and-k8s/.devcontainer/k3s-config/kubeconfig.yaml ~/.kube/config
    chmod 600 ~/.kube/config
    echo "✅ Kubeconfig copied from docker-compose setup"
elif [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    chmod 600 ~/.kube/config
    # Update server URL to use localhost
    sed -i 's/127.0.0.1/localhost/g' ~/.kube/config
    echo "✅ Kubeconfig copied from k3s installation"
fi

# Test connection
if kubectl cluster-info &> /dev/null; then
    echo "🎉 Successfully connected to k3s cluster!"
    kubectl get nodes
else
    echo "❌ Could not connect to k3s cluster. Please check if k3s is running."
    exit 1
fi
