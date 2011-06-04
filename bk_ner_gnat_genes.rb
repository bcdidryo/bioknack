#!/usr/bin/ruby

require 'optparse'
require 'net/http'
require 'uri'

def print_help()
	puts 'Usage: bk_ner_gnat_genes.rb (--pmid PMID | --pmcid PMCID)'
	puts '  -a PMID | --pmid PMID : Pubmed ID'
	puts '  -b PMCID | --pmcid PMCID : Pubmed Central ID'
	puts ''
	puts 'Example:'
	puts 'bk_ner_gnat_genes.rb --pmcid PMC2885420'
end

query = nil

options = OptionParser.new { |option|
	option.on('-a', '--pmid PMID') { |id| query = "pmid=#{id}" }
	option.on('-b', '--pmcid PMCID') { |id| query = "pmc=#{id}" }
}

begin
	options.parse!
rescue OptionParser::InvalidOption
	print_help()
	exit
end

if ARGV.length != 0 or query == nil then
	print_help()
	exit
end

url = URI.parse("http://bergmanlab.smith.man.ac.uk:8081")
res = Net::HTTP.start(url.host, url.port) {|http|
	begin
		http.get("/?#{query}&task=gnorm")
	rescue
		puts "ERROR: Cannot retrieve results for query #{query}"
		exit
	end
}

genes = {}

res.body.each_line { |line|
	# line format:
	# PMC2885420	PubMedCentral	gene	10090;10090;10090	110991;11522;58810	1192	1212	alcohol dehydrogenase	1.0
	id, source, type, tax_ids, gene_ids, ner_start, ner_end, name, score = line.split("\t")

	next unless type == 'gene'

	id = id.sub(/^\D+/, '').to_i
	score = score.to_f
	gene_ids = gene_ids.split(';')

	gene_ids.each { |gene|
		gene = gene.to_i
		scores = genes[id]
		mentions = []

		scores = {} unless scores
		mentions = scores[score] if scores.has_key?(score)

		mentions << gene
		scores[score] = mentions
		genes[id] = scores
	}
}

genes.keys.sort.each { |id|
	scores = genes[id]
	scores.keys.sort.reverse.each { |score|
		scores[score].each { |gene|
			puts "#{id}\t#{gene}\t#{score}"
		}
	}
}

