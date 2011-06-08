#!/usr/bin/ruby

require 'optparse'
require 'thread'

@sentence_chunks = /\W|\w+/

@dictionary = {}
@lookahead = {}
@lookahead_min = {}

@read_lock = Mutex.new
@write_lock = Mutex.new

# Modes for the dictionary:
#  :functional - 1:1 mapping of keys to values
#  :relational - 1:n mapping of keys to values
@mode = :functional

# Separator used to fuse values when @mode is :relational
@separator = "\t"

@threads = 4
@consecutive_reads = 1000
@consecutive_writes = 1000

# Creates dictionary entries and associates 'xref' with the dictionary entry.
def distribute(dictionary_entry, xref)
	dictionary_entry.downcase!
	words = dictionary_entry.scan(@sentence_chunks)
	arity = words.length

	return unless arity > 0

	@dictionary[arity] = {} if not @dictionary.has_key?(arity)

	arity_dictionary = @dictionary[arity]
	key = words.join()
	case @mode
	when :functional
		arity_dictionary[key] = xref
	when :relational
		set = arity_dictionary[key]
		set = [] unless set
		set |= [ xref ]
		arity_dictionary[key] = set
	else
		raise 'Unknown mode. Check the comments to @mode in the source.'
	end

	@lookahead_min[words[0]] = arity unless @lookahead_min.has_key?(words[0])
	@lookahead_min[words[0]] = arity if @lookahead_min[words[0]] > arity

	words.each_with_index { |word, index|
		prefix = words[0..index].join()
		@lookahead[prefix] = arity unless @lookahead.has_key?(prefix)
		@lookahead[prefix] = arity if @lookahead[prefix] < arity
	}
end

def print_help()
	puts 'Usage: bk_ner.rb [options] database dictionary'
	puts 'Options:'
	puts '  -m MODE | --mode MODE           : dictionary key/value mapping (default: ' << @mode << ')'
	puts '                                    values for MODE:'
	puts '                                      functional - 1:1 mapping between keys and values'
	puts '                                      relational - 1:n mapping between keys and values'
	puts '  -s CHAR | --separator CHAR      : character to use to join multiple values with'
	puts '                                    MODE :relational (default: \t)'
	puts '  -t THREADS | --threads THREADS  : number of threads (default: ' << @threads.to_s << ')'
	puts '  -r READS | --reads READS        : consecutive reads (default: ' << @consecutive_reads.to_s << ')'
	puts '  -w WRITES | --writes WRITES     : consecutive writes (default: ' << @consecutive_writes.to_s << ')'
	puts ''
	puts 'Fastest with JRuby due to thread usage.'
	puts ''
	puts 'NCBI Gene Data:'
	puts '  ftp://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz'
end

options = OptionParser.new { |option|
	option.on('-m', '--mode MODE') { |m|
		case m
		when 'functional'
			@mode = :functional
		when 'relational'
			@mode = :relational
		else
			@mode = :unknown
		end
	}
	option.on('-s', '--separator CHAR') { |char| @separator = char }
	option.on('-t', '--threads THREADS') { |threads_no| @threads = threads_no.to_i }
	option.on('-r', '--reads READS') { |reads| @consecutive_reads = reads.to_i }
	option.on('-w', '--writes WRITES') { |writes| @consecutive_writes = writes.to_i }
}

begin
	options.parse!
rescue OptionParser::InvalidOption
	print_help()
	exit
end

if @mode == :unknown then
	print_help()
	exit
end

if ARGV.length != 2 then
	print_help()
	exit
end

database_file_name = ARGV[0]
dictionary_file_name = ARGV[1]

database_file = File.open(database_file_name, 'r')
dictionary_file = File.open(dictionary_file_name, 'r')

xref_alternative = ""

dictionary_file.each { |line|
	token, xref = line.split("\t", 2)

	if xref then
		xref.chomp!
		distribute(token, xref)
	else
		token.chomp!
		distribute(token, xref_alternative)
	end
}

dictionary_file.close

def munch(line, digest)
        id, text = line.split("\t", 2)

	offset = 0
	text.downcase!
	words = text.scan(@sentence_chunks)
	return unless words
	while (max_arity = words.length) > 0
		arity = @lookahead_min[words[0]]
		while arity and arity <= max_arity
			word_or_compound = words[0..arity - 1].join()

			word_arity = @lookahead[word_or_compound]
			break unless word_arity
			max_arity = word_arity if word_arity < max_arity

			arity_dictionary = @dictionary[arity]
			if arity_dictionary then
				dictionary_entry = arity_dictionary[word_or_compound]
				if dictionary_entry then
					boundary = offset + word_or_compound.length - 1
					dictionary_entry = dictionary_entry.join(@separator) if @mode == :relational
					digest << "#{id}\t#{word_or_compound}\t#{offset.to_s}\t#{boundary.to_s}\t#{dictionary_entry}"
				end
			end

			arity += 1
		end
		offset += words[0].length
		words.shift
	end
end

threads = []

for i in 1..@threads
	threads << Thread.new {
		eof_reached = false
		retries = 0
		lines = []
		digest = []
		begin
			begin
				if not eof_reached
					lines.clear
					@read_lock.synchronize {
						for x in 1..@consecutive_reads
							lines << database_file.readline
						end
					}
				end
				lines.each { |line|
					munch(line, digest)
				}
				if digest.length > @consecutive_writes
					@write_lock.synchronize {
						digest.each { |line|
							puts line
						}
					}
					digest.clear
				end
			end while not eof_reached
		rescue IOError => e	# Hopefully due to EOF
			eof_reached = true
			begin
				retries += 1
				retry
			end if retries == 0
		end
		@write_lock.synchronize {
			digest.each { |line|
				puts line
			}
		}
	}
end

threads.each { |thread|
	thread.join
}

database_file.close

