# --- Lambda Layer Module Variables --- #
# Defines input variables for the automated Lambda Layer build module.

# --- Naming and Environment Variables --- #
# General variables for consistent naming and environment configuration.
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment for the resources (e.g., dev, stage, prod)"
  type        = string
  validation {
    condition     = can(regex("^(dev|stage|prod)$", var.environment))
    error_message = "The environment must be one of 'dev', 'stage', or 'prod'."
  }
}

# --- Required Settings --- #

variable "layer_name" {
  description = "The unique name for the Lambda Layer (e.g., 'Pillow-Dependencies')."
  type        = string
}

variable "source_path" {
  description = "The relative path to the source directory containing the requirements.txt.tftpl file."
  type        = string
}

variable "layer_runtime" {
  description = "A list of compatible runtimes for the layer (e.g., ['python3.12']). This must match the Lambda function's runtime."
  type        = list(string)
  default     = ["python3.12"]
}

variable "library_version" {
  description = "The specific version of the library to install (e.g., '11.2.1' for Pillow)."
  type        = string
}

# --- Optional Settings --- #

variable "layer_architecture" {
  description = "The compatible instruction set architecture for the layer (e.g., 'x86_64' or 'arm64'). Must match the Lambda function's architecture."
  type        = list(string)
  default     = ["x86_64"]
}

# --- Notes --- #
# 1. Purpose: This module automates the creation of a Lambda Layer from a Python requirements template file.
# 2. Reusability: Variable names are generic ('layer_name', 'library_version') to allow this module to be used for any Python dependency.
# 3. Dependencies: The machine running 'terraform apply' must have Python, pip, and the 'zip' utility installed.
