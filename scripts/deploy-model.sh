#!/bin/bash

# AI Model Deployment Script for OpenShift
# This script handles the deployment of AI models with proper error handling,
# resource validation, and progress monitoring

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/tmp/model-deployment-$(date +%Y%m%d-%H%M%S).log"

# Default values
MODEL_TYPE="llama-7b"
NAMESPACE="ai-models"
ENVIRONMENT="staging"
DRY_RUN="false"
VERBOSE="false"
TIMEOUT="600"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy AI models to OpenShift cluster with comprehensive validation and monitoring.

OPTIONS:
    -m, --model-type TYPE      Model type to deploy (llama-7b, llama-13b, stable-diffusion)
    -n, --namespace NAME       Kubernetes namespace (default: ai-models)
    -e, --environment ENV      Environment (dev, staging, production)
    -d, --dry-run             Perform dry run without actual deployment
    -v, --verbose             Enable verbose output
    -t, --timeout SECONDS    Deployment timeout in seconds (default: 600)
    -h, --help               Show this help message

EXAMPLES:
    # Deploy LLaMA 7B to staging
    $0 -m llama-7b -e staging
    
    # Deploy Stable Diffusion to production with verbose output
    $0 -m stable-diffusion -e production -v
    
    # Perform dry run
    $0 -m llama-13b -d

SUPPORTED MODELS:
    - llama-7b: LLaMA 7B parameter model
    - llama-13b: LLaMA 13B parameter model  
    - llama-70b: LLaMA 70B parameter model
    - stable-diffusion: Stable Diffusion XL
    - code-llama: Code LLaMA model

EOF
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model-type)
            MODEL_TYPE="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check required tools
    local required_tools=("oc" "kubectl" "helm" "jq")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is not installed or not in PATH"
            exit 1
        fi
    done
    
    # Check OpenShift connection
    if ! oc whoami &> /dev/null; then
        log_error "Not logged in to OpenShift cluster"
        log_info "Please run: oc login <server-url>"
        exit 1
    fi
    
    # Validate model type
    local valid_models=("llama-7b" "llama-13b" "llama-70b" "stable-diffusion" "code-llama")
    if [[ ! " ${valid_models[@]} " =~ " ${MODEL_TYPE} " ]]; then
        log_error "Invalid model type: $MODEL_TYPE"
        log_info "Valid models: ${valid_models[*]}"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Check resource availability
check_resources() {
    log_info "Checking cluster resources..."
    
    local gpu_nodes
    gpu_nodes=$(oc get nodes -l accelerator=h100 --no-headers | wc -l)
    
    if [[ $gpu_nodes -eq 0 ]]; then
        log_error "No GPU nodes available in cluster"
        exit 1
    fi
    
    log_info "Found $gpu_nodes GPU nodes"
    
    # Check GPU availability
    local available_gpus
    available_gpus=$(oc describe nodes -l accelerator=h100 | grep "nvidia.com/gpu" | grep -E "Allocatable|Allocated resources" -A1 | grep nvidia.com/gpu | awk '{sum+=$2} END {print sum}')
    
    if [[ ${available_gpus:-0} -eq 0 ]]; then
        log_warning "No GPUs currently available"
    else
        log_info "Available GPUs: $available_gpus"
    fi
    
    # Check storage
    local storage_classes
    storage_classes=$(oc get storageclass --no-headers | wc -l)
    if [[ $storage_classes -eq 0 ]]; then
        log_error "No storage classes available"
        exit 1
    fi
    
    log_success "Resource check completed"
}

# Create or update namespace
setup_namespace() {
    log_info "Setting up namespace: $NAMESPACE"
    
    if oc get namespace "$NAMESPACE" &> /dev/null; then
        log_info "Namespace $NAMESPACE already exists"
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would create namespace: $NAMESPACE"
        else
            oc create namespace "$NAMESPACE"
            log_success "Created namespace: $NAMESPACE"
        fi
    fi
    
    # Set up RBAC
    log_info "Configuring RBAC..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would apply RBAC configurations"
    else
        oc apply -f "$PROJECT_DIR/deployments/openshift/rbac/" -n "$NAMESPACE"
        log_success "RBAC configured"
    fi
}

# Deploy model using Helm
deploy_model() {
    log_info "Deploying model: $MODEL_TYPE"
    
    local helm_release="$MODEL_TYPE-$ENVIRONMENT"
    local values_file="$PROJECT_DIR/deployments/helm/ai-models/values-$ENVIRONMENT.yaml"
    
    # Check if values file exists
    if [[ ! -f "$values_file" ]]; then
        log_warning "Environment-specific values file not found: $values_file"
        values_file="$PROJECT_DIR/deployments/helm/ai-models/values.yaml"
    fi
    
    local helm_args=(
        "upgrade" "--install" "$helm_release"
        "$PROJECT_DIR/deployments/helm/ai-models/"
        "--namespace" "$NAMESPACE"
        "--values" "$values_file"
        "--timeout" "${TIMEOUT}s"
        "--wait"
    )
    
    # Model-specific configurations
    case "$MODEL_TYPE" in
        "llama-7b")
            helm_args+=("--set" "llama.enabled=true")
            helm_args+=("--set" "llama.model.size=7b")
            helm_args+=("--set" "stableDiffusion.enabled=false")
            ;;
        "llama-13b")
            helm_args+=("--set" "llama.enabled=true")
            helm_args+=("--set" "llama.model.size=13b")
            helm_args+=("--set" "stableDiffusion.enabled=false")
            ;;
        "llama-70b")
            helm_args+=("--set" "llama.enabled=true")
            helm_args+=("--set" "llama.model.size=70b")
            helm_args+=("--set" "stableDiffusion.enabled=false")
            helm_args+=("--set" "llama.resources.requests.memory=128Gi")
            helm_args+=("--set" "llama.resources.requests.nvidia\.com/gpu=4")
            ;;
        "stable-diffusion")
            helm_args+=("--set" "llama.enabled=false")
            helm_args+=("--set" "stableDiffusion.enabled=true")
            ;;
        "code-llama")
            helm_args+=("--set" "llama.enabled=true")
            helm_args+=("--set" "llama.model.size=7b")
            helm_args+=("--set" "llama.model.variant=code")
            helm_args+=("--set" "stableDiffusion.enabled=false")
            ;;
    esac
    
    if [[ "$DRY_RUN" == "true" ]]; then
        helm_args+=("--dry-run")
        log_info "[DRY RUN] Helm deployment command:"
        log_info "helm ${helm_args[*]}"
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        helm_args+=("--debug")
    fi
    
    if helm "${helm_args[@]}"; then
        log_success "Model deployment completed"
    else
        log_error "Model deployment failed"
        exit 1
    fi
}

# Monitor deployment progress
monitor_deployment() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Skipping deployment monitoring"
        return 0
    fi
    
    log_info "Monitoring deployment progress..."
    
    local deployment_name
    case "$MODEL_TYPE" in
        "llama-"*)
            deployment_name="llama-7b-inference"
            ;;
        "stable-diffusion")
            deployment_name="stable-diffusion-xl"
            ;;
        "code-llama")
            deployment_name="llama-7b-inference"
            ;;
    esac
    
    # Wait for deployment to be ready
    log_info "Waiting for deployment $deployment_name to be ready..."
    if oc rollout status deployment/"$deployment_name" -n "$NAMESPACE" --timeout="${TIMEOUT}s"; then
        log_success "Deployment $deployment_name is ready"
    else
        log_error "Deployment $deployment_name failed to become ready within timeout"
        
        # Show logs for debugging
        log_info "Showing pod logs for debugging:"
        oc logs -l app="$deployment_name" -n "$NAMESPACE" --tail=50
        exit 1
    fi
    
    # Check service endpoints
    log_info "Verifying service endpoints..."
    local service_name="${deployment_name}-service"
    if oc get service "$service_name" -n "$NAMESPACE" &> /dev/null; then
        local endpoint_count
        endpoint_count=$(oc get endpoints "$service_name" -n "$NAMESPACE" -o json | jq '.subsets[0].addresses | length')
        if [[ ${endpoint_count:-0} -gt 0 ]]; then
            log_success "Service endpoints are healthy ($endpoint_count endpoints)"
        else
            log_warning "No healthy endpoints found for service $service_name"
        fi
    else
        log_warning "Service $service_name not found"
    fi
}

# Run health checks
health_check() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Skipping health checks"
        return 0
    fi
    
    log_info "Running health checks..."
    
    local route_name
    case "$MODEL_TYPE" in
        "llama-"*|"code-llama")
            route_name="llama-7b-route"
            ;;
        "stable-diffusion")
            route_name="stable-diffusion-route"
            ;;
    esac
    
    if oc get route "$route_name" -n "$NAMESPACE" &> /dev/null; then
        local route_host
        route_host=$(oc get route "$route_name" -n "$NAMESPACE" -o jsonpath='{.spec.host}')
        
        log_info "Testing health endpoint: https://$route_host/health"
        if curl -f -s "https://$route_host/health" > /dev/null; then
            log_success "Health check passed"
        else
            log_error "Health check failed"
            exit 1
        fi
    else
        log_warning "Route $route_name not found, skipping external health check"
    fi
}

# Cleanup function
cleanup() {
    if [[ -f "$LOG_FILE" ]]; then
        log_info "Deployment log saved to: $LOG_FILE"
    fi
}

# Main execution
main() {
    trap cleanup EXIT
    
    log_info "Starting AI model deployment"
    log_info "Model: $MODEL_TYPE, Environment: $ENVIRONMENT, Namespace: $NAMESPACE"
    log_info "Dry run: $DRY_RUN, Verbose: $VERBOSE"
    
    check_prerequisites
    check_resources
    setup_namespace
    deploy_model
    monitor_deployment
    health_check
    
    log_success "Deployment completed successfully!"
}

# Execute main function
main "$@"