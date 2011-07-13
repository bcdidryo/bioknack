#!/usr/bin/ruby

if ARGV.length != 2 then
	# TODO
        exit
end

opentag = ARGV[0]
closetag = ARGV[1]

seen_tags = 0

while chunk = STDIN.gets('>') do
	if chunk.end_with?(closetag) then
		print chunk[0..-1*closetag.length-1] if seen_tags > 0
		seen_tags -= 1
		next
	end
	print chunk if seen_tags > 0
	seen_tags += 1 if chunk.end_with?(opentag)
end

