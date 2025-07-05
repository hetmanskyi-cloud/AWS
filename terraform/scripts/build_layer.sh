#!/bin/bash

set -euxo pipefail  # Exit immediately on errors, unset variables, and pipeline errors; print each command

# --- Lambda Layer Builder Script --- #
#
# Description:
#   Builds an AWS Lambda Layer with Pillow for Python.
#   Uses Docker for isolated and reproducible builds.
#
# Execution:
#   Typically invoked by Terraform local-exec provisioner.
#   Can be executed manually for debugging purposes.
#
# Requirements:
#   - Docker must be installed and running.
#
# Inputs:
#   $1 - PYTHON_VERSION_TAG (e.g., "3.12")
#   $2 - PILLOW_VERSION (e.g., "11.2.1")
#   $3 - MODULE_PATH (e.g., "./modules/lambda_layer")

# --- Logging Function --- #
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# --- Verify Arguments --- #
if [ "$#" -ne 3 ]; then
  log "ERROR: Invalid number of arguments."
  log "Usage: $0 PYTHON_VERSION_TAG PILLOW_VERSION MODULE_PATH"
  exit 1
fi

PYTHON_VERSION_TAG=$1
PILLOW_VERSION=$2
MODULE_PATH=$3

log "Starting Lambda Layer build with Python: ${PYTHON_VERSION_TAG}, Pillow: ${PILLOW_VERSION}, Path: ${MODULE_PATH}"

# --- Change to Module Directory --- #
cd "${MODULE_PATH}" || { log "ERROR: Failed to change directory to ${MODULE_PATH}"; exit 1; }

# --- Step 1: Create requirements.txt --- #
log "Creating requirements.txt with Pillow==${PILLOW_VERSION}"
echo "Pillow==${PILLOW_VERSION}" > requirements.txt

# --- Step 2: Docker-Based Build (as root, with host UID/GID fix) --- #
log "Starting Docker-based build process"
docker run --rm \
  -v "$(pwd)":/var/task \
  -w /var/task \
  --entrypoint /bin/sh "public.ecr.aws/lambda/python:${PYTHON_VERSION_TAG}" \
  -c "
    set -e
    log() { echo '[Docker] ['\$(date '+%Y-%m-%d %H:%M:%S')']' \$*; }

    log 'Installing system dependencies (gcc, libjpeg-devel, zlib-devel, zip)...'
    dnf install -y gcc libjpeg-devel zlib-devel zip

    log 'Installing Python packages from requirements.txt...'
    pip install -r requirements.txt -t python/

    log 'Creating layer.zip from installed packages...'
    zip -r -q layer.zip python

    log 'Fixing permissions of created files to match host user...'
    chown -R \$(stat -c '%u:%g' /var/task) python/ layer.zip
  "

log "Docker build completed successfully"

# --- Step 3: Cleanup --- #
log "Cleaning up temporary build files"
rm -f requirements.txt
rm -rf python/

log "Lambda Layer successfully built at: $(pwd)/layer.zip"

# --- Notes --- #
# 1. Purpose: Creates a 'layer.zip' compatible with AWS Lambda runtime.
# 2. Execution: Designed for Terraform invocation; can also be run manually for debugging.
# 3. Permissions Strategy: The container runs as 'root' to install system packages.
#    As a final step, 'chown' changes the ownership of the created files to match the
#    host user, which avoids all sudo/permission issues during cleanup.
# 4. System Dependencies: Explicitly installs 'gcc', 'libjpeg-devel', 'zlib-devel', and 'zip'
#    in the container, required for building Pillow and creating the archive.
