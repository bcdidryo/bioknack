#!/bin/bash

IFS=$(echo -e -n "\n\b")

rm -f input/*.{nxml,xml,txt}

for source in `pwd`/$1/*.{nxml,xml,txt} ; do
	if [ -f "$source" ] ; then
		ln -s "$source" input/`basename "$source"`
	fi
done

