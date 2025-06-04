# --- Makefile --- #
# Automates common infrastructure management tasks using Terraform and helper scripts
#
# Usage examples:
#   make init                                    # Initialize Terraform
#   make plan ENV=prod                           # Preview changes for 'prod' environment
#   make apply ENV=stage                         # Apply changes for 'stage' environment
#   make debug                                   # Monitor WordPress installation via SSM
#   make check                                   # Check for undeleted resources
#   make all                                     # Full pre-apply cycle: init -> format -> validate -> plan
#   make ami ENV=dev                             # Create a Golden AMI from the 'dev' environment
#   make use-ami TARGET_ENV=stage SOURCE_ENV=dev # Copy AMI ID from dev into stage's terraform.tfvars

# --- Variables --- #
OWNER           ?= Hetmanskyi
APPLICATION     ?= wordpress
COMPONENT       ?= asg
PROJECT         ?= AWS
ENV             ?= dev

# Path to the environment-specific Terraform directory (dev, stage, prod)
TF_DIR          = environments/$(ENV)
SCRIPTS_DIR     = ./scripts     # Directory for helper scripts

# Tag value for the Environment tag on the golden AMI itself. This will be 'golden' regardless of source ENV.
AMI_GOLDEN_TAG  ?= golden

# Ensure Makefile is run from terraform/ directory
ifeq ($(notdir $(CURDIR)),terraform)
else
$(error Please run make from the terraform/ directory)
endif

# --- Targets --- #
.PHONY: all init format validate plan apply destroy show output refresh graph debug check check-tools ami use-ami

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

# --- AMI Creation Target --- #
# Creates a Golden AMI from the 'dev' environment. This target should only be run in the 'dev' environment.
ami: check-tools
	@if [ "$(ENV)" != "dev" ]; then echo "This target can only be run in the 'dev' environment."; exit 1; fi; \
	\
	# Step 1: Setup timestamp and log file \
	TIMESTAMP=$$(date +%Y-%m-%d_%H-%M-%S); \
	LOG_DIR=environments/$(ENV)/ami_history/logs; \
	LOG_FILE=$$LOG_DIR/ami_creation_$$TIMESTAMP.log; \
	echo "[$$TIMESTAMP] Starting AMI creation..." | tee $$LOG_FILE; \
	\
	# Step 2: Find the running instance ID based on tags \
	echo "[$$TIMESTAMP] Finding instance ID..." | tee -a $$LOG_FILE; \
	INSTANCE_ID=$$(aws ec2 describe-instances \
		--filters "Name=tag:Environment,Values=$(ENV)" \
		          "Name=tag:Application,Values=$(APPLICATION)" \
		          "Name=tag:Component,Values=$(COMPONENT)" \
		          "Name=tag:Project,Values=$(PROJECT)" \
		          "Name=tag:Owner,Values=$(OWNER)" \
		          "Name=instance-state-name,Values=running" \
		--query "Reservations[0].Instances[0].InstanceId" --output text); \
	echo "[$$TIMESTAMP] Found Instance ID: $$INSTANCE_ID" | tee -a $$LOG_FILE; \
	\
	# Step 3: Update packages on the instance via SSM \
	echo "[$$TIMESTAMP] Updating packages..." | tee -a $$LOG_FILE; \
	aws ssm send-command \
		--instance-ids $$INSTANCE_ID \
		--document-name "AWS-RunShellScript" \
		--parameters 'commands=["sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt clean"]' \
		--query "Command.CommandId" --output text >> $$LOG_FILE; \
	\
	# Step 4: Reboot the instance \
	echo "[$$TIMESTAMP] Rebooting instance..." | tee -a $$LOG_FILE; \
	aws ssm send-command \
		--instance-ids $$INSTANCE_ID \
		--document-name "AWS-RunShellScript" \
		--parameters 'commands=["sudo reboot"]' >> $$LOG_FILE; \
	\
	# Step 5: Wait for instance to come back online \
	echo "[$$TIMESTAMP] Waiting for instance to become available again..." | tee -a $$LOG_FILE; \
	aws ec2 wait instance-running --instance-ids $$INSTANCE_ID; \
	echo "[$$TIMESTAMP] Instance $$INSTANCE_ID is back online." | tee -a $$LOG_FILE; \
	\
	# Step 6: Create the AMI \
	echo "[$$TIMESTAMP] Creating Golden AMI..." | tee -a $$LOG_FILE; \
	AMI_NAME="golden-ami-$$TIMESTAMP"; \
	AMI_ID=$$(aws ec2 create-image \
		--instance-id $$INSTANCE_ID \
		--name "$$AMI_NAME" \
		--no-reboot \
		--tag-specifications "ResourceType=image,Tags=[\
{Key=Name,Value=$$AMI_NAME},\
{Key=Environment,Value=$(AMI_GOLDEN_TAG)},\
{Key=Application,Value=$(APPLICATION)},\
{Key=Component,Value=$(COMPONENT)},\
{Key=Project,Value=$(PROJECT)},\
{Key=Owner,Value=$(OWNER)}]" \
		--query "ImageId" --output text); \
	echo "$$TIMESTAMP - $$AMI_ID" >> environments/$(ENV)/ami_history/ami_id.txt; \
	\
	# Step 7: Output the AMI ID \
	echo "Golden AMI created with ID: $$AMI_ID"; \
	echo "[$$TIMESTAMP] Golden AMI created with ID: $$AMI_ID" | tee -a $$LOG_FILE; \
	\
	# Step 8: Commit AMI ID and log to Git \
	git add environments/$(ENV)/ami_history/ami_id.txt $$LOG_FILE && \
	git commit -m "chore($(ENV)): appended Golden AMI $$AMI_ID to history" && \
	echo "[$$TIMESTAMP] Committed AMI ID and log to Git." | tee -a $$LOG_FILE

# --- AMI Copy Target --- #
# Copies AMI ID from SOURCE_ENV to TARGET_ENV's terraform.tfvars
# Usage: make use-ami TARGET_ENV=stage SOURCE_ENV=dev
use-ami: check-tools
	\
	# Step 1: Read AMI ID from source environment \
	SOURCE_AMI_FILE="environments/$(SOURCE_ENV)/ami_id.txt"; \
	AMI_ID=$$(cat $$SOURCE_AMI_FILE); \
	echo "Using AMI ID: $$AMI_ID from environment '$(SOURCE_ENV)'"; \
	\
	# Step 2: Update AMI ID in target terraform.tfvars \
	TARGET_TFVARS="environments/$(TARGET_ENV)/terraform.tfvars"; \
	echo "Updating AMI ID in $$TARGET_TFVARS..."; \
	sed -i 's|^ami_id *= *".*"|ami_id = "'$$AMI_ID'"|' $$TARGET_TFVARS; \
	echo "AMI ID updated to $$AMI_ID"; \
	\
	# Step 3: Commit to Git if changed \
	git diff --quiet $$TARGET_TFVARS || { \
		git add $$TARGET_TFVARS && \
		git commit -m "chore($(TARGET_ENV)): update AMI ID to $$AMI_ID from $(SOURCE_ENV)"; \
		echo "AMI update committed to Git."; \
	}

# --- Notes --- #
# - Default environment for general Terraform operations is 'dev'. Use ENV=prod or ENV=stage to override.
# - AWS CLI must be configured with appropriate credentials and permissions.
# - Run all commands from within the terraform/ directory.
# - The 'make' command is used to run the Makefile targets. Ensure Make is installed and available in your PATH.
# - The 'all' target runs a full preparation cycle: init -> format -> validate -> plan.
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
# - The 'ami' target creates a Golden AMI only from the 'dev' environment. It performs system updates,
#   reboots the instance, creates an AMI, and writes the resulting AMI ID to 'environments/dev/ami_id.txt'.
#   The created AMI will be tagged with 'Environment=golden' and NOT 'Environment=dev'.
#   Usage: 'make ami ENV=dev'. Any other ENV will result in an error.
# - The 'use-ami' target copies the latest AMI ID from a specified source environment's 'ami_id.txt'
#   into the 'terraform.tfvars' file of a specified target environment. This automates the transfer
#   of approved AMI IDs into higher environments (e.g., stage, prod) for deployment.
#   Usage: 'make use-ami TARGET_ENV=stage SOURCE_ENV=dev'.
# - Ensure that the scripts in the SCRIPTS_DIR are executable and have the correct permissions.