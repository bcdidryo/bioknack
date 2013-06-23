#!/usr/bin/ruby

require 'optparse'

@names_only = false
@omit_obsolete = false

def print_help()
	puts 'Usage: bk_ner_fmt_obo.rb [options] < input.obo'
	puts ''
	puts 'Reads an OBO file from standard input and outputs a two-column TSV file'
	puts 'on standard output with the following columns:'
	puts '  1. OBO term name or OBO term synonym'
	puts '  2. OBO id'
	puts ''
	puts 'Options:'
	puts '  -n | --names-only    : omit synonyms in output'
	puts '  -o | --omit-obsolete : do not output information of obsolete terms'
end

options = OptionParser.new { |option|
	option.on('-n', '--names-only') { @names_only = true }
	option.on('-o', '--omit-obsolete') { @omit_obsolete = true }
}

begin
	options.parse!
rescue OptionParser::InvalidOption
	print_help()
	exit
end

is_term = false
id = nil

def unfold(synonym)
	return [synonym] unless synonym.match(/^\([^)]+\) or \(.+\)$/)

	return synonym.scan(/\(([^)]+)\)/).flatten
end

output = []

STDIN.each { |line|
	line.chomp!

	if line == '[Term]' then
		output.clear
		is_term = true
	end
	if line == '' then
		output.each { |line| puts line } if is_term
		is_term = false
	end
	next unless is_term

	is_term = false if @omit_obsolete and line == 'is_obsolete: true'

	id = line['id: '.length..line.length-1] if line.start_with?('id: ')
	next unless id

	output << "#{line['name: '.length..line.length-1]}\t#{id}" if line.start_with?('name: ')
	unfold(line.match(/\"([^"]+)\"/)[1]).each { |synonym| output << "#{synonym}\t#{id}" } if line.start_with?('synonym: ') and not @names_only
}

