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