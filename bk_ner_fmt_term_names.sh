#!/bin/bash

rm -f term_names.tsv

for ontology in dictionaries/*.obo ; do

	if [ ! -f "$ontology" ] ; then continue ; fi

	<"$ontology" bk_ner_fmt_obo.rb -n | awk -F "\t" '{print $2"\t"$1}' > term_names.tsv

done

