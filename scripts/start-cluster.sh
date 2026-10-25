#!/bin/bash
# Start the ShopFlow Minikube cluster after a PC restart and repair the known
# cold-start problems: reset WSL/node DNS, then restart app pods that
# crash-looped because DNS was not ready (see docs/incident notes).
set -u
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
minikube start --driver=docker --cpus=2 --memory=3072
minikube ssh -- "echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf" > /dev/null
echo "Waiting 120s for DNS and the control plane to settle..."
sleep 60
kubectl wait --for=condition=ready pod/postgres-0 -n shopflow --timeout=300s
kubectl delete pod -n shopflow -l app.kubernetes.io/name=backend
kubectl delete pod -n shopflow -l app.kubernetes.io/name=frontend
kubectl get pods -A
