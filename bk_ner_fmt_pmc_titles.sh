#!/bin/bash

IFS=$(echo -e -n "\n\b")

rm -f titles.tsv

for article in `find pmc -name *.nxml` ; do

	pmcid=`basename "$article" .nxml | grep -o -E '[0-9]+$'`
	echo -e -n "$pmcid\t" >> titles.tsv

	<$article bk_ner_extract_tag.rb '<article-meta>' '</article-meta>' \
		| bk_ner_extract_tag.rb '<article-title>' '</article-title>' \
		| tr -d "\n" | sed -E 's/(^ +| +$)//g' | sed -E 's/ +/ /g' >> titles.tsv

done

