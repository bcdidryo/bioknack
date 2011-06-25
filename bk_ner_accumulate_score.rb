#!/usr/bin/ruby

previous_document = nil
previous_gene = nil

score = 0

STDIN.each_line { |line|
	line.chomp!

	columns = line.split("\t")

	if columns[0] == previous_document and columns[1] == previous_gene then
		score += columns[2].to_i
	else
		puts "#{previous_document}\t#{previous_gene}\t#{score}" if previous_document

		previous_document = columns[0]
		previous_gene = columns[1]
		score = columns[2].to_i
	end
}

puts "#{previous_document}\t#{previous_gene}\t#{score}" if previous_document

