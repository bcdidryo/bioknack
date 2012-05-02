#!/bin/bash

# bioknack's NER-tool of generic normalisations.

# Requirements:
#
# The following files are automatically downloaded when executing
#
#   - bk_ner_gn.sh all
#   or alternatively
#   - bk_ner_gn.sh minimal
#   - bk_ner_gn.sh pmc
#   - bk_ner_gn.sh obo
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
# - written to
#   ./$genes_result_file
#   ./$species_result_file
#   ./$ontologies_{go,do,chebi}_result_file
#   as TSVs with the following columns
#     1. document ID
#     2. gene/species/term ID
#     3. score

usage() {
	echo "Usage: bk_ner_gn.sh task [format]"
	echo ""
	echo "Parameters:"
	echo "  task   : name of the task that should be carried out. The name"
	echo "           can be one of the following:"
	echo "             minimal : downloads minimal set of dictionaries, i.e."
	echo "                       Entrez gene, RefSeq, NCBI's taxonomy"
	echo "             obo     : downloads some OBO ontologies, i.e."
	echo "                       Gene ontology, human disease ontology, ChEBI"
	echo "             pmc     : downloads the PubMed Central open access subset"
	echo "             corpus  : compiles text documents into a corpus"
	echo "             species : compiles species dictionaries based on NCBI's"
	echo "                       taxonomy"
	echo "             genes   : compiles gene dictionaries based on Entrez gene"
	echo "                       and RefSeq"
	echo "             ner     : carries out the named entity recognition"
	echo "             score   : scores the 'ner' results"
	echo "             all     : carries out all named entity recognition steps"
	echo "                       EXCEPT the downloading of the input source;"
	echo "                       equivalent to running the tasks 'corpus',"
	echo "                       'species', 'genes', 'ner' and 'score' in that"
	echo "                       order"
	echo "  format : format of the text documents; either 'nxml', 'xml' or 'txt',"
	echo "           where 'nxml' is the default."
	echo ""
	echo "Example: full named entity recognition run over PubMed Central's"
	echo "         open access subset."
	echo ""
	echo "  $ bk_ner_gn.sh minimal              (get genes/species refs)"
	echo "  $ bk_ner_gn.sh obo                  (get some OBO ontologies)"
	echo "  $ bk_ner_gn.sh pmc                  (get OA-subset of PMC)"
	echo "  $ bk_ner_gn.sh all                  (run the NER)"
}

os=`uname`

if [ "$os" != 'Darwin' ] && [ "$os" != 'Linux' ] ; then
	echo "Sorry, but you have to run this script under Mac OS X or Linux."
	exit 1
fi

if [[ $# -lt 1 ]] || [[ $# -gt 2 ]] ; then
	usage
	exit 1
fi

# all corpus species genes ner score
if [ "$1" != 'all' ] && [ "$1" != 'corpus' ] && [ "$1" != 'species' ] && [ "$1" != 'genes' ] \
	&& [ "$1" != 'ner' ] && [ "$1" != 'score' ] \
	&& [ "$1" != 'minimal' ] && [ "$1" != 'pmc' ] && [ "$1" != 'obo' ] ; then
	usage
	exit 1
fi

# On Linux some joins complain about unsorted input by default.
# The reason is lies in the very interesting ignorance of the LANG
# variable, which would tell 'sort' and 'join' about the text coding
# used.
LANG="C"
LC_ALL="C"
LC_COLLATE="C"

# Format of the input files (determines file suffix too):
format=nxml

if [[ $# -eq 2 ]] ; then
	if [ "$2" != 'nxml' ] && [ "$2" != 'xml' ] && [ "$2" != 'txt' ] ; then
		usage
		exit 1
	fi
	format=$2
fi

# One directory for all the directories. You can modify specific paths down below.
dict_dir=dictionaries

entrez=$dict_dir
refseq=$dict_dir
refseq_version=*
species_dict=$dict_dir
obo_dict=$dict_dir

# The chunky corpus only contains italicised text and (what seems to be) identifiers.
# The sentence corpus contains document IDs mapped to sentences.
tmp_dir=tmp
chunky_corpus=$tmp_dir/chunky_corpus
sentence_corpus=$tmp_dir/sentence_corpus
input_dir=input
genes_result_file=genes.tsv
species_result_file=species.tsv
ontologies_go_result_file=terms_go.tsv
ontologies_do_result_file=terms_do.tsv
ontologies_chebi_result_file=terms_chebi.tsv

# Use 'gawk' as default. Mac OS X's 'awk' works as well, but
# for consistency I would suggest running `sudo port install gawk`.
# The default Linux 'awk' does *not* work.
if [ "$os" = 'Darwin' ] ; then
	awk_interpreter=awk
	sed_regexp=-E
fi
if [ "$os" = 'Linux' ] ; then
	awk_interpreter=gawk
	sed_regexp=-r
fi

# See below about using JRuby.
ruby_interpreter=ruby

# Whether the gene dicionaries should be split in 9 or 99 partitions
#  0 : create 9 partitions
#  1 : create 99 partitions
# Might be good to create 99 partitions when using JRuby, because it consumes
# much more memory than the standard implementation.
small_gene_partitions=1

# Number of top-$cutoff results that make it into the final output
cutoff=100

entity_regexp='[ .,;?]([A-Z][a-zA-Z0-9_\-]*[A-Z][a-zA-Z0-9_\-]*|[a-z]+[0-9A-Z_\-][a-zA-Z0-9_\-])[ .,;?]|\([a-zA-Z0-9_\-]{2,}\)'
sentence_regexp='[^.!?]+[.!?]'
stop_regexp='^(et al\.?|[Ii]n vi(tr|v)o|.+ [a-z]+(ed|ing)|.*DNA.*|.*PCR.*|.*RNA.*|I|II|III|IV|V|VI|VII|VIII|IX|X|Y|ORF)$'

entity_regexp_type=-E
stop_regexp_type=-E

PATH=$PATH:./bioknack

# ALTERNATIVE RUBY ENGINE
#
# JRuby as Ruby interpreter: uses much more memory but is faster.
#ner_maxmem=6G
#ruby_interpreter="jruby --fast --server -J-Xmx$ner_maxmem
#	-J-Djruby.compile.fastest=true -J-Djruby.management.enabled=false"

error=0

get_id() {
	if [ "$2" = 'txt' ] ; then
		id=`basename "$1" .$2`
	else
		id=(`<"$1" bk_ner_extract_tag.rb '<article-meta>' '</article-meta>' \
			| bk_ner_extract_tag.rb '<article-id pub-id-type="pmc">' '</article-id>' \
			| sed $sed_regexp 's/(^ +| +$)//g' | tr -d "\n"`)
	fi
	echo "$id"
}

if [ ! -d bioknack ] ; then
	echo "Missing directory: bioknack"
	echo "Get it via: https://github.com/joejimbo/bioknack"
	echo ""

	error=1
fi

if [ ! -d $dict_dir ] ; then
	echo "Missing directory: $dict_dir"
	echo "Dictionaries (and their sources) will go into this directory."
	echo ""
	echo "If you just want to prepare a corpus/corpora, then just create an empty directory."

	error=1
fi

if [ ! -d $tmp_dir ] ; then
	echo "Missing directory: $tmp_dir"
	echo "This directory is needed for storing the generated dictionaries and corpus/corpora."

	error=1
fi

if [ ! -d $input_dir ] ; then
	echo "Missing directory: $input_dir"
	echo "Expecting *.{nxml,xml,txt} documents in that directory for corpus/corpora generation."
	echo "If you want to run the BioCreative 3 evaluation, either use run_bc3_ner.sh or"
	echo "get/extract the BioCreative 3 documents."
	echo "Get it via: http://www.biocreative.org/media/store/files/2010/BC3GNTest.zip"
	echo ""
	echo "If you just want to prepare dictionaries, then just create an empty directory."

	error=1
fi

# The following constraints are only checked when the complete script is run. Otherwise
# the sanity checks become to clutered and inflexible in themselves.

if [ "$1" = 'all' ] && [ ! -f $entrez/gene_info ] ; then
	echo "Missing file: $entrez/gene_info"
	echo "Get it via: ftp://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz"
	echo ""

	error=1
fi

if [ "$1" = 'all' ] && [ ! -f $refseq/release$refseq_version.accession2geneid ] ; then
	echo "Missing file: $refseq/release$refseq_version.accession2geneid"
	echo "Get it via: ftp://ftp.ncbi.nih.gov/refseq/release/release-catalog/release$refseq_version.accession2geneid.gz"
	echo '(Note: any version will do. Just set $refseq_version accordingly.)'
	echo ""

	error=1
fi

if [ "$1" = 'all' ] && [ ! -f $species_dict/names.dmp ] ; then
	echo "Missing file: $species_dict/names.dmp"
	echo "Get it via: ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz"
	echo ""

	error=1
fi

if [[ error -eq "1" ]] ; then
	echo "Okay... there were some errors. Bailing out."
	echo "Having said that: do not run this script in the bioknack directory."
	echo "Instead, 'cd ..' and create a symbolic to: bioknack/run_bc3_ner.sh"

	exit
fi

if [ "$1" = 'minimal' ] ; then
	rm -f $entrez/gene_info.gz $entrez/gene_info $refseq/release$refseq_version.accession2geneid.gz \
		$refseq/release$refseq_version.accession2geneid $species_dict/taxdump.tar.gz $species_dict/*.dmp
	echo "Downloading minimal set of dictionaries..."
	echo " - Entrez gene"
	wget -P $entrez ftp://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz
	gunzip $entrez/gene_info.gz
	echo " - RefSeq"
	wget -P $refseq ftp://ftp.ncbi.nih.gov/refseq/release/release-catalog/release$refseq_version.accession2geneid.gz
	gunzip $refseq/release$refseq_version.accession2geneid.gz
	echo " - NCBI's taxonomy"
	wget -P $species_dict ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
	tar xzf $species_dict/taxdump.tar.gz -C $species_dict
	rm -f $species_dict/taxdump.tar.gz
fi

if [ "$1" = 'pmc' ] ; then
	rm -f $input_dir/articles.*.tar.gz
	for directory in $input_dir/* ; do
		if [ -d "$directory" ] ; then rm -rf "$directory" ; fi
	done
	echo "Downloading PubMed Central archives..."
	wget -P $input_dir ftp://ftp.ncbi.nlm.nih.gov/pub/pmc/articles.*.tar.gz
	for i in $input_dir/articles.*.tar.gz ; do
		tar xzf $i -C $input_dir
	done
	rm -f $input_dir/articles.*.tar.gz
fi

if [ "$1" = 'obo' ] ; then
	rm -rf $obo_dict/HumanDO.obo $obo_dict/gene_ontology_edit.obo
	echo "Downloading (some) OBOs..."
	wget -P $obo_dict http://diseaseontology.svn.sourceforge.net/viewvc/\*checkout\*/diseaseontology/trunk/HumanDO.obo
	wget -P $obo_dict http://obo.cvs.sourceforge.net/viewvc/obo/obo/ontology/genomic-proteomic/gene_ontology_edit.obo
	wget -P $obo_dict ftp://ftp.ebi.ac.uk/pub/databases/chebi/ontology/chebi.obo

	echo " - generating ontology dictionary"
	cat $obo_dict/*.obo | $ruby_interpreter ./bioknack/bk_ner_fmt_obo.rb | grep -E '^.{6,}	' \
		| grep -v -E '[^	]+ \([^\(\)]+\)	' | grep -v -E '[^	]+ \[.+\]	' \
		| grep -v -E '\.|,' | grep -v -E '[^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+' | sort | uniq > $tmp_dir/ontologies
fi

if [ "$1" = 'all' ] || [ "$1" = 'corpus' ] ; then
	echo "Generating corpus..."
	rm -f $chunky_corpus
	echo " - extracting italicised text"
	for i in $input_dir/*.{nxml,xml,txt} ; do
		if [ ! -f "$i" ] && [ ! -h "$i" ] ; then continue ; fi
		pmcid=$(get_id "$i" "$format")
		echo -e -n "$pmcid\t" >> $chunky_corpus
		grep -o -E '<italic>[^<]+</' "$i" | sed 's/<italic>//' | sed 's/<\///' \
			| sed $sed_regexp 's/(^ +| +$)//g' | sed 's/-/ /g' \
			| grep -v $stop_regexp_type "$stop_regexp" \
			| sed 's/$/;/' \
			| sort | uniq | tr -d '\n' >> $chunky_corpus
		echo "" >> $chunky_corpus
	done
	echo " - extracting words/compounds with two or more uppercase letters"
	for i in $input_dir/*.{nxml,xml,txt} ; do
		if [ ! -f "$i" ] && [ ! -h "$i" ] ; then continue ; fi
		pmcid=$(get_id "$i" "$format")
		echo -e -n "$pmcid\t" >> $chunky_corpus
		grep -o $entity_regexp_type "$entity_regexp" "$i" \
			| sed 's/^.//' | sed 's/.$//' | sed 's/-/ /' | sed 's/(^ +| +$)//g' \
			| grep -v $stop_regexp_type "$stop_regexp" \
			| sort | uniq | tr '\n' ';' | tr -d '\n' >> $chunky_corpus
		echo "" >> $chunky_corpus
	done
	if [ -f $tmp_dir/ontologies ] ; then
		rm -f $sentence_corpus
		echo " - extracting sentences"
		for i in $input_dir/*.{nxml,xml,txt} ; do
			if [ ! -f "$i" ] && [ ! -h "$i" ] ; then continue ; fi
			pmcid=$(get_id "$i" "$format")
			echo -e -n "$pmcid\t" >> $sentence_corpus
			if [ "$format" = 'txt' ] ; then
				<"$i" tr -d '\n' >> $sentence_corpus
			else
				<"$i" $ruby_interpreter ./bioknack/bk_ner_extract_tag.rb '<body>' '</body>' \
					| tr -d '\n' >> $sentence_corpus
			fi
			echo "" >> $sentence_corpus
		done
	fi
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
				if (length(x) > 1) {
					if (match(x[1], "^[A-Z][a-z]")) {
						print x[1]"\t"$1;
						print substr(x[1], 1, 1)"."substr(y, length(x[1])+1)"\t"$1
					};
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
	<$entrez/gene_info $ruby_interpreter ./bioknack/bk_ner_fmt_entrezgene.rb > $tmp_dir/entrez_genes

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

	rm -f $tmp_dir/genes_*
	# You might want to comment in the $gene_prefix splitting below, if you run out of memory.
	# Note: if you do so, then adjust the wildcard under "Scoring results..." too!
	echo "Partitioning gene dictionary..."
	for prefix in {1,2,3,4,5,6,7,8,9} ; do
		echo " - processing taxonomies starting with prefix $prefix"
		if [[ $small_gene_partitions -eq 0 ]] ; then
			grep -E '[^0-9]'$prefix'[0-9]*\|' $tmp_dir/genes \
				> $tmp_dir/genes_${prefix}
		else
			for gene_prefix in {1,2,3,4,5,6,7,8,9} ; do
				echo "   - processing gene identifiers starting with prefix $gene_prefix"
				grep -E '[^0-9]'$prefix'[0-9]*\|'$gene_prefix $tmp_dir/genes \
					> $tmp_dir/genes_${prefix}_${gene_prefix}
			done
		fi
	done
fi

if [ "$1" = 'all' ] || [ "$1" = 'ner' ] ; then
	echo "Running NER..."
	for dictionary in $tmp_dir/genes_* ; do
		echo " - processing `basename $dictionary`"
		$ruby_interpreter ./bioknack/bk_ner.rb -c -m relational -l -d ";" -x $chunky_corpus $dictionary \
			> $tmp_dir/bk_`basename $dictionary`
	done
	for dictionary in $tmp_dir/species_* ; do
		echo " - processing `basename $dictionary`"
		$ruby_interpreter ./bioknack/bk_ner.rb -c -m relational -l -d ";" $chunky_corpus $dictionary \
			> $tmp_dir/bk_`basename $dictionary`
	done
	if [ -f $tmp_dir/ontologies ] ; then
		echo " - processing ontologies"
		$ruby_interpreter ./bioknack/bk_ner.rb -c -l -y '\ ' $sentence_corpus $tmp_dir/ontologies \
			> $tmp_dir/bk_ontologies
	fi
fi

if [ "$1" = 'all' ] || [ "$1" = 'score' ] ; then
	echo "Scoring results..."
	echo " - scoring genes (species independent)"
	if [[ $small_gene_partitions -eq 0 ]] ; then
		gene_file=$tmp_dir/bk_genes_?
	else
		gene_file=$tmp_dir/bk_genes_?_?
	fi
	cat $gene_file | $awk_interpreter -F "\t" '{print $1"\t"$3"\t"$2}' \
		| sort -k 1,2 | uniq -c | $awk_interpreter -F "\t" '{
				split($1, x, " ");
				print (x[1]*length($3))"\t"x[2]"\t"$2"\t"$3
			}' | sort -r -n \
		| $awk_interpreter -F "\t" '{
				split($3, x, "|");
				print $1"\t"$2"\t"x[1]"\t"x[2]"\t"$4
			}' > $tmp_dir/bk_genes_scored

	echo " - preparing gene results for join with species dictionary"
	$awk_interpreter -F "\t" '{print $2"|"$3"\t"$1"\t"$4"\t"$5}' $tmp_dir/bk_genes_scored \
		| sort -k 1,1 > $tmp_dir/bk_genes_scored_for_join

	# The `sort -k 1,1` is there because Linux's sort
	# sucks harder than a black hole.
	echo " - preparing species dictionary for join with gene results (no species score used)"
	$awk_interpreter -F "\t" '{print $1"|"$3"\t"$2}' $tmp_dir/bk_species_? | sort -k 1,2 \
		| uniq | sort -k 1,1 > $tmp_dir/bk_species_for_join

	echo " - joining results and species dictionary"
	join -t "	" -1 1 -2 1 $tmp_dir/bk_genes_scored_for_join \
		$tmp_dir/bk_species_for_join | sort -r -n -k 2,2 > $tmp_dir/bk_genes_species_score

	echo " - compressing and accumulating document IDs, gene IDs and scores"
	$awk_interpreter -F "\t|[|]" '{print $1"\t"$4"\t"$3}' $tmp_dir/bk_genes_species_score \
		| sort | uniq | $ruby_interpreter ./bioknack/bk_ner_accumulate_score.rb \
		| sort -r -n -k 3,3 > $tmp_dir/bk_documents_genes_score

	echo " - writing gene results w/ tail cutoff after $cutoff hits"
	rm -f $genes_result_file $species_result_file $ontologies_go_result_file $ontologies_do_result_file $ontologies_chebi_result_file
	for document_id in `cut -f 1 $tmp_dir/bk_documents_genes_score | sort -n | uniq` ; do
		grep -w -E "^$document_id" $tmp_dir/bk_documents_genes_score | head -n $cutoff >> $genes_result_file
	done

	echo " - scoring species"
	cat $tmp_dir/bk_species_? | cut -f 1,3 | sort | uniq -c | $awk_interpreter -F "\t" '{
			split($1, x, " ");
			print x[2]"\t"$2"\t"x[1]
		}' | sort -r -n -k 3,3 | tee $tmp_dir/bk_species_scored > $species_result_file
 
	if [ -f $tmp_dir/ontologies ] ; then
		echo " - scoring ontology terms"
		cut -f 1,3 $tmp_dir/bk_ontologies | sort | uniq -c | $awk_interpreter -F "\t" '{
				split($1, x, " ");
				print x[2]"\t"$2"\t"x[1]
			}' | sort -r -n -k 3 > $tmp_dir/bk_ontologies_scored
		grep -E '^GO:' $tmp_dir/bk_ontologies_scored > $ontologies_go_result_file
		grep -E '^DO:' $tmp_dir/bk_ontologies_scored > $ontologies_do_result_file
		grep -E '^CHEBI:' $tmp_dir/bk_ontologies_scored > $ontologies_chebi_result_file
	fi

	echo -n "Output files: $genes_result_file $species_result_file"
	if [ -f $tmp_dir/ontologies ] ; then echo " $ontologies_go_result_file $ontologies_do_result_file $ontologies_chebi_result_file" ; else echo "" ; fi
fi

echo "Done. Have a nice day."

