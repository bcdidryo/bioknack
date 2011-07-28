#!/bin/bash

IFS=$(echo -e -n "\n\b")

# Argument list gets too long when used as `rm -f ...`
for link in input/*.{nxml,xml,txt} ; do
	rm -f $link
done

for source in `pwd`/$1/*.{nxml,xml,txt} ; do
	if [ -f "$source" ] ; then
		ln -s "$source" input/`basename "$source"`
	fi
done

