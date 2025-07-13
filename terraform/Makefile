# --- Makefile --- #
# Run this Makefile from the terraform directory.
# Automates infrastructure management tasks for all environments (dev, stage, prod), as well as AMI preparation, testing, and deployment.
#
# Usage examples:
#   make all                                     # Full pre-apply cycle: init -> format -> validate -> plan
#   make init                                    # Initialize Terraform
#   make plan ENV=prod                           # Preview changes for 'prod' environment
#   make apply ENV=stage                         # Apply changes for 'stage' environment
#   make debug                                   # Monitor WordPress installation via SSM
#   make check                                   # Check for undeleted resources
#   make provision-ami ENV=dev                   # Provision and harden an instance for Golden AMI creation
#   make test-ami ENV=dev                        # Run automated smoke tests against the provisioned instance
#   make create-ami ENV=dev                      # Create a Golden AMI from the hardened, tested instance
#   make use-ami TARGET_ENV=stage SOURCE_ENV=dev # Copy latest Golden AMI ID from dev to stage

# --- Variables --- #
OWNER           ?= Hetmanskyi
APPLICATION     ?= wordpress
COMPONENT       ?= asg
PROJECT         ?= AWS
ENV             ?= dev

# Path to the current environment's Terraform configuration (dev, stage, prod)
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
.PHONY: all init format validate plan apply destroy show output refresh graph debug check check-tools provision-ami test-ami create-ami use-ami

# Run full preparation cycle
all: check-tools init format validate plan

# Run the full preparation cycle (basic syntax/logic checks before apply)
init:
	terraform -chdir=$(TF_DIR) init -upgrade

# Format all Terraform files recursively (enforces best practices)
format:
	terraform -chdir=$(TF_DIR) fmt -recursive

# Validate the Terraform configuration (catches syntax errors and logical issues)
validate:
	terraform -chdir=$(TF_DIR) validate

# Preview infrastructure changes without applying (always run before apply)
plan:
	TF_VAR_environment=$(ENV) terraform -chdir=$(TF_DIR) plan

# Apply infrastructure changes (auto-approve, use with caution)
apply:
	TF_VAR_environment=$(ENV) terraform -chdir=$(TF_DIR) apply -auto-approve

# Destroy all managed infrastructure (irreversible, use with caution)
destroy:
	TF_VAR_environment=$(ENV) terraform -chdir=$(TF_DIR) destroy -auto-approve

# Show current Terraform-managed infrastructure
show:
	TF_VAR_environment=$(ENV) terraform -chdir=$(TF_DIR) show

# Display Terraform outputs for the current environment
output:
	TF_VAR_environment=$(ENV) terraform -chdir=$(TF_DIR) output

# Refresh the local state with remote infrastructure (makes no changes)
refresh:
	TF_VAR_environment=$(ENV) terraform -chdir=$(TF_DIR) refresh

# Generate a resource dependency graph in DOT format (see with Graphviz)
graph:
	terraform -chdir=$(TF_DIR) graph > graph.dot

# Monitor the WordPress installation process on EC2 via SSM
debug:
	bash $(SCRIPTS_DIR)/debug_monitor.sh

# Check for AWS resources that remain after destroy (avoids cloud resource leaks)
check:
	bash $(SCRIPTS_DIR)/check_aws_resources.sh

# Ensure required CLI tools (Terraform, AWS CLI) are installed before any actions
check-tools:
	@command -v terraform >/dev/null 2>&1 || { echo "Terraform is not installed."; exit 1; }
	@command -v aws >/dev/null 2>&1 || { echo "AWS CLI is not installed."; exit 1; }
	@echo "All required CLI tools are installed."

# --- AMI Provisioning Target --- #
# Provisions (updates and hardens) the running instance for Golden AMI creation using an Ansible playbook.
# This target only prepares the instance; it does NOT create the AMI.
# Run only in the 'dev' environment.
provision-ami: check-tools
	@if [ "$(ENV)" != "dev" ]; then echo "This target can only be run in the 'dev' environment."; exit 1; fi; \
	set -e; \
	\
	# Step 1: Setup timestamp and log file \
	TIMESTAMP=$$(date +%Y-%m-%d_%H-%M-%S); \
	LOG_DIR=environments/$(ENV)/ami_history/logs; \
	LOG_FILE=$$LOG_DIR/ami_provision_$$TIMESTAMP.log; \
	echo "[$$TIMESTAMP] Starting AMI provision (baseline update and hardening)..." | tee $$LOG_FILE; \
	\
	# Step 2: Find the running instance IP and ID based on tags \
	echo "[$$TIMESTAMP] Finding instance IP and ID..." | tee -a $$LOG_FILE; \
	INSTANCE_INFO=$$(aws ec2 describe-instances \
		--filters "Name=tag:Environment,Values=$(ENV)" \
				  "Name=tag:Application,Values=$(APPLICATION)" \
				  "Name=tag:Component,Values=$(COMPONENT)" \
				  "Name=tag:Project,Values=$(PROJECT)" \
				  "Name=tag:Owner,Values=$(OWNER)" \
				  "Name=instance-state-name,Values=running" \
		--query "Reservations[0].Instances[0].[InstanceId,PublicIpAddress]" --output text); \
	INSTANCE_ID=$$(echo "$$INSTANCE_INFO" | awk '{print $$1}'); \
	INSTANCE_IP=$$(echo "$$INSTANCE_INFO" | awk '{print $$2}'); \
	if [ -z "$$INSTANCE_IP" ]; then echo "ERROR: Could not find a running instance with a public IP in $(ENV) environment."; exit 1; fi; \
	echo "[$$TIMESTAMP] Found Instance ID: $$INSTANCE_ID, IP: $$INSTANCE_IP" | tee -a $$LOG_FILE; \
	\
	# Step 3: Generate ansible inventory for SSH \
	INVENTORY_FILE=ansible/inventory/golden-ami-ssh.yaml; \
	SSH_KEY_PATH="/home/sky/.ssh/hetmansky-ed25519.pem"; \
	if [ ! -f "$$SSH_KEY_PATH" ]; then \
		echo "ERROR: SSH key not found at $$SSH_KEY_PATH!"; \
		exit 1; \
	fi; \
	mkdir -p ansible/inventory; \
	printf "all:\n" > $$INVENTORY_FILE; \
	printf "  hosts:\n" >> $$INVENTORY_FILE; \
	printf "    golden-ami-instance:\n" >> $$INVENTORY_FILE; \
	printf "      ansible_host: %s\n" "$$INSTANCE_IP" >> $$INVENTORY_FILE; \
	printf "      ansible_connection: ssh\n" >> $$INVENTORY_FILE; \
	printf "      ansible_user: ubuntu\n" >> $$INVENTORY_FILE; \
	printf "      ansible_ssh_private_key_file: %s\n" "$$SSH_KEY_PATH" >> $$INVENTORY_FILE; \
	printf "      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'\n" >> $$INVENTORY_FILE; \
	echo "[$$TIMESTAMP] Created ansible inventory: $$INVENTORY_FILE" | tee -a $$LOG_FILE; \
	\
	# Step 4: Run Ansible playbook for system update and hardening via SSH \
	echo "[$$TIMESTAMP] Running Ansible prepare-golden-ami.yml..." | tee -a $$LOG_FILE; \
	ansible-playbook -i $$INVENTORY_FILE ansible/playbooks/prepare-golden-ami.yml | tee -a $$LOG_FILE; \
	echo "[$$TIMESTAMP] Provisioning done. Now verify instance and run make create-ami ENV=dev" | tee -a $$LOG_FILE;

# --- AMI Test Target --- #
# Runs the Ansible smoke test playbook to verify that the provisioned instance meets all requirements for Golden AMI.
# Only execute after 'provision-ami' and before 'create-ami'.
# Run only in the 'dev' environment.
test-ami: check-tools
	@if [ "$(ENV)" != "dev" ]; then echo "This target can only be run in the 'dev' environment."; exit 1; fi; \
	set -e; \
	\
	# Step 1: Setup timestamp and log file \
	TIMESTAMP=$$(date +%Y-%m-%d_%H-%M-%S); \
	LOG_DIR=environments/$(ENV)/ami_history/logs; \
	LOG_FILE=$$LOG_DIR/ami_smoke_test_$$TIMESTAMP.log; \
	echo "[$$TIMESTAMP] Starting AMI smoke test..." | tee $$LOG_FILE; \
	\
	# Step 2: Run Ansible smoke test playbook \
	PLAYBOOK_PATH=ansible/playbooks/smoke-test-ami.yml; \
	INVENTORY_FILE=ansible/inventory/golden-ami-ssh.yaml; \
	if [ ! -f "$$PLAYBOOK_PATH" ]; then \
		echo "ERROR: Playbook not found at $$PLAYBOOK_PATH"; exit 1; \
	fi; \
	if [ ! -f "$$INVENTORY_FILE" ]; then \
		echo "ERROR: Inventory file not found at $$INVENTORY_FILE"; exit 1; \
	fi; \
	echo "[$$TIMESTAMP] Running Ansible smoke-test-ami.yml..." | tee -a $$LOG_FILE; \
	ansible-playbook -i $$INVENTORY_FILE $$PLAYBOOK_PATH | tee -a $$LOG_FILE; \
	\
	echo "[$$TIMESTAMP] Smoke test complete. Review $$LOG_FILE for details."; \
	echo "If all checks passed, proceed to 'make create-ami ENV=dev'."

# --- AMI Creation Target --- #
# Creates the Golden AMI after provisioning and testing are successful.
# AMI is tagged as 'golden' and its ID is logged and committed to Git for traceability.
# Run only in the 'dev' environment.
create-ami: check-tools
	@if [ "$(ENV)" != "dev" ]; then echo "This target can only be run in the 'dev' environment."; exit 1; fi; \
	set -e; \
	\
	# Step 1: Setup timestamp and log file \
	TIMESTAMP=$$(date +%Y-%m-%d_%H-%M-%S); \
	LOG_DIR=environments/$(ENV)/ami_history/logs; \
	LOG_FILE=$$LOG_DIR/ami_creation_$$TIMESTAMP.log; \
	echo "[$$TIMESTAMP] Starting Golden AMI creation..." | tee $$LOG_FILE; \
	\
	# Step 2: Find the running instance ID based on tags (reuse logic) \
	echo "[$$TIMESTAMP] Finding instance ID..." | tee -a $$LOG_FILE; \
	INSTANCE_ID=$$(aws ec2 describe-instances \
		--filters "Name=tag:Environment,Values=$(ENV)" \
				  "Name=tag:Application,Values=$(APPLICATION)" \
				  "Name=tag:Component,Values=$(COMPONENT)" \
				  "Name=tag:Project,Values=$(PROJECT)" \
				  "Name=tag:Owner,Values=$(OWNER)" \
				  "Name=instance-state-name,Values=running" \
		--query "Reservations[0].Instances[0].InstanceId" --output text); \
	if [ -z "$$INSTANCE_ID" ]; then echo "ERROR: Could not find a running instance in $(ENV) environment."; exit 1; fi; \
	echo "[$$TIMESTAMP] Found Instance ID: $$INSTANCE_ID" | tee -a $$LOG_FILE; \
	\
	# Step 3: Create the Golden AMI (no reboot) \
	echo "[$$TIMESTAMP] Creating Golden AMI..." | tee -a $$LOG_FILE; \
	AMI_NAME="golden-ami-$$TIMESTAMP"; \
	AMI_ID=$$(aws ec2 create-image \
		--instance-id $$INSTANCE_ID \
		--name "$$AMI_NAME" \
		--no-reboot \
		--tag-specifications 'ResourceType=image,Tags=[{Key=Name,Value=$$AMI_NAME},{Key=Environment,Value=$(AMI_GOLDEN_TAG)},{Key=Application,Value=$(APPLICATION)},{Key=Component,Value=$(COMPONENT)},{Key=Project,Value=$(PROJECT)},{Key=Owner,Value=$(OWNER)}]' \
		--query "ImageId" --output text); \
	echo "$$TIMESTAMP - $$AMI_ID" >> environments/$(ENV)/ami_history/ami_id.txt; \
	\
	# Step 4: Output the AMI ID \
	echo "Golden AMI created with ID: $$AMI_ID"; \
	echo "[$$TIMESTAMP] Golden AMI created with ID: $$AMI_ID" | tee -a $$LOG_FILE; \
	\
	# Step 5: Commit AMI ID and log to Git \
	git add environments/$(ENV)/ami_history/ami_id.txt $$LOG_FILE && \
	git commit -m "chore($(ENV)): appended Golden AMI $$AMI_ID to history" && \
	echo "[$$TIMESTAMP] Committed AMI ID and log to Git." | tee -a $$LOG_FILE

# --- AMI Copy Target --- #
# Copies the latest Golden AMI ID from a source environment (dev) to a target environment (stage/prod).
# Updates the ami_id variable in the target's terraform.tfvars file and commits the change.
# Usage: make use-ami TARGET_ENV=stage SOURCE_ENV=dev
use-ami: check-tools
	\
	# Step 1: Read latest AMI ID from source environment history \
	SOURCE_AMI_FILE="environments/$(SOURCE_ENV)/ami_history/ami_id.txt"; \
	AMI_ID=$$(tail -n 1 $$SOURCE_AMI_FILE | awk '{print $$NF}'); \
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
# - By default, all operations use the 'dev' environment. To use another, set ENV=stage or ENV=prod.
# - AWS CLI must be configured with credentials and sufficient permissions for all actions.
# - Always run Makefile targets from within the terraform directory; directory structure is enforced.
# - The 'all' target runs: check-tools → init → format → validate → plan (safe preparation for any apply).
# - The 'init' target initializes the working directory for the current environment and upgrades providers.
# - The 'format' target recursively formats all Terraform files to follow best practices.
# - The 'validate' target checks for syntax or configuration errors in Terraform files.
# - The 'plan' target previews infrastructure changes. Always run before 'apply'.
# - The 'apply' target makes changes to the environment with auto-approve. Use with caution!
# - The 'destroy' target removes all resources managed by Terraform. This is irreversible.
# - The 'show' target displays the current Terraform-managed state in human-readable form.
# - The 'output' target displays output variables (e.g., ALB DNS, IDs) for the current environment.
# - The 'refresh' target syncs local state with actual infrastructure (does not modify resources).
# - The 'graph' target generates a DOT file visualizing resource dependencies.
# - The 'debug' target monitors WordPress deployment via SSM after EC2 instance initialization.
# - The 'check' target lists AWS resources that remain after destroy to prevent cloud resource leaks.
# - The 'check-tools' target verifies that Terraform and AWS CLI are installed before proceeding.
# - The 'provision-ami' target prepares (updates and hardens) the running instance using an Ansible playbook, but does not create the AMI.
#   Should only be run in the 'dev' environment. Logs are written to environments/dev/ami_history/logs/.
# - The 'test-ami' target runs the smoke-test Ansible playbook to verify the provisioned instance. Only proceed to AMI creation if all tests pass.
#   Should only be run in the 'dev' environment.
# - The 'create-ami' target creates a Golden AMI from the tested instance, tags it as 'golden', and writes its ID to environments/dev/ami_history/ami_id.txt.
#   The AMI ID and logs are committed to Git. Should only be run in the 'dev' environment.
# - The 'use-ami' target copies the latest Golden AMI ID from a source environment (e.g., dev) to a target environment (e.g., stage or prod)
#   by updating the ami_id in the target's terraform.tfvars and committing changes to Git.
#   Usage: make use-ami TARGET_ENV=stage SOURCE_ENV=dev
# - All helper scripts in SCRIPTS_DIR must be executable (e.g., check_aws_resources.sh, debug_monitor.sh).
# - Ansible playbooks are expected in terraform/ansible/playbooks/. Inventory files are auto-generated per operation.
# - Ansible inventory for SSM (terraform/ansible/inventory/golden-ami-ssm.yaml) or SSH (golden-ami-ssh.yaml) may be overwritten by provisioning targets.
# - Review log files in environments/$(ENV)/ami_history/logs/ after each operation for troubleshooting or traceability.
# - Always test changes in the 'dev' environment before promoting to 'stage' or 'prod'.
