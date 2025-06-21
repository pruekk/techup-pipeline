#!/bin/bash
# gcp-iam.sh
# This script manages Google Cloud IAM policies for GKE students.
# It removes outdated, overly permissive bindings and applies necessary
# project-level viewer roles for GKE authentication.

# This script is compatible with Bash versions 3.2.x and newer.

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
GCP_PROJECT_ID="devops-docker-demo-458213"

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

echo "--- Starting GCP IAM Configuration for Project: ${GCP_PROJECT_ID} ---"

# --- Phase 1: Remove Old, Incorrect IAM Bindings ---
# These bindings used 'resource.name.startsWith' conditions which are ineffective
# for namespace-level control and could inadvertently grant broad cluster access.
# We iterate through each student and each problematic role (developer, viewer)
# to ensure these specific conditional bindings are removed.

echo "Removing potentially incorrect project-level IAM policy bindings..."
for i in "${!student_namespaces[@]}"; do
    student_ns_prefix="${student_namespaces[$i]}"
    email="${student_emails[$i]}"
    condition_expression="resource.name.startsWith('${student_ns_prefix}')"
    title_prefix="NamespaceAccessFor" # Matches the title used in your original example

    # Bash 3.x doesn't support ${variable^} for capitalization, so hardcode titles if needed
    # Assuming original titles were something like NamespaceAccessForStudentAx
    # Adjust 'title' if your exact original titles were different.
    title_suffix=""
    case "${student_ns_prefix}" in
        "student-ax") title_suffix="StudentAX" ;;
        "student-babe") title_suffix="StudentBabe" ;;
        "student-bank") title_suffix="StudentBank" ;;
        "student-charlie") title_suffix="StudentCharlie" ;;
        "student-neung") title_suffix="StudentNeung" ;;
        *) title_suffix="${student_ns_prefix}" ;; # Fallback if not explicitly listed
    esac
    full_condition_title="${title_prefix}${title_suffix}"


    # Attempt to remove roles/container.developer with condition
    echo "  - Removing roles/container.developer for ${email} with condition: ${full_condition_title}..."
    # Redirect stderr to /dev/null to suppress "Policy binding not found!" errors.
    gcloud projects remove-iam-policy-binding "${GCP_PROJECT_ID}" \
        --member="user:${email}" \
        --role="roles/container.developer" \
        --condition="expression=${condition_expression},title=${full_condition_title}" \
        --quiet 2>/dev/null || true

    # Attempt to remove roles/container.viewer with condition
    echo "  - Removing roles/container.viewer for ${email} with condition: ${full_condition_title}..."
    # Redirect stderr to /dev/null to suppress "Policy binding not found!" errors.
    gcloud projects remove-iam-policy-binding "${GCP_PROJECT_ID}" \
        --member="user:${email}" \
        --role="roles/container.viewer" \
        --condition="expression=${condition_expression},title=${full_condition_title}" \
        --quiet 2>/dev/null || true
done
echo "Finished removing old IAM bindings. (Any 'Not found' errors are now suppressed, which is expected)."
echo ""

# --- Phase 2: Grant Project-Level container.viewer Role ---
# This role allows students to authenticate with the GKE cluster and use `gcloud container clusters get-credentials`.
# It does NOT grant any Kubernetes resource permissions within the cluster itself; that's handled by RBAC.

echo "Granting project-level 'roles/container.viewer' to all students for GKE authentication..."
for email in "${student_emails[@]}"; do # Iterate through the emails array
    # Using --no-user-output-enabled to suppress interactive prompts and confirmation messages.
    # Using || true to prevent script exit if the binding already exists (idempotency).
    echo "  - Adding roles/container.viewer for user:${email}..."
    gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
        --member="user:${email}" \
        --role="roles/container.viewer" \
        --no-user-output-enabled || true

    echo "  - Adding roles/artifactregistry.writer for user:${email}..."
    gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
        --member="user:${email}" \
        --role="roles/artifactregistry.writer" \
        --no-user-output-enabled || true
done

echo "--- GCP IAM Configuration Complete! ---"
echo "Students now have basic authentication permissions to the GKE cluster."
