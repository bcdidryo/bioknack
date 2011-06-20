#!/bin/bash

# Requirements:
#
# bioknack
#   - expected in ./bioknack
#   - git clone https://github.com/joejimbo/bioknack
#
# NCBI's Entrez Gene Catalogue
#   - expected in ./$tmp_dir
#   - wget ftp://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz (and gunzip...)
#
# RefSeq Gene Data
#   - expected in ./$tmp_dir
#   - wget ftp://ftp.ncbi.nih.gov/refseq/release/release-catalog/releaseXX.accession2geneid.gz
#     (substitute XX with the latest release)
#
# NCBI's Taxonomy Catalogue
#   - expected in ./$species_dict
#   - wget ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz (and untar...)
#
# BioCreative 3
#   - XML documents expected in ./$input_xml
#   - from http://www.biocreative.org/news/corpora/biocreative-iii-corpus/ get either
#     - http://www.biocreative.org/media/store/files/2010/BC3GNTraining_.zip
#     - http://www.biocreative.org/media/store/files/2010/BC3GNTest.zip

# Results
#
# BioCreative 3 Format
#   - written to ./$result_file
#   - TSV
#     1. PubMed Central ID
#     2. Entrez Gene ID
#     3. Score

PATH=$PATH:`pwd`/bioknack

entrez=gene_info
refseq=refseq
refseq_version=*
species_dict=taxdmp
english_dict=dict

tmp_dir=bc3/bioknack
corpus=$tmp_dir/corpus
input_xml=bc3/BC3GNTest/xmls
result_file=bc3gn_bioknack

# On Mac OSX either run `sudo port install gawk` or set to 'awk'
awk_interpreter=gawk
ruby_interpreter=ruby

entity_regexp='[ .,;?]([A-Z][a-zA-Z0-9_\-]*[A-Z][a-zA-Z0-9_\-]*|[a-z]+[0-9A-Z_\-][a-zA-Z0-9_\-])[ .,;?]|\([a-zA-Z0-9_\-]{2,}\)'
stop_regexp='^(et al\.?|[Ii]n vi(tr|v)o|.+ [a-z]+(ed|ing)|.*DNA.*|.*PCR.*|.*RNA.*|I|II|III|IV|V|VI|VII|VIII|IX|X|Y|ORF)$'

entity_regexp_type=-E
stop_regexp_type=-E

# ALTERNATIVE RUBY ENGINE
#
# JRuby as Ruby interpreter: uses much more memory but is faster.
#ner_maxmem=6G
#ruby_interpreter=~/Projects/jruby-1.5.2/bin/jruby --fast --server -J-Xmx$ner_maxmem \
#	-J-Djruby.compile.fastest=true -J-Djruby.management.enabled=false

error=0

if [ ! -d bioknack ] ; then
	echo "Missing directory: bioknack"
	echo "Get it via: https://github.com/joejimbo/bioknack"
	echo ""

	error=1
fi

if [ ! -f $entrez/gene_info ] ; then
	echo "Missing file: $entrez/gene_info"
	echo "Get it via: ftp://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz"
	echo ""

	error=1
fi

if [ ! -f $refseq/release$refseq_version.accession2geneid ] ; then
	echo "Missing file: $refseq/release$refseq_version.accession2geneid"
	echo "Get it via: ftp://ftp.ncbi.nih.gov/refseq/release/release-catalog/release$refseq_version.accession2geneid.gz"
	echo '(Note: any version will do. Just set $refseq_version accordingly.)'
	echo ""

	error=1
fi

if [ ! -f $species_dict/names.dmp ] ; then
	echo "Missing file: $species_dict/names.dmp"
	echo "Get it via: ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz"
	echo ""

	error=1
fi

if [ ! -d $input_xml ] ; then
	echo "Missing directory: $input_xml"
	echo "Get it via: http://www.biocreative.org/media/store/files/2010/BC3GNTest.zip"
	echo ""

	error=1
fi

if [[ error -eq "1" ]] ; then
	echo "Okay... there were some errors. Bailing out."
	echo "Having said that: do not run this script in the bioknack directory."
	echo "Instead, 'cd ..' and create a symbolic to: bioknack/run_bc3_ner.sh"

	exit
fi

echo "Generating corpus..."
rm $corpus
echo " - extracting italicised text"
for i in $input_xml/*.nxml ; do
	pmcid=`basename $i .nxml`
	echo -e -n "$pmcid\t" >> $corpus
	grep -o -E '<italic>[^<]+</' $i | sed 's/<italic>//' | sed 's/<\///' \
		| sed -E 's/(^ +| +$)//g' | sed 's/-/ /g' \
		| grep -v $stop_regexp_type "$stop_regexp" \
		| sed 's/$/;/' \
		| sort | uniq | tr -d '\n' >> $corpus
	echo "" >> $corpus
done
echo " - extracting words/compounds with two or more uppercase letters"
for i in $input_xml/*.nxml ; do
	pmcid=`basename $i .nxml`
	tmp_file=$tmp_dir/`basename $i .nxml`.tmp
	echo -e -n "$pmcid\t" >> $corpus
	grep -o $entity_regexp_type "$entity_regexp" $i \
		| sed 's/^.//' | sed 's/.$//' | sed 's/-/ /' | sed 's/(^ +| +$)//g' \
		| grep -v $stop_regexp_type "$stop_regexp" \
		| sort | uniq | tr '\n' ';' | tr -d '\n' >> $corpus
	rm -f $tmp_file
	echo "" >> $corpus
done

echo "Generating species dictionary..."
cut -f 1,3 $species_dict/names.dmp | $awk_interpreter -F '\t' '{
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
	}' | sort -k 1,2 | uniq > $tmp_dir/species

echo "Partitioning species dictionary..."
for prefix in {1,2,3,4,5,6,7,8,9} ; do
	echo " - processing taxonomies starting with prefix $prefix"
	grep -E '[^0-9]'$prefix'[0-9]*$' $tmp_dir/species > $tmp_dir/species_$prefix
done

echo "Generating Entrez gene dictionary..."
<$entrez/gene_info bk_ner_fmt_entrezgene.rb > $tmp_dir/entrez_genes

echo "Generating RefSeq gene dictionary..."
<$refseq/release$refseq_version.accession2geneid $awk_interpreter -F '\t' '{
		split($3, x, ".");
		print x[1]"\t"$1"|"$2;
		if ($4 != "na") {
			split($4, x, ".");
			print x[1]"\t"$1"|"$2
		}
	}' > $tmp_dir/refseq_genes

echo "Merging gene dictionaries..."
sort $tmp_dir/entrez_genes $tmp_dir/refseq_genes | uniq > $tmp_dir/genes

# You might want to comment in the $gene_prefix splitting below, if you run out of memory.
echo "Partitioning gene dictionary..."
for prefix in {1,2,3,4,5,6,7,8,9} ; do
	echo " - processing taxonomies starting with prefix $prefix"
#	for gene_prefix in {1,2,3,4,5,6,7,8,9} ; do
#		echo "   - processing gene identifiers starting with prefix $gene_prefix"
#		grep -E '[^0-9]'$prefix'[0-9]*\|'$gene_prefix $tmp_dir/genes \
#			> $tmp_dir/genes_${prefix}_${gene_prefix}
		grep -E '[^0-9]'$prefix'[0-9]*\|' $tmp_dir/genes \
			> $tmp_dir/genes_${prefix}
#	done
done

echo "Running NER..."
for dictionary in $tmp_dir/genes_* ; do
	echo " - processing `basename $dictionary`"
	$ruby_interpreter ./bioknack/bk_ner.rb -c -m relational -l -d ";" -x $tmp_dir/corpus $dictionary \
		> $tmp_dir/bk_`basename $dictionary`
done
for dictionary in $tmp_dir/species_* ; do
	echo " - processing `basename $dictionary`"
	$ruby_interpreter ./bioknack/bk_ner.rb -c -m relational -l -d ";" $tmp_dir/corpus $dictionary \
		> $tmp_dir/bk_`basename $dictionary`
done

echo "Scoring results..."
cat $tmp_dir/bk_genes_* | $awk_interpreter -F "\t" '{print $1"\t"$3"\t"$2}' \
	| sort -k 1,2 | uniq -c | $awk_interpreter -F "\t" '{
			split($1, x, " ");
			print (x[1]*length($3))"\t"x[2]"\t"$2"\t"$3
		}' | sort -r -n \
	| $awk_interpreter -F "\t" '{
			split($3, x, "|");
			print $1"\t"$2"\t"x[1]"\t"x[2]"\t"$4
		}' > $tmp_dir/bk_genes_scored

echo "Preparing results for join with species dictionary..."
$awk_interpreter -F "\t" '{print $2"|"$3"\t"$1"\t"$4"\t"$5}' $tmp_dir/bk_genes_scored \
	| sort -k 1 > $tmp_dir/bk_genes_scored_for_join

echo "Preparing species dictionary for join with results..."
$awk_interpreter -F "\t" '{print $1"|"$3"\t"$2}' $tmp_dir/bk_species_* | sort -k 1,2 \
	| uniq > $tmp_dir/bk_species_for_join

echo "Joining results and species dictionary..."
join -t "	" -1 1 -2 1 $tmp_dir/bk_genes_scored_for_join \
	$tmp_dir/bk_species_for_join | sort -r -n -k 2 > $tmp_dir/bk_genes_species_score

echo "Filtering for occurrence threshold..."
$awk_interpreter -F "\t|[|]" '{print $1"\t"$4"\t"$3}' $tmp_dir/bk_genes_species_score | uniq > $result_file
# This additional grep can be used to filter out matches that hit only once or twice:
#| grep -v -E '[^ 0123456789](1|2)$' > $result_file

echo "Output file: $result_file"
echo "Done. Have a nice day."

