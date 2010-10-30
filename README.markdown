bioknack
========

*bioknack* is going to be an accumulation of tools that
are relevant to bioinformatic applications. The tool set
will be updated every time I get the knack of solving a
problem which is sufficiently significant to be of public
interest. For now, *bioknack* consists of only a couple of
contributions, but this will change eventually.

Prerequisites
-------------

You need to install the following programs to run *bioknack*:

* Ruby 1.8
* Ruby Gems 1.3

*bioknack* also works with Ruby 1.9 and JRuby. For tools that
support multi-threading, it is best to run them with JRuby, since
the standard implementations do not support running threads
in parallel.

Installing *bioknack*
---------------------

There is no installation per se, because *bioknack* is only a
collection of Ruby scripts. They can be retrieved as follows:

    git clone git://github.com/joejimbo/bioknack.git

This will create a directory called `bioknack` with the *bioknack*
scripts in it.

*bioknack* Scripts
------------------

Right now, there are only three measly scripts in *bioknack* as listed below.
Each of the scripts will provide some further information when called without
parameters, whereas the following bullet points describe general aspects of
the programs.

* **bk_pos_token_positions.rb**
  * Augments a part-of-speech tagged document with character-based
    positions for each token that indicate the token's position in
    the original text.
  * Takes as input the original (untagged) text-file and the
    tagged text.
  * In the output, each token is extended by `(x,y)`, where `x` and
    `y` denote the character positions of the token in the original
    text. `x` coincides with the beginning of the token, where as `y`
    is the first character *after* the token in the original text. The
    positions are zero-based. This format is suitable for comparisons
    with the **BioNLP '09** data-set.
  * **Example:**
    * `source.txt` contains "Functional association of
      Nmi with Stat5 and Stat1 *[...]*"
    * `tagged.txt` contains "Functional_JJ association\_NN of\_IN Nmi\_NNP
      with\_IN Stat5\_NNP and\_CC Stat1\_NNP *[...]*"
    * `bk_pos_token_positions source.txt tagged.txt` produces the output "Functional\_JJ(0,10)
      association\_NN(11,22)
      of\_IN(23,25)
      Nmi\_NNP(26,29)
      with\_IN(30,34)
      Stat5\_NNP(35,40)
      and\_CC(41,44)
      Stat1\_NNP(45,50) *[...]*"
* **bk_ner.rb**
  * Recognises entities in text. The script will read text from a TSV file where
    each line represents an identifier/text pair and entities from a second TSV file
    which contains entities in its first column and an optional identifier in its
    second column. Recognised entities are output in TSV format where the columns
    are organised as follows: text identifier, actually matched text,
    start of matched entity in the text (first character, zero based index),
    end of matched entity in the text (index of last matched character),
    optional entity identifier if it was provided.
  * **Example:**
    * `text_db.tsv` contains the lines
      * 14801717\tImunization with influenza virus vaccines
      * 12332212\tTreatment of monoliasis vulvae
    * `phrases.tsv` contains the lines
      * Influenza\t1
      * Influenza Virus\t1.1
      * Treatment Of
    * `bk_ner.rb text_db.tsv phrases.tsv` outputs the following lines:
      * 14801717\tinfluenza\t17\t25\t1
      * 14801717\tinfluenza virus\t17\t31\t1.1
      * 12332212\ttreatment of\t0\t11\t
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
  * **Example:**
    * `bk_mesh_mysql_import.rb -u mysql -p secret d2010.bin mesh2010` logs into the MySQL
      database as user `mysql` with the password `secret` and loads the contents
      of the file `d2010.bin` into the tables `descriptor`, `descriptor_backfile_posting`
      and `descriptor_entry` of the database `mesh2010`.
* **bk_ner_eval_bionlp09.rb**
  * Compares a `.a1` file of **BioNLP '09** to the output generated
    by an entity recognition tool. It outputs (mis-)matches and statistical
    information (precision, recall and F_beta score).
  * Takes as input a `.a1` file and a tab-separated file with the columns
    * character start of recognised entity
    * character stop of recognised entity (one character beyond entity)
    * type of entity (not used)
    * recognised entity
    * **Example:** `1292   1296   gene product   MAPK`
  * The output is either a detailed comparison between the tagged
    contents of the `.a1` file and the entity recognition output, or it is
    simply a tab-separated list of number of true positives, number of
    false positives, number of false negatives, precision, recall and
    F-score (`-t` parameter).
  * **Examples:**
    * `./bk_ner_eval_bionlp09.rb 10089566.a1 10089566.entities`
      * lines beginning with `+` denote a true positive
      * lines beginning with `-` denote a false positive
      * lines beginning with `!` denote an false positive, which
        did mismatch the given character positions
      * lines beginning with `?` denote a false negative
      * lines beginning with `*` denote statistical output
    * `./bk_ner_eval_bionlp09.rb -t -f 2.0 10089566.a1 10089566.entities`
      * outputs tab-separated values for precision, recall and F_2.0 score

---

License
=======

Redistribution and use in source and binary forms, with
or without modification, are permitted provided that the
following conditions are met:

1. Redistributions of source code must retain the above
   copyright notice, this list of conditions and the
   following disclaimer.
2. Redistributions in binary form must reproduce the above
   copyright notice, this list of conditions and the
   following disclaimer in the documentation and/or other
   materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

