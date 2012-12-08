#!/bin/bash

IFS=$(echo -e -n "\n\b")

# Fix ordering issues on Linux, speed-up things too:
LANG="C"
LC_ALL="C"
LC_COLLATE="C"

# Remark: Ruby interpreter to use...
#   ruby_interpreter=ruby
# Any interesting settings (s.a. "ruby1.9 -KA") do not work here, because
# IFS is redefined.

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
	<"$article" bk_ner_extract_tag.rb '<article-meta>' '</article-meta>' 1 > article-meta.tmp
	<article-meta.tmp bk_ner_extract_tag.rb '<article-id pub-id-type="pmc">' '</article-id>' 1 \
		| sed $sed_regexp 's/(^ +| +$)//g' | tr -d "\n" \
		| tee -a journals.tsv.tmp year.tsv.tmp pmid.tsv.tmp doi.tsv.tmp >> titles.tsv.tmp
	echo -e -n "\t" | tee -a journals.tsv.tmp year.tsv.tmp pmid.tsv.tmp doi.tsv.tmp >> titles.tsv.tmp
	<article-meta.tmp bk_ner_extract_tag.rb '<article-title>' '</article-title>' \
		| sed $sed_regexp 's/(^ +| +$)//g' | sed $sed_regexp 's/ +/ /g' | tr -d "\n" >> titles.tsv.tmp
	echo "" >> titles.tsv.tmp
	<article-meta.tmp bk_ner_extract_tag.rb '<pub-date pub-type="epub">' '</pub-date>' \
		| bk_ner_extract_tag.rb '<year>' '</year>' 1 \
		| sed $sed_regexp 's/(^ +| +$)//g' | sed $sed_regexp 's/ +/ /g' \
		| sed $sed_regexp 's/(....).*/\1/' | tr -d "\n" >> year.tsv.tmp
	echo "" >> year.tsv.tmp
	<"$article" bk_ner_extract_tag.rb '<journal-meta>' '</journal-meta>' 1 \
		| bk_ner_extract_tag.rb '<journal-title-group>' '</journal-title-group>' \
		| bk_ner_extract_tag.rb '<journal-title>' '</journal-title>' \
		| sed $sed_regexp 's/(^ +| +$)//g' | sed $sed_regexp 's/ +/ /g' | tr -d "\n" >> journals.tsv.tmp
	echo "" >> journals.tsv.tmp
	for idtype in {'pmid','doi'} ; do
		<article-meta.tmp bk_ner_extract_tag.rb "<article-id pub-id-type=\"$idtype\">" '</article-id>' 1 \
			| sed $sed_regexp 's/(^ +| +$)//g' | sed $sed_regexp 's/ +/ /g' | tr -d "\n" >> $idtype.tsv.tmp
		echo "" >> $idtype.tsv.tmp
	done
done
rm -f article-meta.tmp

for tsvprefix in {'titles','journals','year','pmid','doi'} ; do 
	<$tsvprefix.tsv.tmp sort -k 1,1 | ruby -e 'last_line = nil
		STDIN.each { |line|
		    if last_line then
		        chunks = line.split("\t", 2);
		        last_chunks = last_line.split("\t", 2);
		        if chunks[0] == last_chunks[0] then
		            if chunks[1].length < last_chunks[1].length then
		                # do nothing
		            else
		                last_line = line
		            end
		        else
		            puts last_line
		            last_line = line
		        end
		    else
		        last_line = line
		    end
		};
		puts last_line if last_line' | grep -v -E '^	' > $tsvprefix.tsv
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

