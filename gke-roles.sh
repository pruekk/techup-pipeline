#!/bin/bash
# gke-role.sh
# This script configures Kubernetes RBAC for GKE students.
# It grants namespace-specific developer access, viewer access to shared namespaces,
# and the ability to list all namespaces.

# This script is compatible with Bash versions 3.2.x and newer.

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
# For Bash 3.2 compatibility, we use two indexed arrays instead of an associative array.
# Ensure the order of elements in both arrays matches.
student_namespaces=(
    "student-ax"
    "student-babe"
    "student-bank"
    "student-charlie"
    "student-neung"
)

student_emails=(
    "nuthaponm79@gmail.com"
    "panyawit.sea@gmail.com"
    "bankthanapat@gmail.com"
    "jirayu.supasil.edu@gmail.com"
    "neung0511@gmail.com"
)

# Ensure the number of elements in both arrays is the same
if [ "${#student_namespaces[@]}" -ne "${#student_emails[@]}" ]; then
    echo "Error: Mismatch between number of student namespaces and emails. Please check configuration." >&2
    exit 1
fi

SHARED_VIEW_NAMESPACES=("monitoring" "cicd-pipeline-alpha")

echo "--- Starting Kubernetes RBAC Configuration ---"

# --- PART 1: FULL MANAGEMENT ON OWN NAMESPACE (Requirement 1) ---
# For each student, create a Role and a RoleBinding in their dedicated namespace.
# The Role defines developer permissions (create, get, list, watch, update, patch, delete)
# for common Kubernetes resources within that specific namespace.

echo "1. Configuring full management for students in their own namespaces (e.g., student-ax)..."
for i in "${!student_namespaces[@]}"; do
    namespace="${student_namespaces[$i]}"
    email="${student_emails[$i]}"
    role_name="${namespace}-developer-role"
    binding_name="${namespace}-developer-binding"

    echo "  - Creating Role '${role_name}' and RoleBinding '${binding_name}' for ${email} in namespace '${namespace}'"

    # Create Role YAML (defines permissions within the namespace)
    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${namespace}
  name: ${role_name}
rules:
- apiGroups: [""] # Core API group for resources like pods, services, configmaps, secrets
  resources: ["pods", "services", "deployments", "configmaps", "secrets", "persistentvolumeclaims", "events", "serviceaccounts"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"] # API group for deployments, statefulsets, etc.
  resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["batch"] # API group for jobs, cronjobs
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"] # API group for ingresses, network policies
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["policy"] # API group for pod disruption budgets
  resources: ["poddisruptionbudgets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["autoscaling"] # API group for horizontal pod autoscalers
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

    # Create RoleBinding YAML (binds the user to the Role in their namespace)
    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${binding_name}
  namespace: ${namespace}
subjects:
- kind: User
  name: ${email}
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: ${role_name}
  apiGroup: rbac.authorization.k8s.io
EOF
done
echo "   -> Completed full management setup for student namespaces."
echo ""

# --- PART 2: VIEW ONLY ON SHARED NAMESPACES (Requirement 2) ---
# For each student, create a RoleBinding in the 'monitoring' and 'cicd-pipeline-alpha' namespaces.
# This binds them to the predefined 'view' ClusterRole, granting read-only access to common resources.

echo "2. Configuring view-only access for shared namespaces: ${SHARED_VIEW_NAMESPACES[*]}..."
for namespace in "${SHARED_VIEW_NAMESPACES[@]}"; do
    echo "  Processing shared namespace: ${namespace}"
    for i in "${!student_namespaces[@]}"; do
        student_namespace_prefix="${student_namespaces[$i]}" # This variable is not used in the loop below
        email="${student_emails[$i]}"
        binding_name="${student_namespace_prefix}-${namespace}-viewer-binding" # e.g., student-ax-monitoring-viewer-binding

        echo "    - Creating RoleBinding '${binding_name}' for user '${email}' in namespace '${namespace}'"

        cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${binding_name}
  namespace: ${namespace}
subjects:
- kind: User
  name: ${email}
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view # Binds to the predefined 'view' ClusterRole (read-only)
  apiGroup: rbac.authorization.k8s.io
EOF
    done
done
echo "   -> Completed view-only access setup for shared namespaces."
echo ""

# --- PART 3: ALLOW LISTING ALL NAMESPACES (Requirement 4, part 1) ---
# Create a custom ClusterRole that only allows 'get', 'list', and 'watch' permissions
# on the 'namespaces' resource. Then, create a ClusterRoleBinding for each student
# to this new ClusterRole. This is a ClusterRole because 'namespaces' is a cluster-scoped resource.

echo "3. Configuring ability for students to list all namespaces ('kubectl get namespace')..."

# Create a custom ClusterRole
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-lister # A new ClusterRole for just listing namespaces
rules:
- apiGroups: [""] # Core API group for 'namespaces' resource
  resources: ["namespaces"]
  verbs: ["get", "list", "watch"]
EOF
echo "  - ClusterRole 'namespace-lister' created."

# Create ClusterRoleBinding for each student to the namespace-lister ClusterRole
for i in "${!student_namespaces[@]}"; do
    student_namespace_prefix="${student_namespaces[$i]}" # This variable is not used in the loop below
    email="${student_emails[$i]}"
    binding_name="${student_namespace_prefix}-namespace-lister-binding"

    echo "  - Creating ClusterRoleBinding '${binding_name}' for user '${email}'"

    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${binding_name}
subjects:
- kind: User
  name: ${email}
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: namespace-lister # Binds to our custom namespace-lister ClusterRole
  apiGroup: rbac.authorization.k8s.io
EOF
done
echo "   -> Completed namespace listing setup."
echo ""

echo "--- Kubernetes RBAC Configuration Complete! ---"
echo "Students now have the precise access as per your requirements:"
echo "  - **Full management** on their own 'student-xxx' namespace."
echo "  - **View only** on 'monitoring' namespace."
echo "  - **View only** on 'cicd-pipeline-alpha' namespace."
echo "  - Can **list all namespaces** using 'kubectl get namespace'."
echo "  - **Cannot access resources inside other namespaces** (unless explicitly allowed, like monitoring/cicd-pipeline-alpha)."
