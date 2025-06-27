# Terraform version and provider requirements
terraform {
  required_version = "~> 1.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

# --- Lambda Layer Automated Build and Deployment --- #
# This file contains the logic to automatically build a Python dependency layer
# and deploy it to AWS Lambda.

# Render the requirements.txt content from the template file
locals {
  requirements_content = templatefile("${var.source_path}/requirements.txt.tftpl", {
    pillow_version = var.library_version
  })
}

# --- Build Trigger Resource --- #
# This 'null_resource' acts as a trigger to rebuild the layer package.
resource "null_resource" "layer_build_trigger" {
  # The trigger is a hash of the RENDERED content. This ensures a rebuild
  # when the template or the library_version variable changes.
  triggers = {
    requirements_hash = sha256(local.requirements_content)
  }

  # This provisioner runs a shell command to create the layer package.
  provisioner "local-exec" {
    command = <<-EOT
      # 1. Create a build directory
      mkdir -p "${path.module}/build/python"

      # 2. Write the rendered content into a standard 'requirements.txt' file
      cat <<EOF > "${path.module}/build/requirements.txt"
      ${local.requirements_content}
      EOF

      # 3. Install the packages using the newly created requirements.txt file
      python -m pip install -r "${path.module}/build/requirements.txt" -t "${path.module}/build/python"

      # 4. Change into the 'build' directory and create a 'layer.zip' file
      cd "${path.module}/build" && zip -r ../layer.zip . -x "requirements.txt"
    EOT
  }
}

# --- AWS Lambda Layer Version Resource --- #
# This resource uploads the generated zip file to AWS and creates a new layer version.
resource "aws_lambda_layer_version" "lambda_layer" { # <-- ИМЯ ИЗМЕНЕНО ЗДЕСЬ
  layer_name = "${var.name_prefix}-${var.layer_name}-${var.environment}"

  # The filename points to the zip file created by the 'local-exec' provisioner.
  filename = "${path.module}/layer.zip"

  # We use the hash of the requirements content as the trigger for changes.
  # This avoids the plan-time error of trying to read a file that doesn't exist yet.
  # The value is taken directly from the 'triggers' block of our null_resource.
  source_code_hash = null_resource.layer_build_trigger.triggers.requirements_hash

  # Define compatibility for the layer using our generic variables.
  compatible_runtimes      = [var.runtime]
  compatible_architectures = [var.architecture]

  # This dependency ensures the build script finishes before this resource is created.
  depends_on = [null_resource.layer_build_trigger]
}

# --- Notes --- #
# 1. Automation: This setup fully automates the layer creation process within the 'terraform apply' workflow.
# 2. Triggering: The layer is only rebuilt if the 'library_version' variable or the template file itself changes.
# 3. Prerequisites: The machine running Terraform must have Python, pip, and the 'zip' command-line utility installed.
