#!/usr/bin/ruby

require 'optparse'

def print_help()
	puts 'Usage: bk_intersection.rb file1 file2'
	puts ''
	puts 'Creates a dictionary of each line of file1 and'
	puts 'then outputs the intersection with each line of'
	puts 'file2.'
end

options = OptionParser.new { |option|
}

begin
	options.parse!
rescue OptionParser::InvalidOption
	print_help()
	exit
end

if ARGV.length != 2 then
	print_help()
	exit
end

filename1 = ARGV[0]
filename2 = ARGV[1]

file1 = File.open(filename1, 'r')
file2 = File.open(filename2, 'r')

dictionary = {}

file1.each { |line|
	dictionary[line.chomp!] = 1
}

file2.each { |line|
	line.chomp!

	puts line if dictionary[line]
}

file1.close
file2.close

