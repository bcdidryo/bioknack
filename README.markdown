bioknack
========

*bioknack* is going to be an accumulation of tools that
are relevant to bioinformatic applications. The tool set
will be updated every time I get the knack of solving a
problem which is sufficiently significant to be of public
interest. For now, *bioknack* consists of only one
contribution, but this will change eventually.

Prerequisites
-------------

You need to install the following programs to run *bioknack*:

* Ruby 1.8
* Ruby Gems 1.3

Installing *bioknack*
---------------------

There is no installation per se, because *bioknack* is only a
collection of Ruby scripts. They can be retrieved as follows:

    git clone git://github.com/joejimbo/bioknack.git

This will create a directory called `bioknack` with the *bioknack*
scripts in it.

*bioknack* Scripts
------------------

Right now, there is only a measly single script in *bioknack*:

* **chagger**
  * Augments a part-of-speech tagged documents with character-based
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
    * `chagger.pl source.txt tagged.txt` produces the output "Functional\_JJ(0,10)
      association\_NN(11,22)
      of\_IN(23,25)
      Nmi\_NNP(26,29)
      with\_IN(30,34)
      Stat5\_NNP(35,40)
      and\_CC(41,44)
      Stat1\_NNP(45,50) *[...]*"

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

