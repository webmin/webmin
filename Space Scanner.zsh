#!/usr/bin/env zsh

export LC_ALL=C

script_dir=$(dirname "$0")

find "$script_dir" -type d -name "lang" | while read -r lang_dir; do
    # Process all files in the "lang" directory
    find "$lang_dir" -type f | while read -r file; do
        # Process each line to remove spaces around the first '=' and trim trailing spaces
        awk '
    {
      # Remove trailing spaces on the entire line
      gsub(/[ \t]+$/, "");

      # Match lines containing at least one "="
      if ($0 ~ /=/) {
        # Split the line into two parts: key and the rest (value)
        pos = index($0, "="); # Find the position of the first "="
        key = substr($0, 1, pos - 1); # Extract everything before the "="
        value = substr($0, pos + 1); # Extract everything after the "="

        # Trim spaces around key and value
        gsub(/[ \t]+$/, "", key); # Remove trailing spaces from key
        gsub(/^[ \t]+/, "", value); # Remove leading spaces from value

        # Print the reconstructed line
        print key "=" value;
      } else {
        # Leave lines that don’t match untouched
        print $0;
      }
    }' "$file" >"$file.tmp" && mv "$file.tmp" "$file"
    done
done
echo "Processing completed!"
