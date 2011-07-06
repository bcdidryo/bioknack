#!/usr/bin/ruby

is_term = false
id = nil

STDIN.each { |line|
	line.chomp!

	is_term = true if line == '[Term]'
	is_term = false if line == ''
	next unless is_term

	id = line['id: '.length..line.length-1] if line.start_with?('id: ')
	next unless id

	puts "#{line['name: '.length..line.length-1]}\t#{id}" if line.start_with?('name: ')
	puts "#{line.match(/\"([^"]+)\"/)[1]}\t#{id}" if line.start_with?('synonym: ')
}

