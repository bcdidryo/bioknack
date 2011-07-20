#!/usr/bin/ruby

require 'optparse'

@names_only = false
@omit_obsolete = false

def print_help()
	puts 'TODO'
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

