#!/bin/bash
#
# Verify and correct the MongoDB Backup Helm chart structure
# This script checks if all required files are present and creates any missing files

set -e

CHART_DIR="charts/mongodb-backup"
TEMPLATES_DIR="${CHART_DIR}/templates"

echo "Verifying MongoDB Backup Helm chart structure..."

# Check if the chart directory exists
if [[ ! -d "${CHART_DIR}" ]]; then
    echo "Creating chart directory: ${CHART_DIR}"
    mkdir -p "${CHART_DIR}"
fi

# Check if the templates directory exists
if [[ ! -d "${TEMPLATES_DIR}" ]]; then
    echo "Creating templates directory: ${TEMPLATES_DIR}"
    mkdir -p "${TEMPLATES_DIR}"
fi

# List of required files to check
declare -A required_files=(
    ["${CHART_DIR}/Chart.yaml"]="Chart metadata file"
    ["${CHART_DIR}/values.yaml"]="Default values file"
    ["${CHART_DIR}/values.schema.json"]="JSON schema for validating values"
    ["${CHART_DIR}/README.md"]="Documentation file"
    ["${CHART_DIR}/commands.yaml"]="Helm commands reference"
    ["${TEMPLATES_DIR}/_helpers.tpl"]="Template helpers"
    ["${TEMPLATES_DIR}/configmap.yaml"]="ConfigMap template"
    ["${TEMPLATES_DIR}/secret.yaml"]="Secret template"
    ["${TEMPLATES_DIR}/serviceaccount.yaml"]="ServiceAccount template"
    ["${TEMPLATES_DIR}/role.yaml"]="RBAC role template"
    ["${TEMPLATES_DIR}/rolebinding.yaml"]="RBAC role binding template"
    ["${TEMPLATES_DIR}/pvc.yaml"]="PVC template"
    ["${TEMPLATES_DIR}/cronjob.yaml"]="CronJob template"
    ["${TEMPLATES_DIR}/networkpolicy.yaml"]="NetworkPolicy template"
    ["${TEMPLATES_DIR}/NOTES.txt"]="Post-installation notes"
)

# Check each required file and create placeholders for missing ones
MISSING_FILES=0

for file in "${!required_files[@]}"; do
    if [[ ! -f "${file}" ]]; then
        echo "Missing: ${file} (${required_files[$file]})"
        MISSING_FILES=$((MISSING_FILES+1))
        
        # Create an empty file as a placeholder
        echo "Creating placeholder for ${file}"
        touch "${file}"
    fi
done

# Summary
if [[ ${MISSING_FILES} -eq 0 ]]; then
    echo "✅ All required files are present!"
else
    echo "⚠️ Created ${MISSING_FILES} placeholder files."
    echo "   Please ensure these files are populated with proper content."
fi

# Check chart linting
if command -v helm &> /dev/null; then
    echo "Running helm lint to validate chart..."
    helm lint "${CHART_DIR}" || true
else
    echo "⚠️ Helm not found in PATH. Skipping chart linting."
fi

echo "Chart structure verification complete!"
echo ""
echo "Directory structure:"
find "${CHART_DIR}" -type f | sort