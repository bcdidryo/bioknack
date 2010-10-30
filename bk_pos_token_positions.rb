#!/usr/bin/ruby

require 'optparse'

$raw = false
$strict = false

def print_help()
        puts 'Usage: chagger.rb [-n] [-r] [-s] originalfile taggedfile'
        puts '  -r | --raw       : do not rewrite escaped characters'
	puts '  -s | --strict    : do not skip words that cannot be resolved'
end

options = OptionParser.new { |option|
        option.on('-r', '--raw') { $raw = true }
        option.on('-s', '--strict') { $strict = true }
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

text_file_name = ARGV[0]
tagged_file_name = ARGV[1]

text_file = File.open(text_file_name, 'r')
tagged_file = File.open(tagged_file_name, 'r')

text = ''
while line = text_file.gets do text << line end

tagged_text = ''
while line = tagged_file.gets do tagged_text << line end

tokens = tagged_text.split

cursor = 0
tokens.each { |token|
	word = token.sub(/_.+$/, '')
	
	if not $raw then
		# Remove escape characters.
		word.gsub!(/(\\)(.)/, '\2')

		# Rewrite brackets.
		word.gsub!(/-LRB-/, '(')
		word.gsub!(/-RRB-/, ')')
	end

	first_appearance = text.index(word)
	blackspace = text.match(/\s*\S/)

	# LRB and RRB can be (, <, etc. We might accidentally match a (, even though we should have matched a [.
	first_appearance = 0 if first_appearance and blackspace and first_appearance > blackspace.to_s.length

	if not first_appearance then
		if $strict then
			puts 'Blimey!'
			puts 'Cannot find "' << word << '" in the text.'
			exit
		end

		# Assume the next word is what we are looking for:
		first_appearance = text.index(/\S/)
		if word.match(/^\W$/) then
			word = text[first_appearance..first_appearance]
		else
			word = text[first_appearance..-1].match(/\S+/).to_s
		end
	end

	token_start = cursor + first_appearance
	token_end = token_start + word.length

	puts "#{token}(#{token_start},#{token_end})"

	text = text[first_appearance + word.length..-1]
	cursor = token_end
}

