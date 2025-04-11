# --- Makefile --- #
# Automates common infrastructure management tasks using Terraform and helper scripts
#
# Usage examples:
#   make init                    # Initialize Terraform
#   make plan ENV=prod           # Preview changes for 'prod' environment
#   make apply ENV=stage         # Apply changes for 'stage' environment
#   make debug                   # Monitor WordPress installation via SSM
#   make check                   # Check for undeleted resources
#   make all                     # Full pre-apply cycle: init → format → validate → plan

# --- Variables --- #
ENV ?= dev                       # Default environment (can be overridden)
TF_DIR        = .                # Terraform root directory
SCRIPTS_DIR   = ./scripts        # Directory for helper scripts. To change the script directory, modify the SCRIPTS_DIR variable

# Ensure Makefile is run from terraform/ directory
ifeq ($(notdir $(CURDIR)),terraform)
else
$(error Please run make from the terraform/ directory)
endif

# --- Targets --- #
# Define targets for common tasks
# Each target corresponds to a specific Terraform command or script
# The targets are designed to be run in sequence or individually as needed
.PHONY: all init format validate plan apply destroy show output refresh graph debug check check-tools

# Run full preparation cycle
all: check-tools init format validate plan

# Initialize Terraform and upgrade providers
init:
	terraform -chdir=$(TF_DIR) init -upgrade

# Format all Terraform files recursively
format:
	terraform -chdir=$(TF_DIR) fmt -recursive

# Validate Terraform configuration
validate:
	terraform -chdir=$(TF_DIR) validate

# Preview infrastructure changes
plan:
	TF_VAR_environment=$(ENV) terraform -chdir=$(TF_DIR) plan

# Apply infrastructure changes
apply:
	TF_VAR_environment=$(ENV) terraform -chdir=$(TF_DIR) apply -auto-approve

# Destroy all managed infrastructure
destroy:
	TF_VAR_environment=$(ENV) terraform -chdir=$(TF_DIR) destroy -auto-approve

# Show current Terraform-managed infrastructure
show:
	TF_VAR_environment=$(ENV) terraform -chdir=$(TF_DIR) show

# Display Terraform outputs for the current environment
output:
	TF_VAR_environment=$(ENV) terraform -chdir=$(TF_DIR) output

# Refresh local state with the actual remote infrastructure
refresh:
	TF_VAR_environment=$(ENV) terraform -chdir=$(TF_DIR) refresh

# Generate a visual dependency graph (in DOT format). Use tools like Graphviz to render the resulting 'graph.dot' file.
graph:
	terraform -chdir=$(TF_DIR) graph > graph.dot

# Monitor WordPress installation via SSM
debug:
	bash $(SCRIPTS_DIR)/debug_monitor.sh

# Check for any leftover resources after destroy
check:
	bash $(SCRIPTS_DIR)/check_aws_resources.sh

# Check if required CLI tools are installed
check-tools:
	@command -v terraform >/dev/null 2>&1 || { echo "Terraform is not installed."; exit 1; }
	@command -v aws >/dev/null 2>&1 || { echo "AWS CLI is not installed."; exit 1; }
	@echo "All required CLI tools are installed."

# --- Notes --- #
# - Default environment is 'dev'. Use ENV=prod or ENV=stage to override.
# - AWS CLI must be configured with appropriate credentials and permissions.
# - Run all commands from within the terraform/ directory.
# - The 'make' command is used to run the Makefile targets. Ensure Make is installed and available in your PATH.
# - The 'all' target runs a full preparation cycle: init → format → validate → plan.
# - The 'init' target initializes the Terraform working directory and downloads necessary providers.
# - The 'format' target will format Terraform files according to best practices.
# - The 'validate' target checks the syntax and configuration of Terraform files.
# - The 'plan' target will show a preview of changes without applying them. Always run this before 'apply'.
# - The 'apply' target will automatically approve changes. Use with caution.
# - The 'destroy' target will remove all resources managed by Terraform. Use with caution.
# - The 'show' target prints the current Terraform state in human-readable format.
# - The 'output' target displays output variables (e.g., ALB DNS name).
# - The 'refresh' target syncs local state with the current infrastructure without making changes.
# - The 'graph' target generates a visual representation of the resource dependencies in DOT format.
# - The 'debug' target should only be used after the EC2 instance has been initialized and is available via SSM.
# - The 'check' target will list any AWS resources that were not deleted after running 'destroy'.
# - The 'check-tools' target ensures that Terraform and AWS CLI are installed before proceeding.
# - Ensure that the scripts in the SCRIPTS_DIR are executable and have the correct permissions.