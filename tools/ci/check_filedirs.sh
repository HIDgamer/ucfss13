#!/bin/bash
if [ -n "$1" ]
then
    dme=$1
else
    echo "ERROR: Specify a DME to check"
    exit 1
fi

# Extract lines between FILE_DIR markers
file_dir_block=$(awk '/BEGIN_FILE_DIR/{flag=1;next}/END_FILE_DIR/{flag=0}flag' $dme)

# Check that every non-empty line in the block is a valid #define FILE_DIR entry
invalid=$(echo "$file_dir_block" | grep -v '^\s*$' | grep -v '^#define FILE_DIR ')
if [ -n "$invalid" ]
then
    echo "ERROR: File DIR was ticked, please untick it, see: https://tgstation13.org/phpBB/viewtopic.php?f=5&t=321 for more"
    exit 1
fi
