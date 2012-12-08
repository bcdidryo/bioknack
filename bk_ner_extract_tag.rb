#!/usr/bin/ruby

if ARGV.length < 2 or ARGV.length > 3 then
	# TODO
	exit
end

opentag = ARGV[0]
closetag = ARGV[1]
match = 0
match = ARGV[2].to_i if ARGV.length == 3

seen_tags = 0

while chunk = STDIN.gets('>') do
	if seen_tags > 0 and chunk.end_with?(closetag) then
		print chunk[0..-1*closetag.length-1]
		seen_tags -= 1

		if match > 0 and seen_tags == 0 then
			match -= 1
			exit unless match > 0
		end

		next
	end
	print chunk if seen_tags > 0
	seen_tags += 1 if chunk.end_with?(opentag)
end

