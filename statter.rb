#!/usr/bin/ruby

require 'optparse'

def print_help()
        puts 'Usage: statter.rb [-t] [-f beta] goldfile evaluatefile'
        puts '  -t | --tsv              : output tabulator separated num. values of'
	puts '                            true positives, false positives, false'
	puts '                            negatives, precision, recall and f-score'
	puts '  -f beta | --fscore beta : compute F_beta score, default 1.0'
end

$beta = 1.0
$tsv = false

options = OptionParser.new { |option|
        option.on('-t', '--tsv') { $tsv = true }
	option.on('-f', '--fscore BETA') { |beta| $beta = beta.to_f }
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

gold_file_name = ARGV[0]
eval_file_name = ARGV[1]

gold_file = File.open(gold_file_name, 'r')
eval_file = File.open(eval_file_name, 'r')

reference = {}
gold_file.each { |line|
	fields = line.split("\t")
	positions = fields[1].sub(/.+\ (\d+)\ (\d+)/, '\1 \2').split
	
	reference[positions[0].chomp] = [ positions[1].chomp, fields[2].chomp ]
}

tested_positions = []
true_positives = 0	# Match found and it is in the gold standard
false_positives = 0	# Match found, but it is not in the gold standard
eval_file.each { |line|
	start, stop, type, word = line.split("\t")

	start.chomp!
	stop.chomp!
	type.chomp!
	word.chomp!

	match = reference[start]
	tested_positions << start

	if match then
		if match[0] == stop then
			if match[1] == word then
				puts "+\t#{start}\t#{stop}\t#{word}\t#{match[1]}" unless $tsv
				true_positives += 1
			else
				puts "-\t#{start}\t#{stop}\t#{word}\t#{match[1]}" unless $tsv
				false_positives += 1
			end
		else
			puts "!\t#{start}\t#{stop}\t#{word}\t#{match[1]}" unless $tsv
			false_positives += 1
		end
	else
		puts "-\t#{start}\t#{stop}\t#{word}\t-" unless $tsv
		false_positives += 1
	end
}

false_negatives = 0     # No match found, but there is one in the gold standard
reference.each_pair { |start, reference|
	stop, word = reference

	if not tested_positions.include?(start) then
		puts "?\t#{start}\t#{stop}\t-\t#{word}" unless $tsv
		false_negatives += 1
	end
}

gold_file.close
eval_file.close

# The actual statistics:
precision = true_positives.to_f / (true_positives + false_positives)
recall = true_positives.to_f / (true_positives + false_negatives)
f_score = (1.0 + $beta * $beta) * precision * recall / ($beta * $beta * precision + recall)

if $tsv then
	puts "#{true_positives}\t#{false_positives}\t#{false_negatives}\t#{precision}\t#{recall}\t#{f_score}"
	exit
end

puts '* true positives: ' << true_positives.to_s
puts '* false positives: ' << false_positives.to_s
puts '* false negatives: ' << false_negatives.to_s
puts '* precision: ' << precision.to_s
puts '* recall: ' << recall.to_s
puts '* f-score: ' << f_score.to_s

