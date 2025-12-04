#!/bin/sh

set -eu

DIRECTORY="."
OUTPUT_FILE=""
EXTENSIONS=""
EXCLUDES=""

TEMP_FILE=$(mktemp) || {
  echo "Error: Failed to create temporary file." >&2
  exit 1
}

cleanup() {
  if [ -f "$TEMP_FILE" ]; then
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
  echo "    -o <FILE>         The file to write the combined content to (Mandatory)."
  echo "    -d <DIR>          The starting directory for the search (Optional, defaults to current directory)."
  echo "    -e <EXT>          File extension to include (e.g., 'sh', 'txt'). Can be specified multiple times."
  echo "    -x <PATH>         Path or directory to exclude from the search. Can be specified multiple times."
  echo "    -h                Display this help message."
  echo ""
  exit 1
}

parse_args() {
  while getopts "d:o:e:x:h" opt; do
    case "$opt" in
    d)
      DIRECTORY="$OPTARG"
      ;;
    o)
      OUTPUT_FILE="$OPTARG"
      ;;
    e)
      if [ -z "$EXTENSIONS" ]; then
        EXTENSIONS="$OPTARG"
      else
        EXTENSIONS="$EXTENSIONS $OPTARG"
      fi
      ;;
    x)
      if [ -z "$EXCLUDES" ]; then
        EXCLUDES="$OPTARG"
      else
        EXCLUDES="$EXCLUDES $OPTARG"
      fi
      ;;
    h)
      usage
      ;;
    *)
      usage
      ;;
    esac
  done
}

validate_args() {
  if [ -z "$OUTPUT_FILE" ]; then
    echo "Error: The output file (-o) must be specified." >&2
    usage
  fi

  if [ ! -d "$DIRECTORY" ]; then
    echo "Error: Directory '$DIRECTORY' does not exist or is not a directory." >&2
    exit 1
  fi
}

find_files() {
  echo "Searching for files in '$DIRECTORY'..."

  find_cmd="find '$DIRECTORY'"

  if [ -n "$EXCLUDES" ]; then
    for path in $EXCLUDES; do
      find_cmd="$find_cmd -path '$DIRECTORY/$path' -prune -o"
    done
  fi

  if [ -n "$EXTENSIONS" ]; then
    find_cmd="$find_cmd \\("
    first=true
    for ext in $EXTENSIONS; do
      if [ "$first" = true ]; then
        find_cmd="$find_cmd -name '*.$ext'"
        first=false
      else
        find_cmd="$find_cmd -o -name '*.$ext'"
      fi
    done
    find_cmd="$find_cmd \\)"
  fi

  find_cmd="$find_cmd -type f -print"

  if ! eval "$find_cmd" >"$TEMP_FILE"; then
    echo "Error: The find command failed to execute." >&2
    exit 1
  fi

  file_count=$(wc -l <"$TEMP_FILE")
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
