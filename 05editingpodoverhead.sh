#!/bin/bash
set -e

echo "Setting up Kata Runtime and Lab Environment..."
cd /root
# Navigate to kata-deploy runtimeclasses directory
echo "Creating RuntimeClass..."
cd kata-containers/tools/packaging/kata-deploy/runtimeclasses

# Create kata-fc.yaml
cat > kata-fc.yaml << 'EOF'
---
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
    name: kata-fc
handler: kata-fc
overhead:
    podFixed:
        memory: "100Mi"
        cpu: "100m"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"
EOF

# Apply the RuntimeClass
kubectl apply -f kata-fc.yaml

# Get the RuntimeClass configuration
kubectl get runtimeclass kata-fc -o yaml

# Navigate to lab templates directory
echo "Preparing lab templates..."
cd "/root/lab-templates"

# Check if template files exist
for template in lab-pod-template.yaml lab-service-template.yaml lab-ingress-template.yaml lab-networkpolicy-template.yaml; do
    if [[ ! -f "$template" ]]; then
        echo "Error: $template not found in $PWD"
        exit 1
    fi
done

# Fix the labId format in template files
sed -i 's/labId: {labId}/labId: "{labId}"/g' lab-pod-template.yaml lab-service-template.yaml lab-ingress-template.yaml lab-networkpolicy-template.yaml

# Set LAB_ID variable
LAB_ID=1

# Apply all templates with LAB_ID substitution
echo "Applying lab templates with LAB_ID=$LAB_ID..."
sed "s/{labId}/$LAB_ID/g" lab-pod-template.yaml | kubectl apply -f -
sed "s/{labId}/$LAB_ID/g" lab-service-template.yaml | kubectl apply -f -
sed "s/{labId}/$LAB_ID/g" lab-ingress-template.yaml | kubectl apply -f -
sed "s/{labId}/$LAB_ID/g" lab-networkpolicy-template.yaml | kubectl apply -f -

# Watch pods for a limited time
echo "Watching pods for 30 seconds..."
timeout 30s kubectl get pods -w || true

echo ""
echo "Lab URLs:"
echo "VSCode: http://vscode-$LAB_ID.mohit.fixcloud.shop/"
echo "Terminal: http://terminal-$LAB_ID.mohit.fixcloud.shop/"

echo ""
echo "Checking cluster resources..."
echo "kubectl describe node nodename"

echo ""
echo "Current resources:"
kubectl get pods
kubectl get svc
kubectl get ingress
kubectl get networkpolicy

echo ""
echo "To clean up, run:"
echo "kubectl delete pod,svc,ingress,networkpolicy -l app=lab"
