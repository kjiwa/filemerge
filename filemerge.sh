#!/bin/sh

# MIT License
#
# Copyright (c) 2025 Kamil Jiwa
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -eu

DIRECTORY="."
OUTPUT_FILE=""
EXTENSIONS=""
EXCLUDES=""
TEMP_FILE=""

create_temp_file() {
  TEMP_FILE="${TMPDIR:-/tmp}/filemerge.$$"
  : >"$TEMP_FILE" || {
    echo "Error: Failed to create temporary file." >&2
    exit 1
  }
}

cleanup() {
  if [ -n "${TEMP_FILE:-}" ] && [ -f "$TEMP_FILE" ]; then
    rm -f "$TEMP_FILE"
  fi
}

trap cleanup EXIT INT TERM

usage() {
  cat <<EOF
Usage: $0 -o <output_file> [-d <directory>] [-e <ext>] [-x <path>]

  Combines the contents of files with specified extensions into a single output file.
  The full relative path of each file will precede its content.

  Arguments:
    -o <FILE>         The file to write the combined content to (Mandatory).
    -d <DIR>          The starting directory for the search (Optional, defaults to current directory).
    -e <EXT>          File extension to include (e.g., 'sh', 'txt'). Can be specified multiple times.
    -x <PATH>         Path or directory to exclude from the search. Can be specified multiple times.
    -h                Display this help message.

EOF
  exit 1
}

parse_args() {
  while getopts "d:o:e:x:h" opt; do
    case "$opt" in
    d) DIRECTORY="$OPTARG" ;;
    o) OUTPUT_FILE="$OPTARG" ;;
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
    h) usage ;;
    *) usage ;;
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

build_find_command() {
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
  echo "$find_cmd"
}

find_files() {
  echo "Searching for files in '$DIRECTORY'..."

  find_cmd=$(build_find_command)

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
  create_temp_file
  parse_args "$@"
  validate_args
  find_files
  combine_contents
}

main "$@"
