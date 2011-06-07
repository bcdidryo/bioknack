#!/usr/bin/ruby

require 'optparse'

def print_help()
	puts 'Usage: bk_stats_biocreative_3.rb standard nerfile'
	puts '  standard : gold/silver standard file'
	puts '  nerfile  : output from NER tool'
	puts ''
	puts 'Example:'
	puts 'bk_stats_biocreative_3.rb GNTestEval/test50.gold.txt bc3gn_t68_r1.txt'
end

options = OptionParser.new { |option|
	# Nothing to see here (yet)...
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

standard_file = ARGV[0]
ner_file = ARGV[1]

eval_pmcids = {}
std = {}
ner = {}

tp = 0
fp = 0
fn = 0

File.open(standard_file) { |standard|
	standard.each_line { |line|
		pmcid, geneid = line.split(/\s/)

		eval_pmcids[pmcid] = true
		std["#{pmcid}-#{geneid}"] = true
	}
}

File.open(ner_file) { |results|
	results.each_line { |line|
		pmcid, geneid, score = line.split(/\s/)

		next unless eval_pmcids[pmcid]

		ner["#{pmcid}-#{geneid}"] = true
		if std["#{pmcid}-#{geneid}"] then
			tp += 1
		else
			fp += 1
		end
	}
}

std.keys.each { |key|
	fn += 1 unless ner.has_key?(key)
}

precision = tp/(1.0*tp+fp)
recall = tp/(1.0*tp+fn)

puts "True positives: #{tp}"
puts "False positives: #{fp}"
puts "Precision: #{precision}"
puts "Recall: #{recall}"
puts "F0.5 score: #{1.25*precision*recall/(0.25*precision+recall)}"
puts "F1 score: #{2.0*precision*recall/(precision+recall)}"
puts "F2 score: #{5.0*precision*recall/(4.0*precision+recall)}"

