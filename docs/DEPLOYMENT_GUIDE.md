# MLOps Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying AI models to OpenShift environments with enterprise-grade security, monitoring, and scalability.

## Prerequisites

### Required Tools
- OpenShift CLI (oc) v4.13+
- Kubernetes CLI (kubectl) v1.28+
- Helm v3.12+
- Ansible v2.14+ (for infrastructure setup)
- Terraform v1.0+ (for cloud resources)
- Docker or Podman

### Access Requirements
- OpenShift cluster with GPU nodes (H100 recommended)
- Cluster administrator privileges
- Container registry access
- Monitoring stack (Prometheus/Grafana) installed

## Quick Start

### 1. Environment Setup

```bash
# Clone the repository
git clone <repository-url>
cd mlops-portfolio

# Make deployment script executable
chmod +x scripts/deploy-model.sh

# Login to OpenShift
oc login <your-openshift-server>
```

### 2. Deploy Your First Model

```bash
# Deploy LLaMA 7B to staging environment
./scripts/deploy-model.sh -m llama-7b -e staging

# Check deployment status
oc get pods -n ai-models-staging
```

### 3. Access the Dashboard

```bash
# Get the dashboard URL
oc get route ai-dashboard -n ai-models-staging

# Open in browser
open https://$(oc get route ai-dashboard -n ai-models-staging -o jsonpath='{.spec.host}')
```

## Detailed Deployment Steps

### Infrastructure Deployment

#### 1. Terraform Infrastructure

```bash
cd infrastructure/terraform/gpu-cluster

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="vars/production.tfvars"

# Apply infrastructure
terraform apply -var-file="vars/production.tfvars"
```

#### 2. Ansible GPU Setup

```bash
# Configure GPU worker nodes
cd infrastructure/ansible
ansible-playbook -i inventory/production gpu-setup.yml
```

### Application Deployment

#### 1. Namespace Preparation

```bash
# Create namespace
oc new-project ai-models-production

# Apply RBAC configurations
oc apply -f deployments/openshift/rbac/ -n ai-models-production
```

#### 2. Storage Setup

```bash
# Create persistent volumes for model storage
oc apply -f deployments/openshift/storage/ -n ai-models-production

# Verify storage
oc get pvc -n ai-models-production
```

#### 3. Model Deployment

Using Helm (Recommended):
```bash
helm install ai-models deployments/helm/ai-models/ \
  --namespace ai-models-production \
  --values deployments/helm/ai-models/values-production.yaml
```

Using OpenShift Templates:
```bash
oc process -f deployments/openshift/llama-deployment.yaml \
  -p ENVIRONMENT=production | oc apply -f -
```

### Monitoring Setup

#### 1. Prometheus Configuration

```bash
# Deploy Prometheus with AI model monitoring
oc apply -f monitoring/prometheus/ -n monitoring

# Verify metrics collection
curl -s http://prometheus-route/api/v1/targets
```

#### 2. Grafana Dashboards

```bash
# Import AI model dashboards
oc create configmap grafana-dashboards \
  --from-file=monitoring/grafana/dashboards/ \
  -n monitoring
```

## Configuration Management

### Environment-Specific Values

#### Staging Environment
- **Replicas**: 1-2 per model
- **Resources**: Reduced GPU allocation
- **Storage**: 100GB per model
- **Monitoring**: Basic metrics

#### Production Environment
- **Replicas**: 3-5 per model for HA
- **Resources**: Full GPU allocation
- **Storage**: 500GB+ per model
- **Monitoring**: Comprehensive alerting

### Security Configurations

#### OpenShift Security Context Constraints

```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: ai-models-scc
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowPrivilegedContainer: false
allowedCapabilities: null
defaultAddCapabilities: null
requiredDropCapabilities:
- KILL
- MKNOD
- SETUID
- SETGID
runAsUser:
  type: MustRunAsRange
  uidRangeMin: 1000
  uidRangeMax: 65535
```

#### Network Policies

```bash
# Apply network isolation
oc apply -f deployments/openshift/network-policies/ -n ai-models-production
```

## Performance Optimization

### GPU Memory Management

```yaml
# Optimized GPU configuration for large models
resources:
  requests:
    nvidia.com/gpu: 1
    memory: "32Gi"
  limits:
    nvidia.com/gpu: 1
    memory: "48Gi"
env:
- name: PYTORCH_CUDA_ALLOC_CONF
  value: "max_split_size_mb:512"
- name: CUDA_LAUNCH_BLOCKING
  value: "1"
```

### Model Loading Strategies

#### 1. Model Quantization
- **INT8**: 75% memory reduction, minimal accuracy loss
- **INT4**: 90% memory reduction, moderate accuracy loss
- **FP16**: 50% memory reduction, no accuracy loss

#### 2. Model Sharding
For large models (70B+), implement tensor parallelism:

```yaml
env:
- name: TENSOR_PARALLEL_SIZE
  value: "4"  # Split across 4 GPUs
- name: PIPELINE_PARALLEL_SIZE
  value: "2"  # Pipeline stages
```

## Troubleshooting

### Common Issues

#### 1. GPU Not Detected
```bash
# Check GPU nodes
oc describe nodes -l accelerator=h100

# Verify device plugin
oc logs -n kube-system -l name=nvidia-device-plugin-ds
```

#### 2. Out of Memory Errors
```bash
# Check GPU memory usage
oc exec -it <pod-name> -- nvidia-smi

# Reduce batch size or enable gradient checkpointing
kubectl patch deployment llama-7b-inference -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"llama-inference","env":[{"name":"BATCH_SIZE","value":"1"}]}]}}}}'
```

#### 3. Model Loading Timeouts
```bash
# Increase timeout values
kubectl patch deployment llama-7b-inference -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"llama-inference","livenessProbe":{"initialDelaySeconds":300}}]}}}}'
```

### Debugging Commands

```bash
# View pod logs
oc logs -f deployment/llama-7b-inference -n ai-models-production

# Check resource usage
oc top pods -n ai-models-production

# Describe problematic pods
oc describe pod <pod-name> -n ai-models-production

# Port forward for direct access
oc port-forward service/llama-7b-service 8080:80 -n ai-models-production
```

## Scaling and Load Balancing

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: llama-7b-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: llama-7b-inference
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Load Testing

```bash
# Install load testing tools
pip install locust

# Run load test
locust -f scripts/load-test.py --host=https://your-model-endpoint
```

## Backup and Disaster Recovery

### Model Backup Strategy

```bash
# Create model backup job
oc create job model-backup-$(date +%Y%m%d) \
  --from=cronjob/model-backup-cron -n ai-models-production

# Verify backup completion
oc logs job/model-backup-$(date +%Y%m%d) -n ai-models-production
```

### Recovery Procedures

1. **Database Recovery**: Restore from latest backup
2. **Model Recovery**: Pull from model registry
3. **Configuration Recovery**: Apply from Git repository

## Cost Optimization

### Resource Management

- **Spot Instances**: Use for non-critical workloads
- **Mixed Instance Types**: Combine GPU and CPU nodes
- **Auto-scaling**: Scale down during low usage periods

### Cost Monitoring

```bash
# View resource costs
oc get nodes -o custom-columns="NAME:.metadata.name,INSTANCE:.metadata.labels.node\.kubernetes\.io/instance-type,COST:.metadata.annotations.cost-per-hour"
```

## Security Best Practices

1. **Image Scanning**: Scan all container images
2. **Network Segmentation**: Implement network policies
3. **RBAC**: Principle of least privilege
4. **Secrets Management**: Use sealed secrets or external secret management
5. **Audit Logging**: Enable comprehensive audit trails

## Compliance

### SOC 2 Compliance
- Encryption at rest and in transit
- Access control and monitoring
- Regular security assessments

### GDPR Compliance
- Data minimization practices
- Right to deletion implementation
- Privacy by design principles

## Support and Maintenance

### Regular Maintenance Tasks

- **Weekly**: Update security patches
- **Monthly**: Performance optimization review
- **Quarterly**: Disaster recovery testing

### Monitoring Alerts

Critical alerts are configured for:
- Model service availability
- GPU utilization thresholds
- Error rate limits
- Security violations

For additional support, refer to the troubleshooting section or contact the MLOps team.