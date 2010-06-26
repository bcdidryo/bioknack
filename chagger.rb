#!/usr/bin/ruby

if ARGV.length != 2 then
	puts 'Usage: ...'
	exit
end

text_file = File.open(ARGV[0], 'r')
tagged_file = File.open(ARGV[1], 'r')

text = ''
while line = text_file.gets do text << line end

tagged_text = ''
while line = tagged_file.gets do tagged_text << line end

tokens = tagged_text.split

cursor = 0
tokens.each { |token|
	word = token.sub(/_.+$/, '')
	word.gsub!(/(\\)(.)/, '\2') # Remove escape characters.
	first_appearance = text.index(word)

	if not first_appearance then
		puts 'Blimey!'
		puts 'Cannot find "' << word << '" in the text.'
		exit
	end

	token_start = cursor + first_appearance
	token_end = token_start + word.length

	puts "#{token}(#{token_start},#{token_end})"

	text = text[first_appearance + word.length..-1]
	cursor = token_end
}

