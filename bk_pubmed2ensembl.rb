#!/usr/bin/ruby

require 'rubygems'

require 'biomart'
require 'optparse'

p2e_url = 'http://pubmed2ensembl56.smith.man.ac.uk/biomart'

@species = 'hsapiens'
@gene = nil
@mode = :unknown
@bulk = nil

def print_help()
	puts 'Usage: bk_pubmed2ensembl.rb [-l] [-s species] [-g gene] [-b file]'
	puts 'Options:'
	puts '  -l | --list              : list available species and exit'
	puts "  -s | --species species   : run query for this species (default: #{@species})"
	puts '  -g | --gene gene         : Ensembl gene ID to query for PubMed IDs'
	puts '  -b | --bulk file         : read Ensembl gene IDs from file (one line per ID)'
	puts '  -i | --interactive       : reads Ensembl gene IDs from STDIN (one line per ID)'
	puts ''
	puts 'TSV Output Format:'
	puts '  1st column: pubmed2ensembl BioMart attribute name'
	puts '  2nd column: PubMed ID'
	puts '  3rd column: Ensembl gene ID (only present for -b or -i)'
	puts ''
	puts 'Examples:'
	puts '  bk_pubmed2ensembl.rb -g ENSG00000139618'
	puts '  bk_pubmed2ensembl.rb -s dmelanogaster -g FBgn0001325'
	puts '  bk_pubmed2ensembl.rb -s mmusculus -b genes.lst'
	puts '    genes.lst content: ENSMUSG00000017167\nENSMUSG00000002871'
	puts '  bk_pubmed2ensembl.rb -i -s drerio'
	puts '    enter on on the console: ENSDARG00000024771\nENSDARG00000020635\n'
	puts ''
	puts 'Notes:'
	puts '  Start-up and first query are slow, but following queries in bulk or'
	puts '  interactive modes are fast.'
end

def query(dataset, p2e_attributes, gene, xtra=nil)
	result = dataset.search(:filters => { 'ensembl_gene_id' => gene }, :attributes => p2e_attributes)

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
			puts "#{result[:headers][index]}\t#{id}" << (xtra ? "\t#{xtra}" : "")
		}
	}
}

end

options = OptionParser.new { |option|
	option.on('-l', '--list') { @mode = :list }
	option.on('-s', '--species SPECIES') { |speciesname| @species = speciesname }
	option.on('-g', '--gene GENE') { |geneid|
		@gene = geneid
		@mode = :query
	}
	option.on('-b', '--bulk FILE') { |filename|
		@bulk = IO.read(filename)
		@mode = :query
	}
	option.on('-i', '--interactive') { @mode = :interactive }
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

unless @mode == :query or @mode == :interactive then
	print_help()
	exit
end

dataset = biomart.datasets["#{@species}_gene_ensembl"]

p2e_attributes = []

dataset.attributes.each { |attribute|
        name = attribute[0]
        p2e_attributes << name if name.match(/flat.+pmid/)
}

case @mode
when :query
	if @bulk then
		@bulk.each_line { |line|
			line.chomp!
			query(dataset, p2e_attributes, line, line)
		}
	else
		query(dataset, p2e_attributes, @gene)
	end
when :interactive
	$stdin.each_line { |line|
		line.chomp!
		next if line.empty?
		query(dataset, p2e_attributes, line, line)
	}
end

