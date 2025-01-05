#!/usr/bin/env bash

files=0
lines=0
max=0
biggest=""

for filename in $(find ../lib/ -name '*.dart') ; do
    files=$((files+1))
    in_file=$(<"$filename" wc -l)
    lines=$((lines+in_file))
    echo "There are $in_file lines in $filename"
    if [[ ${in_file} -gt max ]] ; then
        max=${in_file}
        biggest=${filename}
    fi
done

for filename in $(find ../shared/ -name '*.dart') ; do
    files=$((files+1))
    in_file=$(<"$filename" wc -l)
    lines=$((lines+in_file))
    echo "There are $in_file lines in $filename"
    if [[ ${in_file} -gt max ]] ; then
        max=${in_file}
        biggest=${filename}
    fi
done

echo "There are $lines lines in $files files"
echo "The biggest file is $biggest with $max lines"