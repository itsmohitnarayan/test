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

