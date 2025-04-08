#!/bin/bash

set -euo pipefail

echo "Checking PHP files for encoding issues..."

find . -type f -name "*.php" | while read -r file; do
  ENCODING=$(file -bi "$file")

  echo "Checking: $file"
  echo "Encoding: $ENCODING"

  # Check for BOM
  if grep -q $'\xef\xbb\xbf' "$file"; then
    echo "BOM detected — removing..."
    sed -i '1s/^\xEF\xBB\xBF//' "$file"
    echo "BOM removed"
  else
    echo "No BOM found"
  fi

  # Re-encode file to UTF-8 (force clean UTF-8)
  echo "Re-encoding to UTF-8..."
  iconv -f UTF-8 -t UTF-8 "$file" -o "$file.tmp" || {
    echo "iconv failed for $file"
    exit 1
  }

  mv "$file.tmp" "$file"
  echo "$file cleaned and saved."
  echo
done

echo "All PHP files processed successfully."

# --- Notes --- #
# ✅ Purpose:
#   This script ensures that all PHP files are cleanly encoded in UTF-8 and free of BOM (Byte Order Mark),
#   which can cause unexpected issues in web applications, especially with headers and WordPress themes/plugins.
#
# ⚙️ What it does:
#   - Scans the current directory recursively for *.php files
#   - Detects and removes BOM if present at the beginning of a file
#   - Re-encodes files to UTF-8 using iconv to ensure proper formatting
#
# 💡 When to use:
#   - After cloning or modifying WordPress/PHP files from external sources
#   - Before uploading PHP files to the server
#   - When encountering "headers already sent" or invisible character issues in WordPress
#
# 🛠️ Requirements:
#   - Unix-like environment with `file`, `grep`, `sed`, and `iconv` installed
#
# ❗ Caution:
#   - Backup your files before running this script in production environments
#   - Not suitable for binary or non-UTF-8 encoded source files outside of PHP