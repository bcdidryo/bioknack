#!/usr/bin/ruby

require 'rubygems'
require 'optparse'
require 'sparql/client'

@host = 'central.biomart.org'
@port = 80

def print_help
	puts 'Usage: bk_sparql.rb [options] accesspointname'
	puts ''
	puts 'Reads a SPARQL query from STDIN, then sends it to the given'
	puts 'BioMart\'s access point, and outputs the results as TSVs.'
	puts ''
	puts 'Options:'
	puts "  -h HOSTNAME / --host HOSTNAME : BioMart server (default: #{@host})"
	puts "  -p PORT / --port PORT         : port to use (default: #{@port})"
	puts ''
	puts 'Note: You might need to run `sudo gem install sparql-client`.'
end

options = OptionParser.new { |option|
	option.on('-h', '--host HOSTNAME') { |hostname| @host = hostname }
	option.on('-p', '--port PORT') { |portnumber| @port = portnumber.to_i }
}

begin
	options.parse!
rescue OptionParser::InvalidOption
	print_help
	exit
end

if ARGV.length != 1 then
	print_help
	exit
end

accesspoint = ARGV[0]

server = "#{@host}"
server << ":#{@port}" unless @port == 80

def query(server, accesspoint, query)
	sparql = SPARQL::Client.new("http://#{server}/martsemantics/#{accesspoint}/SPARQLXML/get/")

	query = sparql.query(query)

	return query
end

query = ''
STDIN.each { |line| query << line }
result = nil
begin
	result = query(server, accesspoint, query)
rescue => e
	puts 'Wooops.. an exception occurred.'
	puts "Exception: #{e.to_s}"
	exit
end

variables = nil
result.each { |solution|
	unless variables then
		variables = []
		solution.each_name { |name| variables << name.to_s }
		variables.sort!
		puts "##{variables.join("\t")}"
	end
	row = ''
	variables.each { |name|
		row << solution[name].to_s
		
		row << "\t" unless name == variables.last
	}

	puts row
}

