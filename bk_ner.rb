#!/usr/bin/ruby

require 'optparse'
require 'set'
require 'thread'

@sentence_chunks = /\W|\w+/

@dictionary = {}
@lookahead = {}
@lookahead_min = {}

@read_lock = Mutex.new
@write_lock = Mutex.new

# If @brief is true, then do not repeat dictionary matches per munch-call
# (makes only sense in conjunction with @concise = true, really)
@brief = false

# If @concise is true, then do not output character positions
@concise = false

# If @lines is true, then multiple dictionary matches (with @mode == :relational)
# are written on separate lines instead of concatening the dictionary entries
@lines = false

# Modes for the dictionary:
#  :functional - 1:1 mapping of keys to values
#  :relational - 1:n mapping of keys to values
@mode = :functional

# Separator used to fuse values when @mode is :relational
@separator = "\t"

# The @delimiter string can be a chunk that should be treated as a "end-of-compound"
# marker. If not nil, then matching sentence chunks need to be terminated
# by this string or they are ignored.
@delimiter = nil

# Replaces occurrences of the string @regexper with @replacement and then
# runs the entity recognition on that regular expression. Has to be used with
# -c, because the character position are not determined anymore to achieve good
# performance still.
# @regexper_prefix and @regexper_suffix are surrounding the regular expression
# to ensure that we start matching entities on word boundaries.
# @regexper_dictionary contains the Regexp instance that is used for the matching
# in the text.
@regexper = nil
@regexper_prefix = '(^|[ .,;:!?])'
@regexper_suffix = '($|[ .,;:!?])'
@replacement = '\W([^.!?]+\W)?'
@regexper_dictionary = {}

# Whether to be case sensitive or not.
@case_sensitive = false

@threads = 4
@consecutive_reads = 1000
@consecutive_writes = 1000

# Creates dictionary entries and associates 'xref' with the dictionary entry.
def distribute(dictionary_entry, xref)
	dictionary_entry.downcase! unless @case_sensitive
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
		unless set then
			set = Set.new
			arity_dictionary[key] = set
		end
		set.add(xref)
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

	if @regexper then
		dictionary_entry_regexped = Regexp.escape(dictionary_entry).gsub(@regexper, @replacement)
		@regexper_dictionary[dictionary_entry] =
			Regexp.new("#{@regexper_prefix}#{dictionary_entry_regexped}#{@regexper_suffix}")
	end
end

def print_help()
	puts 'Usage: bk_ner.rb [options] database dictionary'
	puts 'General Options:'
	puts '  -b | --brief                    : do not repeat matched dictionary entries (per document)'
	puts '  -c | --concise                  : do not output character positions'
	puts '  -d CHAR | --delimiter CHAR      : match only full-length words/compounds between the delimiter'
	puts '                                    (lines in the corpus need to end on the delimiter, or the'
	puts '                                    last entry will not be matched)'
	puts '  -l | --lines                    : write multiple dictionary matches on separate lines'
	puts '  -m MODE | --mode MODE           : dictionary key/value mapping (default: ' << @mode.to_s << ')'
	puts '                                    values for MODE:'
	puts '                                      functional - 1:1 mapping between keys and values'
	puts '                                      relational - 1:n mapping between keys and values'
	puts '  -s CHAR | --separator CHAR      : character to use to join multiple values in the output'
	puts '                                    when MODE is :relational and -l is not used'
	puts '                                    (default: \t (tabulator))'
	puts '  -x | --casesensitive            : case sensitive dictionary matching'
	puts '  -y | --regexper CHAR            : replaces the given character (or string) in the'
	puts '                                    dictionary entries with ' << @replacement << ' and then'
	puts '                                    matches documents against the resulting regular expression'
	puts '                                    (has to be used with -c, because character positions are'
	puts '                                    no longer determined to achieve good performance)'
	puts ''
	puts 'Performance Options:'
	puts '  -t THREADS | --threads THREADS  : number of threads (default: ' << @threads.to_s << ')'
	puts '  -r READS | --reads READS        : consecutive reads (default: ' << @consecutive_reads.to_s << ')'
	puts '  -w WRITES | --writes WRITES     : consecutive writes (default: ' << @consecutive_writes.to_s << ')'
	puts ''
	puts 'Fastest with JRuby due to thread usage.'
	puts ''
	puts 'NCBI Gene Data:'
	puts '  ftp://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz'
	puts 'RefSeq Gene Data (substitute XX with the latest release):'
	puts '  ftp://ftp.ncbi.nih.gov/refseq/release/release-catalog/releaseXX.accession2geneid.gz'
end

options = OptionParser.new { |option|
	option.on('-b', '--brief') { @brief = true }
	option.on('-c', '--concise') { @concise = true }
	option.on('-d', '--delimiter CHAR') { |char| @delimiter = char }
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
	option.on('-l', '--lines') { @lines = true }
	option.on('-s', '--separator CHAR') { |char| @separator = char }
	option.on('-t', '--threads THREADS') { |threads_no| @threads = threads_no.to_i }
	option.on('-r', '--reads READS') { |reads| @consecutive_reads = reads.to_i }
	option.on('-w', '--writes WRITES') { |writes| @consecutive_writes = writes.to_i }
	option.on('-x', '--casesensitive') { @case_sensitive = true }
	option.on('-y', '--regexper CHAR') { |char| @regexper = char }
}

begin
	options.parse!
rescue OptionParser::InvalidOption
	print_help()
	exit 1
end

if @mode == :unknown then
	print_help()
	exit 1
end

if ARGV.length != 2 then
	print_help()
	exit 1
end

database_file_name = ARGV[0]
dictionary_file_name = ARGV[1]

database_file = File.open(database_file_name, 'r')
dictionary_file = File.open(dictionary_file_name, 'r')

xref_alternative = ""

dictionary_file.each { |line|
	entity, xref = line.split("\t", 2)

	if xref then
		if @mode == :functional then
			xref.chomp!
			distribute(entity, xref)
		else
			xref.split("\t").each { |xref_n|
				xref_n.chomp!
				distribute(entity, xref_n)
			}
		end
	else
		entity.chomp!
		distribute(entity, xref_alternative)
	end
}

dictionary_file.close

def output_recognition(id, dictionary_entry, seen_entries, word_or_compound, offset, digest)
	if !@brief or !seen_entries[word_or_compound] then
		seen_entries[word_or_compound] = true if @brief
		boundary = offset + word_or_compound.length - 1
		dictionary_entry = dictionary_entry.keys.join(@separator) if @mode == :relational and not @lines
		unless @concise then
			if @mode == :relational and @lines then
				dictionary_entry.each { |entry|
					digest << "#{id}\t#{word_or_compound}\t#{offset.to_s}\t#{boundary.to_s}\t#{entry}"
				}
			else
				digest << "#{id}\t#{word_or_compound}\t#{offset.to_s}\t#{boundary.to_s}\t#{dictionary_entry}"
			end
		else
			if @mode == :relational and @lines then
				dictionary_entry.each { |entry|
					digest << "#{id}\t#{word_or_compound}\t#{entry}"
				}
			else
				digest << "#{id}\t#{word_or_compound}\t#{dictionary_entry}"
			end
		end
	end
end

def munch(line, digest)
        id, text = line.split("\t", 2)

	return unless text

	seen_entries = {} if @brief
	offset = 0
	text.downcase! unless @case_sensitive
	words = text.scan(@sentence_chunks)
	return unless words
	word_or_compound = nil
	word_or_compound = text if @regexper
	while (max_arity = words.length) > 0
		arity = 1 if @regexper
		arity = @lookahead_min[words[0]] unless @regexper
		while arity and arity <= max_arity
			if @delimiter and arity < max_arity and not words[arity] == @delimiter then
				arity += 1
				next
			end

			unless @regexper then
				word_or_compound = words[0..arity - 1].join()
				word_arity = @lookahead[word_or_compound]
				break unless word_arity
				max_arity = word_arity if word_arity < max_arity
			end

			arity_dictionary = @dictionary[arity]
			if arity_dictionary then
				dictionary_entry = nil
				unless @regexper then
					dictionary_entry = arity_dictionary[word_or_compound]
					output_recognition(id, dictionary_entry, seen_entries, word_or_compound, offset, digest) if dictionary_entry
				else
					arity_dictionary.keys.each { |entity|
						regexp = @regexper_dictionary[entity]
						matches = word_or_compound.scan(regexp).map { |matches| matches[0] }
						matches.each { |match|
							next unless match
							output_recognition(id, arity_dictionary[entity], seen_entries, entity, offset, digest)
						}
					}
				end
			end

			arity = max_arity if @delimiter
			arity += 1
		end

		# If a delimiter is given, move forward to the next full-length word/compound:
		while @delimiter and words.length > 1 and not words[0] == @delimiter
			offset += words[0].length
			words.shift
		end

		offset += words[0].length
		unless @regexper then
			words.shift
		else
			words.clear
		end
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

