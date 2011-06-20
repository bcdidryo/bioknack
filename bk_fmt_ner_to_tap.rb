#!/usr/bin/ruby

require 'optparse'

with_annotation = false

options = OptionParser.new { |option|
	option.on('-a', '--annotation') { with_annotation = true }
}

begin
	options.parse!
rescue OptionParser::InvalidOption
	print_help()
	exit
end

ner_file_name = ARGV[0]
standard_file_name = ARGV[1]

documents = {}

ner_file = File.open(ner_file_name, 'r')
standard_file = File.open(standard_file_name, 'r')

standard_file.each { |line|
	document_id, entity_id = line.split("\t")

	entities = documents[document_id]
	entities = {} unless entities

	entity_id.chomp!
	entities[entity_id] = true unless entity_id == '-'
	documents[document_id] = entities
}

standard_file.close()

entity2score = {}
entity2relevance = {}

ner_file.each { |line|
	document_id, entity_id, score = line.split("\t")

	entities = documents[document_id]
	next unless entities

	score.chomp!
	entity2score["#{document_id}|#{entity_id}"] = score
	entity2relevance["#{document_id}|#{entity_id}"] = entities[entity_id]
}

ner_file.close()

summary = File.open('summary.lst', 'w')

documents.keys.each { |document|
	relevant = documents[document].keys.size

	summary.write("#{document}.tap\n")

	document_tap = File.open("#{document}.tap", 'w')

	document_tap.write("#{document}\n")
	document_tap.write("#{relevant}\n")

	sorted_entities = entity2score.keys.sort_by { |key| entity2score[key].to_f }
	sorted_entities.reverse.each { |key|
		next unless key.start_with?("#{document}|")

		if entity2relevance[key] then
			document_tap.write("1\t#{entity2score[key]}")
		else
			document_tap.write("0\t#{entity2score[key]}")
		end

		document_tap.write("\t#{key}") if with_annotation

		document_tap.write("\n")
	}

	document_tap.close()
}

summary.close()

