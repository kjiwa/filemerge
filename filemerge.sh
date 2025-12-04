#!/usr/bin/env bash

# File Combiner Script
# Combines the content of files with specified extensions from a target directory,
# excluding specified paths, into a single output file.

# --- Configuration and Setup ---

# Exit immediately if a command exits with a non-zero status.
# Exit immediately if accessing an unset variable.
# The pipefail option causes a pipeline to return the exit status of the last
# command in the pipe that returned a non-zero status.
set -euo pipefail

# Global Variables
DIRECTORY=""
OUTPUT_FILE=""
EXTENSIONS=()
EXCLUDES=()

# Temporary file for storing the list of files found by 'find'
TEMP_FILE=$(mktemp)

# --- Clean-up Function ---

# Function to ensure the temporary file is deleted upon script exit or interruption
cleanup() {
  # Check if the temporary file exists before trying to delete
  if [[ -f "$TEMP_FILE" ]]; then
    rm -f "$TEMP_FILE"
  fi
}
# Trap signals EXIT, INT (Ctrl+C), and TERM to ensure cleanup runs
trap cleanup EXIT INT TERM

# --- Usage Function ---

usage() {
  echo "Usage: $0 -d <directory> -o <output_file> [-e <ext>] [-x <path>]"
  echo ""
  echo "  Combines the contents of files with specified extensions into a single output file."
  echo "  The full relative path of each file will precede its content."
  echo ""
  echo "  Arguments:"
  echo "    -d, --directory <DIR>       The starting directory for the search (Mandatory)."
  echo "    -o, --output <FILE>         The file to write the combined content to (Mandatory)."
  echo "    -e, --extension <EXT>       File extension to include (e.g., 'sh', 'txt'). Can be specified multiple times."
  echo "    -x, --exclude <PATH>        Path or directory to exclude from the search. Can be specified multiple times."
  echo "    -h, --help                  Display this help message."
  echo ""
  exit 1
}

# --- Argument Parsing ---

parse_args() {
  # Use getopt to handle complex arguments
  local options=":d:o:e:x:h"
  local longoptions="directory:,output:,extension:,exclude:,help"
  local args

  # Check for GNU getopt (needed for long options) and handle error
  if ! args=$(getopt -o "$options" -l "$longoptions" -- "$@"); then
    # getopt prints its own error, then we show usage
    usage
  fi

  # Set positional parameters from the processed arguments
  eval set -- "$args"

  while true; do
    case "$1" in
    -d | --directory)
      DIRECTORY="$2"
      shift 2
      ;;
    -o | --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    -e | --extension)
      EXTENSIONS+=("$2")
      shift 2
      ;;
    -x | --exclude)
      EXCLUDES+=("$2")
      shift 2
      ;;
    -h | --help)
      usage
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Error: Invalid option '$1'" >&2
      usage
      ;;
    esac
  done
}

# --- Validation ---

validate_args() {
  echo "Validating arguments..."

  # Check mandatory arguments
  if [[ -z "$DIRECTORY" || -z "$OUTPUT_FILE" ]]; then
    echo "Error: Both the directory (-d) and output file (-o) must be specified." >&2
    usage
  fi

  # Check directory existence
  if [[ ! -d "$DIRECTORY" ]]; then
    echo "Error: Directory '$DIRECTORY' does not exist or is not a directory." >&2
    exit 1
  fi

  echo "Validation complete."
}

# --- File Filtering Function ---

find_files() {
  echo "Searching for files in '$DIRECTORY'..."

  # Array to hold the find command arguments (avoids 'eval' and complex quoting)
  local find_args=("find" "$DIRECTORY")

  # 1. Build Exclusion Logic
  if [[ ${#EXCLUDES[@]} -gt 0 ]]; then
    for path in "${EXCLUDES[@]}"; do
      find_args+=("-path")
      find_args+=("$DIRECTORY/$path")
      find_args+=("-prune")
      find_args+=("-o")
    done
  fi

  # 2. Build Extension Matching Logic
  if [[ ${#EXTENSIONS[@]} -gt 0 ]]; then
    local first=true

    # Start the expression group with a literal '('
    find_args+=("(")

    for ext in "${EXTENSIONS[@]}"; do
      if ! $first; then
        find_args+=("-o")
      fi

      find_args+=("-name")
      find_args+=("*.$ext")
      first=false
    done

    # Close the expression group with a literal ')'
    find_args+=(")")
  fi

  # 3. Add final constraints
  find_args+=("-type" "f")
  find_args+=("-print")

  # Execute the find command array directly and store output in TEMP_FILE
  if ! "${find_args[@]}" >"$TEMP_FILE"; then
    echo "Error: The find command failed to execute." >&2
    echo "Command attempted: ${find_args[@]}" >&2
    exit 1
  fi

  local file_count=$(wc -l <"$TEMP_FILE")
  echo "Found $file_count files."
}

# --- Content Combination ---

combine_contents() {
  local file_count=0

  echo "Combining contents into '$OUTPUT_FILE'..."

  # Clear the output file
  >"$OUTPUT_FILE"

  # Read the file list from the temporary file line by line
  while IFS= read -r file_path; do

    # 1. Format the path header (ASCII only)
    local header="--- FILE: $file_path ---"

    # 2. Write the header to the output file
    echo "$header" >>"$OUTPUT_FILE"

    # 3. Append the contents of the file
    if ! cat "$file_path" >>"$OUTPUT_FILE"; then
      echo "Warning: Failed to read content from '$file_path'. Skipping." >&2
      echo "--- ERROR READING FILE: $file_path ---" >>"$OUTPUT_FILE"
    fi

    # 4. Add two newlines for separation after the file content
    echo "" >>"$OUTPUT_FILE"
    echo "" >>"$OUTPUT_FILE"

    file_count=$((file_count + 1))

  done <"$TEMP_FILE"

  echo "Successfully processed $file_count files. Output saved to '$OUTPUT_FILE'."
}

# --- Main Execution ---

main() {
  parse_args "$@"
  validate_args
  find_files
  combine_contents
}

main "$@"
