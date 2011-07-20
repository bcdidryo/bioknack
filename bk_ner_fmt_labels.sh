#!/bin/bash

IFS=$(echo -e -n "\n\b")

# On OSX, use the -E parameter:
#$sed_regexp=-E
$sed_regexp=-r

rm -f titles.tsv titles.tsv.tmp

for article in `find input -name *.nxml` ; do

	pmcid=`basename "$article" .nxml | grep -o -E '[0-9]+$'`
	echo -e -n "$pmcid\t" >> titles.tsv.tmp

	<$article bk_ner_extract_tag.rb '<article-meta>' '</article-meta>' \
		| bk_ner_extract_tag.rb '<article-title>' '</article-title>' \
		| tr -d "\n" | sed $sed_regexp 's/(^ +| +$)//g' | sed $sed_regexp 's/ +/ /g' >> titles.tsv.tmp

done

<titles.tsv.tmp sort -k 1 > titles.tsv
rm -f titles.tsv.tmp

rm -f gene_names.tsv

gawk -F '\t' '{print $2"\t"$3}' dictionaries/gene_info | grep -v NEWENTRY | sort -t "	" -k 1 > gene_names.tsv

rm -f term_names.tsv term_names.tsv.tmp

for ontology in dictionaries/*.obo ; do

	if [ ! -f "$ontology" ] ; then continue ; fi

	<"$ontology" bk_ner_fmt_obo.rb -n -o | gawk -F "\t" '{print $2"\t"$1}' >> term_names.tsv.tmp

done

<term_names.tsv.tmp sort -k 1 > term_names.tsv
rm -f term_names.tsv.tmp

rm -f species_names.tsv

# The part up to (and including) 'uniq' is copy/paste from bk_ner_gn.sh.
grep 'scientific name' dictionaries/names.dmp | cut -f 1,3 | gawk -F '\t' '{
		y=$2;
		sub(/ [^a-z].*/, "", y);
		if (match($2, "^\"")) {
			split($2, x, "\"");
			y=x[2]
		};
		if (match(y, "^'\''")) {
			split(y, x, "'\''");
			y=x[2]
		};
		if (match(y, "^[a-zA-Z0-9]")) {
			split(y, x, " ");
			if (length(x) > 1 && match(x[1], "^[A-Z][a-z]")) {
				print x[1]"\t"$1;
				print substr(x[1], 1, 1)"."substr(y, length(x[1])+1)"\t"$1
			};
			print y"\t"$1
		}
	}' | sort -k 1,2 | uniq \
	| grep -v -E '^.\. ' | grep -v '\.' | gawk -F "\t" '{print $2"\t"$1}' \
	| sort -k 1 > species_names.tsv

