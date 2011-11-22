bioknack
========

![bioknack logo](https://github.com/joejimbo/bioknack/raw/master/logo/bioknack120.png)

*bioknack* is a potpourri of bioinformatics tools. The tool-set
is be updated every time I get the knack of having a go at a
problem which is sufficiently significant to be of public
interest. For now, *bioknack* consists only of my contributions,
but this will hopefully change eventually.

Prerequisites
-------------

You need to install the following programs to run *bioknack*:

* Ruby 1.8
* Ruby Gems 1.3

*bioknack* also works with Ruby 1.9 and JRuby. **For tools that
support multi-threading, it is best to run them with JRuby, since
the standard implementations do not truly support running threads
in parallel.**

Installing *bioknack*
---------------------

There is no installation per se, because *bioknack* is only a
collection of Ruby and BASH scripts. You can get *bioknack*  as follows:

    git clone git://github.com/joejimbo/bioknack.git

This will create a directory called `bioknack` with the *bioknack*
scripts in it.

*bioknack* Scripts
------------------

Almost all scripts mentioned below will output a usage message when executed without parameters.

### Flagships

* **bk_ner_gn.sh**
  * Wrapper for recognising entities with `bk_ner.rb`
  * Automatic download and preparation of dictionaries
  * Automatic download of PubMed Central's open-access subset
* **bk_ner.rb**
  * Recognises entities in text.
  * Many modes for recognising genes, species and ontology terms

### Other Scripts

* **bk_pos_token_positions.rb**
  * Augments a part-of-speech tagged document with character-based
    positions for each token that indicate the token's position in
    the original text.
* **bk_ner_gnat_genes.rb**
  * Uses the public web-service of GNAT/LINNAEUS to find gene mentions in abstracts
    of MEDLINE articles (via Pubmed ID) or full-text articles of Pubmed Central (via
    Pubmed Central ID). Returns the document ID, Entrez gene ID and a confidence score.
* **bk_mesh_mysql_import.rb**
  * Imports MeSH-descriptor .bin-files into a MySQL-database. The script will create
    tables `descriptor`, `descriptor_backfile_posting` and `descriptor_entry`. All
    tables are denormalised.
    * `descriptor` will contain one column for each key in the .bin-file, except for
      the keys `ENTRY` and the backfile postings (keys `MED` and `Mx`, where `x` is
      some integer value. Each record is assigned a unique unsigned integer value in
      the column `ENTRY_KEY`.
    * `descriptor_backfile_posting` contains a column `ENTRY_KEY` and columns for
      backfile postings, which were not included in the table `descriptor`.
    * `descriptor_entry` contains to columns: `ENTRY_KEY` and `ENTRY`, mapping the
      left-out `ENTRY` values in `descriptor` to `ENTRY_KEY`s.
  * The tables are created automatically, where existing tables with the names
    given above will be deleted.
  * The database must exist prior to using this script. It can be empty though.
* **bk_sql_txt_mysql_import.rb**
  * Imports data into a MySQL-database with table descriptions given in .sql-files and
    the tables' contents given in .txt-files.
* **bk_stats_biocreative_3.rb**
  * Takes a gold- or silver-standard file from BioCreative 3 and calculates true positives, false positives,
    precision, recall, F(0.5,1,2) score for a given GN task submission.
* **bk_ner_eval_bionlp09.rb**
  * Compares a `.a1` file of **BioNLP '09** to the output generated
    by an entity recognition tool. It outputs (mis-)matches and statistical
    information (precision, recall and F_beta score).

