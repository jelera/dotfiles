#!/usr/bin/env bash
# Kubernetes helper functions

# Quick context switch with fzf
kctx() {
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl not installed. Install with: mise install kubectl@latest"
        return 1
    fi

    local context
    if command -v kubectx &> /dev/null && command -v fzf &> /dev/null; then
        context=$(kubectx | fzf --height 40% --reverse --header "Select Kubernetes Context")
        [[ -n "$context" ]] && kubectx "$context"
    elif command -v fzf &> /dev/null; then
        context=$(kubectl config get-contexts -o name | fzf --height 40% --reverse --header "Select Kubernetes Context")
        [[ -n "$context" ]] && kubectl config use-context "$context"
    else
        kubectl config get-contexts
        echo "Install fzf for interactive selection: mise install fzf@latest"
    fi
}

# Quick namespace switch with fzf
kns() {
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl not installed. Install with: mise install kubectl@latest"
        return 1
    fi

    local namespace
    if command -v kubens &> /dev/null && command -v fzf &> /dev/null; then
        namespace=$(kubens | fzf --height 40% --reverse --header "Select Namespace")
        [[ -n "$namespace" ]] && kubens "$namespace"
    elif command -v fzf &> /dev/null; then
        namespace=$(kubectl get namespaces -o name | cut -d/ -f2 | fzf --height 40% --reverse --header "Select Namespace")
        [[ -n "$namespace" ]] && kubectl config set-context --current --namespace="$namespace"
    else
        kubectl get namespaces
        echo "Install fzf for interactive selection: mise install fzf@latest"
    fi
}

# Get pod logs with fzf selection
klogs() {
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl not installed. Install with: mise install kubectl@latest"
        return 1
    fi

    if command -v fzf &> /dev/null; then
        local pod=$(kubectl get pods -o name | fzf --height 40% --reverse --header "Select Pod for Logs")
        if [[ -n "$pod" ]]; then
            # Check if pod has multiple containers
            local containers=$(kubectl get "$pod" -o jsonpath='{.spec.containers[*].name}' | wc -w)
            if [[ $containers -gt 1 ]]; then
                local container=$(kubectl get "$pod" -o jsonpath='{.spec.containers[*].name}' | tr ' ' '\n' | fzf --height 40% --reverse --header "Select Container")
                [[ -n "$container" ]] && kubectl logs -f "$pod" -c "$container"
            else
                kubectl logs -f "$pod"
            fi
        fi
    else
        echo "fzf not installed. Install with: mise install fzf@latest"
        kubectl get pods
    fi
}

# Exec into pod with fzf selection
kexec() {
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl not installed. Install with: mise install kubectl@latest"
        return 1
    fi

    local shell="${1:-/bin/bash}"

    if command -v fzf &> /dev/null; then
        local pod=$(kubectl get pods -o name | fzf --height 40% --reverse --header "Select Pod to Exec Into")
        if [[ -n "$pod" ]]; then
            # Check if pod has multiple containers
            local containers=$(kubectl get "$pod" -o jsonpath='{.spec.containers[*].name}' | wc -w)
            if [[ $containers -gt 1 ]]; then
                local container=$(kubectl get "$pod" -o jsonpath='{.spec.containers[*].name}' | tr ' ' '\n' | fzf --height 40% --reverse --header "Select Container")
                [[ -n "$container" ]] && kubectl exec -it "$pod" -c "$container" -- "$shell"
            else
                kubectl exec -it "$pod" -- "$shell"
            fi
        fi
    else
        echo "fzf not installed. Install with: mise install fzf@latest"
        kubectl get pods
    fi
}

# Describe resource with fzf selection
kdesc() {
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl not installed. Install with: mise install kubectl@latest"
        return 1
    fi

    if ! command -v fzf &> /dev/null; then
        echo "fzf not installed. Install with: mise install fzf@latest"
        return 1
    fi

    local resource_type="${1:-pod}"
    local resource=$(kubectl get "$resource_type" -o name | fzf --height 40% --reverse --header "Select $resource_type to Describe")
    [[ -n "$resource" ]] && kubectl describe "$resource"
}

# Delete resource with fzf selection
kdel() {
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl not installed. Install with: mise install kubectl@latest"
        return 1
    fi

    if ! command -v fzf &> /dev/null; then
        echo "fzf not installed. Install with: mise install fzf@latest"
        return 1
    fi

    local resource_type="${1:-pod}"
    local resource=$(kubectl get "$resource_type" -o name | fzf --height 40% --reverse --header "Select $resource_type to Delete (Ctrl-C to cancel)")

    if [[ -n "$resource" ]]; then
        echo "About to delete: $resource"
        read -p "Are you sure? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl delete "$resource"
        else
            echo "Cancelled"
        fi
    fi
}

# Port-forward with fzf selection
kport() {
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl not installed. Install with: mise install kubectl@latest"
        return 1
    fi

    if ! command -v fzf &> /dev/null; then
        echo "fzf not installed. Install with: mise install fzf@latest"
        return 1
    fi

    local local_port="${1:-8080}"
    local remote_port="${2:-$local_port}"
    local pod=$(kubectl get pods -o name | fzf --height 40% --reverse --header "Select Pod for Port-Forward")

    if [[ -n "$pod" ]]; then
        echo "Port-forwarding $local_port:$remote_port to $pod"
        kubectl port-forward "$pod" "$local_port:$remote_port"
    fi
}

# Quick pod status overview
kpods() {
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl not installed. Install with: mise install kubectl@latest"
        return 1
    fi

    kubectl get pods --all-namespaces -o wide
}

# Show pod resource usage
ktop() {
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl not installed. Install with: mise install kubectl@latest"
        return 1
    fi

    kubectl top pods --all-namespaces
}
