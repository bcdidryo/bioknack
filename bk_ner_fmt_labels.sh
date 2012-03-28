#!/bin/bash

IFS=$(echo -e -n "\n\b")

# Fix ordering issues on Linux:
LANG="C"
LC_ALL="C"

os=`uname`

if [ "$os" != 'Darwin' ] && [ "$os" != 'Linux' ] ; then
	echo "Sorry, but you have to run this script under Mac OS X or Linux."
	exit 1
fi

if [ "$os" = 'Darwin' ] ; then
	sed_regexp=-E
fi

if [ "$os" = 'Linux' ] ; then
	sed_regexp=-r
fi

# TSV files that hold metadata information about:
# publication titles, pubmed IDs, DOIs
for tsvprefix in {'titles','journals','year','pmid','doi'} ; do 
	rm -f $tsvprefix.tsv $tsvprefix.tsv.tmp
done

for article in `find input -name *.nxml` ; do
	pmcid=`basename "$article" .nxml | grep -o -E '[0-9]+$'`
	<"$article" bk_ner_extract_tag.rb '<article-meta>' '</article-meta>' \
		| bk_ner_extract_tag.rb '<article-id pub-id-type="pmc">' '</article-id>' \
		| sed $sed_regexp 's/(^ +| +$)//g' | tr -d "\n" \
		| tee -a journals.tsv.tmp year.tsv.tmp pmid.tsv.tmp doi.tsv.tmp >> titles.tsv.tmp
	echo -e -n "\t" | tee -a journals.tsv.tmp year.tsv.tmp pmid.tsv.tmp doi.tsv.tmp >> titles.tsv.tmp
	<"$article" bk_ner_extract_tag.rb '<article-meta>' '</article-meta>' \
		| bk_ner_extract_tag.rb '<article-title>' '</article-title>' \
		| sed $sed_regexp 's/(^ +| +$)//g' | sed $sed_regexp 's/ +/ /g' | tr -d "\n" >> titles.tsv.tmp
	echo "" >> titles.tsv.tmp
	<"$article" bk_ner_extract_tag.rb '<article-meta>' '</article-meta>' \
		| bk_ner_extract_tag.rb '<pub-date pub-type="ppub">' '</pub-date>' \
		| bk_ner_extract_tag.rb '<year>' '</year>' \
		| sed $sed_regexp 's/(^ +| +$)//g' | sed $sed_regexp 's/ +/ /g' | tr -d "\n" >> year.tsv.tmp
	echo "" >> year.tsv.tmp
	<"$article" bk_ner_extract_tag.rb '<journal-meta>' '</journal-meta>' \
		| bk_ner_extract_tag.rb '<journal-title-group>' '</journal-title-group>' \
		| bk_ner_extract_tag.rb '<journal-title>' '</journal-title>' \
		| sed $sed_regexp 's/(^ +| +$)//g' | sed $sed_regexp 's/ +/ /g' | tr -d "\n" >> journals.tsv.tmp
	echo "" >> journals.tsv.tmp
	for idtype in {'pmid','doi'} ; do
		<"$article" bk_ner_extract_tag.rb '<article-meta>' '</article-meta>' \
			| bk_ner_extract_tag.rb "<article-id pub-id-type=\"$idtype\">" '</article-id>' \
			| sed $sed_regexp 's/(^ +| +$)//g' | sed $sed_regexp 's/ +/ /g' | tr -d "\n" >> $idtype.tsv.tmp
		echo "" >> $idtype.tsv.tmp
	done
done

for tsvprefix in {'titles','journals','year','pmid','doi'} ; do 
	<$tsvprefix.tsv.tmp sort -k 1 | uniq | grep -v -E '^	' > $tsvprefix.tsv
	rm -f $tsvprefix.tsv.tmp
done

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

