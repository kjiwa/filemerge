#!/usr/bin/env bash

set -euo pipefail

DIRECTORY="."
OUTPUT_FILE=""
EXTENSIONS=()
EXCLUDES=()

TEMP_FILE=$(mktemp) || {
  echo "Error: Failed to create temporary file." >&2
  exit 1
}

cleanup() {
  if [[ -f "$TEMP_FILE" ]]; then
    rm -f "$TEMP_FILE"
  fi
}
trap cleanup EXIT INT TERM

usage() {
  echo "Usage: $0 -o <output_file> [-d <directory>] [-e <ext>] [-x <path>]"
  echo ""
  echo "  Combines the contents of files with specified extensions into a single output file."
  echo "  The full relative path of each file will precede its content."
  echo ""
  echo "  Arguments:"
  echo "    -o, --output <FILE>         The file to write the combined content to (Mandatory)."
  echo "    -d, --directory <DIR>       The starting directory for the search (Optional, defaults to current directory)."
  echo "    -e, --extension <EXT>       File extension to include (e.g., 'sh', 'txt'). Can be specified multiple times."
  echo "    -x, --exclude <PATH>        Path or directory to exclude from the search. Can be specified multiple times."
  echo "    -h, --help                  Display this help message."
  echo ""
  exit 1
}

parse_args() {
  local options=":d:o:e:x:h"
  local longoptions="directory:,output:,extension:,exclude:,help"
  local args

  if ! args=$(getopt -o "$options" -l "$longoptions" -- "$@"); then
    usage
  fi

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

validate_args() {
  if [[ -z "$OUTPUT_FILE" ]]; then
    echo "Error: The output file (-o) must be specified." >&2
    usage
  fi

  if [[ ! -d "$DIRECTORY" ]]; then
    echo "Error: Directory '$DIRECTORY' does not exist or is not a directory." >&2
    exit 1
  fi
}

find_files() {
  echo "Searching for files in '$DIRECTORY'..."

  local find_args=("find" "$DIRECTORY")

  if [[ ${#EXCLUDES[@]} -gt 0 ]]; then
    for path in "${EXCLUDES[@]}"; do
      find_args+=("-path" "$DIRECTORY/$path" "-prune" "-o")
    done
  fi

  if [[ ${#EXTENSIONS[@]} -gt 0 ]]; then
    local first=true
    find_args+=("(")
    for ext in "${EXTENSIONS[@]}"; do
      if ! $first; then
        find_args+=("-o")
      fi
      find_args+=("-name" "*.$ext")
      first=false
    done
    find_args+=(")")
  fi

  find_args+=("-type" "f" "-print")

  if ! "${find_args[@]}" >"$TEMP_FILE"; then
    echo "Error: The find command failed to execute." >&2
    exit 1
  fi

  local file_count=$(wc -l <"$TEMP_FILE")
  echo "Found $file_count files."
}

combine_contents() {
  echo "Combining contents into '$OUTPUT_FILE'..."

  >"$OUTPUT_FILE"

  while IFS= read -r file_path; do
    echo "--- FILE: $file_path ---" >>"$OUTPUT_FILE"

    if ! cat "$file_path" >>"$OUTPUT_FILE"; then
      echo "Warning: Failed to read content from '$file_path'. Skipping." >&2
      echo "--- ERROR READING FILE: $file_path ---" >>"$OUTPUT_FILE"
    fi

    echo "" >>"$OUTPUT_FILE"
    echo "" >>"$OUTPUT_FILE"
  done <"$TEMP_FILE"

  echo "Successfully combined files. Output saved to '$OUTPUT_FILE'."
}

main() {
  parse_args "$@"
  validate_args
  find_files
  combine_contents
}

main "$@"
