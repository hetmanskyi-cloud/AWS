#!/bin/bash

set -euxo pipefail  # Exit on error, print commands, fail on pipeline errors, treat unset vars as errors

# --- Logging Helper --- #
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# --- Version Configuration --- #
DEFAULT_VERSION="6.8.1"
WORDPRESS_VERSION="$DEFAULT_VERSION"

# --- Parse optional --version=X.Y.Z --- #
for arg in "$@"; do
  case $arg in
    --version=*) WORDPRESS_VERSION="${arg#*=}"; shift ;;
    *) log "Unknown argument: $arg"; exit 1 ;;
  esac
done

# --- Paths & URLs --- #
DEST_DIR="${HOME}/wordpress"  # Target WordPress Git repository
TMP_DIR="/tmp/wordpress-update"
ARCHIVE_NAME="wordpress-${WORDPRESS_VERSION}.zip"
ARCHIVE_URL="https://github.com/WordPress/WordPress/archive/refs/tags/${WORDPRESS_VERSION}.zip"
TAG_NAME="v${WORDPRESS_VERSION}"

# --- Prepare Temporary Workspace --- #
log "Preparing temporary workspace: ${TMP_DIR}"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"
cd "${TMP_DIR}"

# --- Download and Extract WordPress --- #
log "Downloading WordPress ${WORDPRESS_VERSION} from GitHub..."
curl -fsSL -o "${ARCHIVE_NAME}" "${ARCHIVE_URL}"

log "Extracting archive..."
unzip -q "${ARCHIVE_NAME}"

# --- Remove any unexpected .git from extracted archive --- #
ARCHIVE_PATH="WordPress-${WORDPRESS_VERSION}"
ARCHIVE_GIT="${ARCHIVE_PATH}/.git"
ARCHIVE_GIT_NESTED="${ARCHIVE_PATH}/wordpress/.git"

if [ -d "${ARCHIVE_GIT}" ]; then
  log "Removing unexpected .git directory from archive root..."
  rm -rf "${ARCHIVE_GIT}"
fi

if [ -d "${ARCHIVE_GIT_NESTED}" ]; then
  log "Removing unexpected .git directory from nested 'wordpress/'..."
  rm -rf "${ARCHIVE_GIT_NESTED}"
fi

# --- Clean and Prepare Destination Directory --- #
if [ -d "${DEST_DIR}" ]; then
  log "Clearing contents of ${DEST_DIR}, preserving .git..."
  find "${DEST_DIR}" -mindepth 1 -ignore_readdir_race ! -name '.git' ! -path "${DEST_DIR}/.git/*" -exec rm -rf {} +
else
  log "Creating destination directory: ${DEST_DIR}"
  mkdir -p "${DEST_DIR}"
fi

# --- Copy WordPress Content --- #
if [ -d "${ARCHIVE_PATH}/wordpress" ]; then
  log "Detected 'wordpress/' subdirectory inside archive. Copying its contents..."
  cp -r "${ARCHIVE_PATH}/wordpress/"* "${DEST_DIR}/"
else
  log "No nested 'wordpress/' folder. Copying from archive root..."
  cp -r "${ARCHIVE_PATH}/"* "${DEST_DIR}/"
fi

log "WordPress content copied to: ${DEST_DIR}"

# --- Git Commit & Push --- #
cd "${DEST_DIR}"

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  log "ERROR: ${DEST_DIR} is not a Git repository."
  exit 1
fi

log "Staging all changes..."
git add .

log "Committing changes..."
if git diff --cached --quiet; then
  log "No changes detected. Skipping commit."
else
  git commit -m "Update WordPress to version ${WORDPRESS_VERSION}"
fi

log "Pushing changes to 'master' branch..."
git push origin master

# --- Git Tagging --- #
if git tag | grep -q "^${TAG_NAME}$"; then
  log "Tag '${TAG_NAME}' already exists locally. Skipping tag creation."
else
  log "Creating local tag '${TAG_NAME}'..."
  git tag "${TAG_NAME}"
fi

if git ls-remote --tags origin | grep -q "refs/tags/${TAG_NAME}"; then
  log "Tag '${TAG_NAME}' already exists on remote. Skipping push."
else
  log "Pushing tag '${TAG_NAME}' to remote..."
  git push origin "${TAG_NAME}"
fi

# --- Cleanup --- #
log "Cleaning up temporary files..."
rm -rf "${TMP_DIR}"

log "WordPress ${WORDPRESS_VERSION} successfully deployed and tagged as '${TAG_NAME}'"
exit 0

# --- Notes --- #
# This script is designed to update a WordPress installation by downloading the specified version,
# extracting it, and then pushing the changes to a Git repository.
# It also creates a Git tag for the new version.
# This script is designed to be run in a Unix-like environment (Linux, macOS).
# Ensure you have the necessary permissions and configurations for Git and AWS CLI.
# This script assumes you have the AWS CLI and Git installed and configured.
# It also assumes that the WordPress directory is a Git repository.