# filemerge.sh

A Bash utility that combines multiple files into a single output file, with each file's content preceded by its relative path.

## Usage

```bash
./filemerge.sh -o <output_file> [-d <directory>] [-e <ext>] [-x <path>]
```

## Options

- `-o, --output <FILE>` - Output file path (required)
- `-d, --directory <DIR>` - Starting directory for file search (optional, defaults to current directory)
- `-e, --extension <EXT>` - File extension to include (repeatable)
- `-x, --exclude <PATH>` - Path or directory to exclude (repeatable)
- `-h, --help` - Display help message

## Examples

Combine all shell scripts in the current directory:
```bash
./filemerge.sh -o combined.txt -e sh
```

Combine all files in a specific directory:
```bash
./filemerge.sh -d ./src -o output.txt
```

Combine multiple file types:
```bash
./filemerge.sh -d ./src -o output.txt -e js -e ts -e jsx
```

Exclude specific directories:
```bash
./filemerge.sh -o merged.txt -e py -x node_modules -x .git
```

Combine all files (no extension filter):
```bash
./filemerge.sh -o all_docs.txt
```

## Output Format

Each file's content is formatted as:

```
--- FILE: path/to/file.ext ---
[file content]


```

## Requirements

- Bash 4.0+
- Standard Unix utilities (find, cat, wc, getopt)

## Error Handling

The script will exit with an error if:
- Required arguments are missing
- The specified directory does not exist
- Temporary file creation fails
- The find command fails

Warnings are issued for individual files that cannot be read, but execution continues.

## Installation

```bash
chmod +x filemerge.sh
```

Optionally, move to a directory in your PATH:
```bash
sudo mv filemerge.sh /usr/local/bin/filemerge
```
