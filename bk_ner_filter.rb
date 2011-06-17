#!/usr/bin/ruby

require 'optparse'

filter_column = 4 - 1
filter_non_words = true
split_compounds = false

options = OptionParser.new { |option|
	option.on('-c', '--column COLUMN') { |column| filter_column = column.to_i - 1 }
}

begin
	options.parse!
rescue OptionParser::InvalidOption
	exit
end

source_file_name = ARGV[0]
filter_word_file_name = ARGV[1]

source_file = File.open(source_file_name, 'r')
filter_word_file = File.open(filter_word_file_name, 'r')

filters = {}
filter_word_file.each { |line|
	line.strip!

	filters[line] = true

	words = line.split(' ')
	if words.length > 1 then
		words.each { |word|
			filters[word] = true
		}
	end
}

filter_word_file.close()

source_file.each { |line|
	columns = line.split("\t")
	word_or_compound = columns[filter_column]

	next if filters[word_or_compound]
	next if filter_non_words and not word_or_compound.match(/[a-zA-Z]/)
	if split_compounds then
		words = word_or_compound.split(' ')

		filtered = false
		words.each { |word|
			filtered |= filters[word]
		}
		next if filtered
	end

	puts line
}

source_file.close()

