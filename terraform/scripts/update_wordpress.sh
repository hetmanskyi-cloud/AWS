#!/bin/bash

set -euxo pipefail  # Exit on error, print commands, fail on pipeline errors, treat unset vars as errors

# --- Logging Helper --- #
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# --- Version Configuration --- #
DEFAULT_WP_VERSION="6.8.2"
WP_VERSION="$DEFAULT_WP_VERSION"
REDIS_CACHE_VERSION="2.5.4"
WORDFENCE_VERSION="8.0.5"

# --- Parse optional --version=X.Y.Z --- #
for arg in "$@"; do
  case $arg in
    --version=*) WP_VERSION="${arg#*=}"; shift ;;
    *) log "Unknown argument: $arg"; exit 1 ;;
  esac
done

# --- Paths & URLs --- #
DEST_DIR="${HOME}/wordpress" # Target WordPress Git repository
TMP_DIR="/tmp/wordpress-update"
PLUGINS_DIR="${DEST_DIR}/wp-content/plugins"
ARCHIVE_NAME="wordpress-${WP_VERSION}.zip"
ARCHIVE_URL="https://github.com/WordPress/WordPress/archive/refs/tags/${WP_VERSION}.zip"
TAG_NAME="v${WP_VERSION}"

# --- Plugins configuration --- #
declare -A PLUGINS
PLUGINS=(
  [redis-cache]="https://downloads.wordpress.org/plugin/redis-cache.${REDIS_CACHE_VERSION}.zip"
  [wordfence]="https://downloads.wordpress.org/plugin/wordfence.${WORDFENCE_VERSION}.zip"
)

# --- Prepare Temporary Workspace --- #
log "Preparing temporary workspace: ${TMP_DIR}"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"
cd "${TMP_DIR}"

# --- Download and Extract WordPress --- #
log "Downloading WordPress ${WP_VERSION} from GitHub..."
curl -fsSL -o "${ARCHIVE_NAME}" "${ARCHIVE_URL}"

log "Extracting archive..."
unzip -q "${ARCHIVE_NAME}"

# --- Remove any unexpected .git from extracted archive --- #
ARCHIVE_PATH="WordPress-${WP_VERSION}"
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
  find "${DEST_DIR}" -mindepth 1 \
    ! -name '.git' ! -path "${DEST_DIR}/.git/*" \
    -exec rm -rf {} + 2>/dev/null || true
  log "Contents cleared."
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

# --- Download and install plugins --- #
mkdir -p "${PLUGINS_DIR}"
for plugin in "${!PLUGINS[@]}"; do
  url="${PLUGINS[$plugin]}"
  log "Downloading plugin '$plugin' from $url ..."
  curl -fsSL -o "${plugin}.zip" "${url}"
  log "Extracting plugin '$plugin'..."
  unzip -q -o "${plugin}.zip" -d "${PLUGINS_DIR}"
  log "Plugin '$plugin' extracted."
done

log "All plugins updated/installed."

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
  git commit -m "Update WordPress to version ${WP_VERSION} and plugins to fixed versions"
fi

log "Pushing changes to 'master' branch..."
git push origin master

# --- Git Tagging (Update & Force) --- #
# This section ensures the tag always points to the latest commit for the given version.
# It will delete any existing local and remote tags before creating and pushing the new one.

log "Checking for existing tag '${TAG_NAME}'..."

# Check if tag exists on the remote and delete it
if git ls-remote --tags origin | grep -q "refs/tags/${TAG_NAME}$"; then
 log "Tag '${TAG_NAME}' found on remote. Deleting it..."
 git push --delete origin "${TAG_NAME}"
else
 log "Tag '${TAG_NAME}' not found on remote. No need to delete."
fi

# Check if tag exists locally and delete it
if git tag | grep -q "^${TAG_NAME}$"; then
 log "Tag '${TAG_NAME}' found locally. Deleting it..."
 git tag -d "${TAG_NAME}"
fi

# Create and push the new tag
log "Creating new local tag '${TAG_NAME}'..."
git tag "${TAG_NAME}"

log "Pushing new tag '${TAG_NAME}' to remote..."
git push origin "${TAG_NAME}"

# --- Cleanup --- #
log "Cleaning up temporary files..."
rm -rf "${TMP_DIR}"

log "WordPress ${WP_VERSION} and plugins successfully deployed and tagged as '${TAG_NAME}'"
exit 0

# --- Notes --- #
# This script updates a WordPress installation by downloading the specified version,
# extracting it, updating specified plugins, and then pushing the changes to a Git repository.
# It also creates a Git tag for the new version.
# Plugins are downloaded directly by fixed URLs; to change plugin versions, edit the version variables at the top.
# Run this script from any location. Ensure you have permissions and correct git configuration.
# This script assumes your WordPress directory is a Git repo and you have push rights.
