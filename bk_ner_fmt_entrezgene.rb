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

	tax, gene, symbol, ignore, synonyms, ignore, ignore, ignore, description = line.split("\t")

	symbol = symbol.split('|')
	synonyms = synonyms.split('|')
	description = description.split(/[^ a-zA-Z0-9\-'()]/)

	print(symbol, tax, gene)
	print(synonyms, tax, gene)
	print(description, tax, gene)
}

