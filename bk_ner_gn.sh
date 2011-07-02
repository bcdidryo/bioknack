#!/bin/bash

# Requirements:
#
# NCBI's Entrez Gene Catalogue
#   - expected in ./$entrez
#   - wget ftp://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz (and gunzip...)
#
# RefSeq Gene Data
#   - expected in ./$refseq
#   - wget ftp://ftp.ncbi.nih.gov/refseq/release/release-catalog/releaseXX.accession2geneid.gz
#     (substitute XX with the latest release)
#
# NCBI's Taxonomy Catalogue
#   - expected in ./$species_dict
#   - wget ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz (and untar...)
#
# Input documents for the text-mining/gene-normalisation
#   - *.{nxml,xml,txt} documents expected in ./$input_dir
#   - for running on the BioCreative 3 documents either use run_bc3_ner.sh or visit
#     http://www.biocreative.org/news/corpora/biocreative-iii-corpus/ and get either
#     - http://www.biocreative.org/media/store/files/2010/BC3GNTraining_.zip
#     - http://www.biocreative.org/media/store/files/2010/BC3GNTest.zip

# Results
#
# - written to ./$result_file
# - TSV
#   1. PubMed Central ID
#   2. Entrez Gene ID
#   3. Score

if [[ $# -ne 1 ]] ; then
	echo "TODO: help message"
	exit
fi

# all corpus species genes ner score
if [ "$1" != 'all' ] && [ "$1" != 'corpus' ] && [ "$1" != 'species' ] && [ "$1" != 'genes' ] \
	&& [ "$1" != 'ner' ] && [ "$1" != 'score' ] \
	&& [ "$1" != 'pmc' ] ; then
	echo "TODO: help message"
	exit
fi

entrez=dictionaries
refseq=dictionaries
refseq_version=*
species_dict=dictionaries

tmp_dir=tmp
corpus=$tmp_dir/corpus
input_dir=input
result_file=results.tsv

# On Mac OSX either run `sudo port install gawk` or set to 'awk'
awk_interpreter=gawk
ruby_interpreter=ruby

# Number of top-$cutoff results that make it into the final output
cutoff=100

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

if [ ! -d $input_dir ] ; then
	echo "Missing directory: $input_dir"
	echo "Expecting *.{nxml,xml,txt} documents in that directory for corpus generation."
	echo "If you want to run the BioCreative 3 evaluation, either use run_bc3_ner.sh or"
	echo "get/extract the BioCreative 3 documents from:"
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

if [ "$1" = 'pmc' ] ; then
	wget -P $input_dir ftp://ftp.ncbi.nlm.nih.gov/pub/pmc/articles.*.tar.gz
	for i in $input_dir/*.tar.gz ; do
		tar xzf $i -C $input_dir
	done
fi

if [ "$1" = 'all' ] || [ "$1" = 'corpus' ] ; then
	echo "Generating corpus..."
	rm -f $corpus
	echo " - extracting italicised text"
	for i in $input_xml/*.{nxml,xml,txt} ; do
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
fi

if [ "$1" = 'all' ] || [ "$1" = 'species' ] ; then
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
fi

if [ "$1" = 'all' ] || [ "$1" = 'genes' ] ; then
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
	# Note: if you do so, then adjust the wildcard under "Scoring results..." too!
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
fi

if [ "$1" = 'all' ] || [ "$1" = 'ner' ] ; then
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
fi

if [ "$1" = 'all' ] || [ "$1" = 'score' ] ; then
	echo "Scoring results..."
	cat $tmp_dir/bk_genes_? | $awk_interpreter -F "\t" '{print $1"\t"$3"\t"$2}' \
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

	echo "Compressing and accumulating document IDs, gene IDs and scores..."
	$awk_interpreter -F "\t|[|]" '{print $1"\t"$4"\t"$3}' $tmp_dir/bk_genes_species_score \
		| sort | uniq | ./bioknack/bk_ner_accumulate_score.rb \
		| sort -r -n -k 3 > $tmp_dir/bk_documents_genes_score

	echo "Writing results w/ tail cutoff after $cutoff hits..."
	rm -f $result_file
	for document_id in `cut -f 1 $tmp_dir/bk_documents_genes_score | sort -n | uniq` ; do
		grep -w -E "^$document_id" $tmp_dir/bk_documents_genes_score | head -n $cutoff >> $result_file
	done

	echo "Output file: $result_file"
fi

echo "Done. Have a nice day."

