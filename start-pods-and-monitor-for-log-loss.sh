#!/bin/bash

kubectl get nodes
kubectl cluster-info

# (re)start fluent-bit
kubectl apply -f k8s-manifests/fluent-bit.yaml
kubectl rollout restart daemonset/fluent-bit -n logging
kubectl rollout status daemonset/fluent-bit -n logging

# (re)start log generators
kubectl apply -f k8s-manifests/log-generators.yaml
kubectl rollout restart deployment/high-volume-logger -n default

sudo rm -f /var/fluent-bit-logs/processed-logs.log
sudo touch /var/fluent-bit-logs/processed-logs.log

# Monitor continuously for log loss
# When there's not log loss, log sequences will increment by 1, and every sequence will have a count of 1000
while true; do
  echo ""
  echo "[$(date)] Count of processed log sequences..."
  cat /var/fluent-bit-logs/processed-logs.log | sort | uniq -c | tail -n 20
  sleep 5
done
