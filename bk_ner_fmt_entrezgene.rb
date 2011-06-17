#!/usr/bin/ruby

def print(list, tax, gene)
	list.each { |item|
		item.strip!
		next if item.empty? or item == '-'
		puts "#{item}\t#{tax}|#{gene}"
	}
end

STDIN.each { |line|
	next if line.start_with?('#')

	tax, gene, symbol, ignore, synonyms, ignore, ignore, ignore,
		description, ignore, external_symbol, external_name, ignore,
		other_designations = line.split("\t")

	next if symbol == 'NEWENTRY'

	symbol = symbol.split('|')
	synonyms = synonyms.split('|')
	external_symbol = [ external_symbol ]
	external_name = [ external_name ]

	print(symbol, tax, gene)
	print(synonyms, tax, gene)
	print(external_symbol, tax, gene)
	print(external_name, tax, gene)
}

