# Terraform version and provider requirements
terraform {
  required_version = "~> 1.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# --- Lambda Layer Automated Build and Deployment --- #
# This file defines the logic to automatically build and deploy a Python Lambda Layer.
# It uses a decoupled shell script for the build process, which is triggered by this module.

locals {
  # Render the requirements.txt content from the template file.
  requirements_content = templatefile("${var.source_path}/requirements.txt.tftpl", {
    pillow_version = var.library_version
  })

  # Automatically extract the Python version number (e.g., "3.12") for the Docker image tag.
  layer_runtime_version_only = replace(var.layer_runtime[0], "python", "")
}

# --- Build Trigger --- #
# This null_resource triggers the central build script if dependencies or the script itself change.
resource "null_resource" "layer_builder" {
  triggers = {
    # This hash is based on the rendered requirements. It's the primary trigger for rebuilding
    # and is used as the source_code_hash for the layer version resource.
    requirements_hash = sha256(local.requirements_content)

    # This trigger ensures a rebuild if the build script itself is modified.
    # It correctly points to the script's central location using 'path.root'.
    build_script_hash = filebase64sha256("${path.module}/../../scripts/build_layer.sh")
  }

  # The provisioner executes our central, robust shell script.
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    # It calls the script from the central '/scripts' directory, passing the required
    # versions and the path to this module so the script knows where to work.
    command = "${path.module}/../../scripts/build_layer.sh ${local.layer_runtime_version_only} ${var.library_version} ${path.module}"
  }
}

# --- AWS Lambda Layer Version --- #
# This resource uploads the ZIP file created by the build script to AWS.
resource "aws_lambda_layer_version" "lambda_layer" {
  layer_name = "${var.name_prefix}-${var.layer_name}-${var.environment}"
  filename   = "${path.module}/layer.zip"

  # The source_code_hash is tied to the requirements content. This is the most reliable
  # way to signal to AWS that the layer's content has changed and a new version is needed.
  source_code_hash = null_resource.layer_builder.triggers.requirements_hash

  compatible_runtimes      = var.layer_runtime
  compatible_architectures = var.layer_architecture

  # This explicit dependency ensures the build script finishes before Terraform attempts to upload the file.
  depends_on = [null_resource.layer_builder]
}

# --- Cleanup on Destroy --- #
# This resource runs ONLY during 'terraform destroy' to remove the locally created ZIP file.
resource "null_resource" "layer_destroy_cleanup" {
  # The trigger just ensures this resource is part of the dependency graph.
  triggers = {
    layer_arn = aws_lambda_layer_version.lambda_layer.arn
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/layer.zip"
  }
}

# --- Notes --- #
# 1. Decoupled Build: The complex build logic is encapsulated in a central shell script
#    ('scripts/build_layer.sh'), and this module is only responsible for triggering it.
# 2. Automated Triggering: The 'null_resource.layer_builder' automatically re-runs the
#    build script if the Python dependencies (via requirements_hash) or the build script
#    itself (via build_script_hash) change.
# 3. Reliable Deployment: The 'aws_lambda_layer_version' resource depends on the 'null_resource'
#    to ensure the 'layer.zip' file exists before it attempts to upload it.
