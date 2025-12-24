#!/usr/bin/env bash

files=0
lines=0
max=0
biggest=""
second_max=0
second_biggest=""

count_lines() {
    for filename in $(find "$1" -name '*.dart'); do
        # Extract the basename of the file
        basename=$(basename "$filename")
        
        # Skip files ending with mocks.dart unless the file is exactly "mocks.dart"
        if [[ "$basename" == *mocks.dart && "$basename" != "mocks.dart" ]]; then
            continue
        fi
        
        files=$((files + 1))
        in_file=$(<"$filename" wc -l)
        lines=$((lines + in_file))
        echo "There are $in_file lines in $filename"

        if [[ $in_file -gt $max ]]; then
            # Update second biggest before changing biggest
            second_max=$max
            second_biggest=$biggest

            # Update biggest
            max=$in_file
            biggest=$filename
        elif [[ $in_file -gt $second_max ]]; then
            # Update second biggest if it's not the largest
            second_max=$in_file
            second_biggest=$filename
        fi
    done
}

count_lines "../lib/"
count_lines "../shared/"

echo "There are $lines lines in $files files"
echo "The biggest file is $biggest with $max lines"
echo "The second biggest file is $second_biggest with $second_max lines"