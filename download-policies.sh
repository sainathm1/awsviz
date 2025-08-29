#!/bin/bash

# Purpose: Retrieve AWS IAM policy ARNs, fetch their default version documents, save them as JSON files,
#          and create a zip archive of the policy documents.

# Exit on any error
set -e

# Constants
POLICY_ARNS_FILE="policy_arns.txt"
POLICIES_DIR="policies"
ZIP_FILE="policies.zip"

# Function to log messages
log_message() {
  echo "[INFO] $1"
}

# Function to log errors and continue
log_error() {
  echo "[ERROR] $1" >&2
}

# Step 1: List all IAM policy ARNs and save to a file
log_message "Listing all IAM policy ARNs..."
if ! aws iam list-policies --query 'Policies[*].Arn' --output text | tr '\t' '\n' > "$POLICY_ARNS_FILE"; then
  log_error "Failed to list IAM policies"
  exit 1
fi

# Step 2: Create directory for policy documents if it doesn't exist
log_message "Creating directory '$POLICIES_DIR' if it doesn't exist..."
mkdir -p "$POLICIES_DIR"

# Step 3: Process each policy ARN to retrieve and save its document
log_message "Retrieving policy documents..."
while IFS= read -r policy_arn; do
  if [[ -z "$policy_arn" ]]; then
    log_error "Empty ARN encountered, skipping..."
    continue
  fi

  # Extract policy name from ARN for file naming
  policy_name=$(basename "$policy_arn")
  log_message "Processing policy ARN: $policy_arn"

  # Retrieve the default version of the policy
  log_message "Fetching default version for policy: $policy_name"
  default_version=$(aws iam get-policy --policy-arn "$policy_arn" --query 'Policy.DefaultVersionId' --output text 2>/dev/null)
  if [[ $? -ne 0 || -z "$default_version" ]]; then
    log_error "Failed to retrieve default version for policy: $policy_arn"
    continue
  fi
  log_message "Default version for $policy_name is $default_version"

  # Retrieve the policy version document
  log_message "Fetching policy document for $policy_name (version: $default_version)"
  policy_json=$(aws iam get-policy-version --policy-arn "$policy_arn" --version-id "$default_version" --query 'PolicyVersion.Document' --output json 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    log_error "Failed to retrieve policy document for $policy_arn (version: $default_version)"
    continue
  fi

  # Save the policy document to a JSON file
  log_message "Saving policy document for $policy_name"
  echo "$policy_json" > "${POLICIES_DIR}/${policy_name}.json"
  log_message "Saved policy document to ${POLICIES_DIR}/${policy_name}.json"

done < "$POLICY_ARNS_FILE"

# Step 4: Create a zip archive of all policy documents
log_message "Creating zip archive of policy documents..."
if [[ -n "$(ls -A "$POLICIES_DIR")" ]]; then
  zip -r "$ZIP_FILE" "$POLICIES_DIR"
  log_message "Created zip archive: $ZIP_FILE"
else
  log_error "No policy documents found in $POLICIES_DIR, skipping zip creation"
fi

# Step 5: Clean up temporary files
log_message "Cleaning up temporary files..."
rm -f "$POLICY_ARNS_FILE"
log_message "Cleanup completed."

log_message "Script execution completed successfully."
