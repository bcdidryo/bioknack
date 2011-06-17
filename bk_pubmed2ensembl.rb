#!/usr/bin/ruby

require 'rubygems'

require 'biomart'
require 'optparse'

p2e_url = 'http://pubmed2ensembl56.smith.man.ac.uk/biomart'

@species = 'hsapiens'
@gene = nil
@mode = :unknown

def print_help()
	puts 'Usage: bk_pubmed2ensembl.rb [-l] [-s species] [-g gene]'
	puts 'Options:'
	puts '  -l | --list              : list available species and exit'
	puts "  -s | --species species   : run query for this species (default: #{@species})"
	puts '  -g | --gene gene         : Ensembl gene ID to query PubMed IDs for'
	puts ''
	puts 'Examples:'
	puts '  bk_pubmed2ensembl.rb -g ENSG00000139618'
	puts '  bk_pubmed2ensembl.rb -s dmelanogaster -g FBgn0001325'
end

options = OptionParser.new { |option|
	option.on('-l', '--list') { @mode = :list }
	option.on('-s', '--species SPECIES') { |x| @species = x }
	option.on('-g', '--gene GENE') { |x|
		@gene = x
		@mode = :query
	}
}

begin
	options.parse!
rescue OptionParser::InvalidOption
	print_help()
	exit
end

if ARGV.length != 0 then
	print_help()
	exit
end

biomart = Biomart::Server.new(p2e_url)

if @mode == :list then
	puts "Available species:"
	arr = []
	biomart.datasets.each { |dataset|
		arr << dataset[0].sub('_gene_ensembl', '')
	}
	arr.sort.each { |dataset|
		puts "  #{dataset}"
	}

	exit
end

unless @mode == :query then
	print_help()
	exit
end

dataset = biomart.datasets["#{@species}_gene_ensembl"]

p2e_attributes = []

dataset.attributes.each { |attribute|
        name = attribute[0]
        p2e_attributes << name if name.match(/flat.+pmid/)
}

result = dataset.search(:filters => { 'ensembl_gene_id' => @gene }, :attributes => p2e_attributes)

result[:data].each { |row|
	row.each_index { |index|
		next unless row[index]

		ids = nil
		if row[index].match(/^(\d+,?)*$/) then
			ids = row[index].scan(/(\d+)/)
		else
			ids = row[index].scan(/^(\d+)|&thinsp;(\d+)/)
		end
		next unless ids
		ids.flatten.compact.map { |x| x.to_i }.sort.uniq.each { |id|
			puts "#{result[:headers][index]}\t#{id}"
		}
	}
}

