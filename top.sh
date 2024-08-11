#!/bin/bash

# Array to hold the names of your clusters
clusters=("cluster1" "cluster2" "cluster3") # Add your cluster names here

max_memory=0
max_memory_pod=""
max_memory_cluster=""
max_memory_namespace=""

# Function to convert memory to MiB
convert_to_mi() {
    local mem_value=$1
    if [[ $mem_value == *"Mi"* ]]; then
        echo "${mem_value//Mi/}"  # Remove "Mi" and return the value
    elif [[ $mem_value == *"m"* ]]; then
        echo "0"  # Treat milli as 0 MiB for this context
    else
        echo "$mem_value"  # Return the value as is
    fi
}

# Loop through each cluster
for cluster in "${clusters[@]}"; do
    echo "Switching to cluster: $cluster"
    kubectl config use-context "$cluster"

    # Check if Metrics Server is working
    echo "Checking pod metrics in cluster: $cluster"
    metrics_output=$(kubectl top pods --all-namespaces 2>&1)

    # Check if there was an error retrieving metrics
    if [[ "$metrics_output" == *"error"* ]]; then
        echo "Error retrieving metrics: $metrics_output"
        continue
    fi

    # Get the pod with the maximum memory usage
    pod_info=$(echo "$metrics_output" | tail -n +2 | sort -k4 -h | tail -n 1)

    # Extract memory usage and pod name
    pod_memory=$(echo "$pod_info" | awk '{print $4}')  # Change to $4 for MEMORY(bytes)
    pod_name=$(echo "$pod_info" | awk '{print $2}')
    namespace=$(echo "$pod_info" | awk '{print $1}')

    # Convert memory to MiB
    pod_memory_mi=$(convert_to_mi "$pod_memory")

    # Check if this pod uses more memory than the current maximum
    if [[ "$pod_memory_mi" =~ ^[0-9]+$ ]] && [[ "$pod_memory_mi" -gt "$max_memory" ]]; then
        max_memory=$pod_memory_mi
        max_memory_pod=$pod_name
        max_memory_cluster=$cluster
        max_memory_namespace=$namespace
    fi
done

# Output the pod with the maximum memory usage
if [[ -n "$max_memory_pod" ]]; then
    echo "Pod with maximum memory usage across all clusters:"
    echo "Cluster: $max_memory_cluster"
    echo "Namespace: $max_memory_namespace"
    echo "Pod Name: $max_memory_pod"
    echo "Memory Usage: ${max_memory}Mi"
else
    echo "No pods found in any cluster."
fi
