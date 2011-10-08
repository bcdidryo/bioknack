#!/usr/bin/ruby

require 'rubygems'
require 'biomart'
require 'optparse'

p2e_url = 'http://pubmed2ensembl56.smith.man.ac.uk/biomart'

@species = 'hsapiens'
@gene = nil
@document = nil
@attribute = nil
@mode = :unknown
@bulk = nil

@id_type = :pmid

def print_help()
	puts 'Usage: bk_pubmed2ensembl.rb [-l] [-a] [-p] [-s species] [-g gene] [-d document/attribute] [-b file]'
	puts 'Options:'
	puts '  -l | --list                   : list available species and exit'
	puts '  -a | --attributes             : list available pubmed2ensembl attributes and exit'
	puts '  -p | --pmcids                 : retrieve PubMed Central IDs instead of PubMed IDs'
	puts "  -s | --species species        : run query for this species (default: #{@species})"
	puts '  -g | --gene gene              : Ensembl gene ID to query for PubMed IDs/PubMed Central IDs'
	puts '  -d | --document id/attribute  : PubMed/PubMed Central ID to query for gene IDs'
	puts '  -b | --bulk file              : read Ensembl gene IDs from file (one line per ID)'
	puts '  -i | --interactive            : reads Ensembl gene IDs from STDIN (one line per ID)'
	puts ''
	puts 'TSV Output Format:'
	puts '  1st column: pubmed2ensembl BioMart attribute name'
	puts '  2nd column: PubMed ID'
	puts '  3rd column: Ensembl gene ID (only present for -b or -i)'
	puts ''
	puts 'Examples:'
	puts '  bk_pubmed2ensembl.rb -g ENSG00000139618'
	puts '  bk_pubmed2ensembl.rb -d PMC408463/pmcid_1099'
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

def query(dataset, p2e_attributes, id, xtra=nil)
	filter = { 'ensembl_gene_id' => id } unless @id_type == :document
	filter = { @attribute => id } if @id_type == :document

	result = dataset.search(:filters => filter, :attributes => p2e_attributes)

	result[:data].each { |row|
	row.each_index { |index|
		next unless row[index]

		ids = nil

		case @id_type
		when :document
			ids = [ row[index] ]
		else
			if row[index].match(/^((PMC)?\d+,?)*$/) then
				ids = row[index].scan(/((PMC)?\d+)/)
			else
				ids = row[index].scan(/^((PMC)?\d+)|&thinsp;((PMC)?\d+)/)
			end
			ids.flatten!
			ids.delete_if { |id| id == nil or id == 'PMC' }
		end

		next unless ids
	
		case @id_type
		when :pmid
			ids.flatten.compact.map { |x| x.to_i }.sort.uniq.each { |id|
				puts "#{result[:headers][index]}\t#{id}" << (xtra ? "\t#{xtra}" : "")
			}
		else
			ids.flatten.compact.sort.uniq.each { |id|
				puts "#{result[:headers][index]}\t#{id}" << (xtra ? "\t#{xtra}" : "")
			}
		end
	}
}

end

options = OptionParser.new { |option|
	option.on('-l', '--list') { @mode = :list }
	option.on('-a', '--attributes') { @mode = :attributes }
	option.on('-s', '--species SPECIES') { |speciesname| @species = speciesname }
	option.on('-d', '--document IDATTR') { |id_attribute|
		@document, @attribute = id_attribute.split('/', 2)
		@id_type = :document
		@mode = :query
	}
	option.on('-g', '--gene GENE') { |geneid|
		@gene = geneid
		@mode = :query
	}
	option.on('-b', '--bulk FILE') { |filename|
		@bulk = IO.read(filename)
		@mode = :query
	}
	option.on('-i', '--interactive') { @mode = :interactive }
	option.on('-p', '--pmcids') { @id_type = :pmcid }
}

begin
	options.parse!
rescue OptionParser::InvalidOption
	print_help()
	exit 1
end

if ARGV.length != 0 then
	print_help()
	exit 1
end

biomart = Biomart::Server.new(p2e_url)

if @mode == :list or @mode == :attributes then
	puts 'Available species:' if @mode == :list
	puts 'Available attributes:' if @mode == :attributes
	arr = []
	biomart.datasets.each { |dataset|
		arr << dataset[0].sub('_gene_ensembl', '') if @mode == :list
		arr = dataset[1].list_attributes if @mode == :attributes and dataset[0] == 'hsapiens_gene_ensembl'
	}
	arr.delete_if { |attribute| attribute.match(/^pmc?id_\d+$/) == nil } if @mode == :attributes
	arr.sort.each { |x|
		puts "  #{x}"
	}

	exit
end

unless @mode == :query or @mode == :interactive then
	print_help()
	exit 1
end

dataset = biomart.datasets["#{@species}_gene_ensembl"]

p2e_attributes = []

if @id_type == :document then
	p2e_attributes = [ 'ensembl_gene_id' ]
else
	dataset.attributes.each { |attribute|
		name = attribute[0]
		p2e_attributes << name if @id_type == :pmid and name.match(/flat.+pmid/)
		p2e_attributes << name if @id_type == :pmcid and name.match(/flat.+pmcid/)
	}
end

if @id_type == :document and p2e_attributes.empty? then
	puts 'No attribute selected.'
	puts ''
	puts 'Get the list of queryable document attributes with -a and then'
	puts 'set the query with "-d documentid/attributename"'
	exit 1
end

case @mode
when :query
	if @bulk then
		@bulk.each_line { |line|
			line.chomp!
			query(dataset, p2e_attributes, line, line)
		}
	else
		query(dataset, p2e_attributes, @gene) unless @id_type == :document
		query(dataset, p2e_attributes, @document) if @id_type == :document
	end
when :interactive
	$stdin.each_line { |line|
		line.chomp!
		next if line.empty?
		query(dataset, p2e_attributes, line, line)
	}
end

