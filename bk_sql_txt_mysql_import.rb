#!/usr/bin/ruby

require 'rubygems'
require 'optparse'
require 'dbi'

def print_help()
        puts 'Usage: bk_sql_txt_mysql_import.rb [-h host] [-P port] [-u username] [-p password] directory database'
        puts '  -h | --host              : MySQL hostname (default: localhost)'
        puts '  -P | --port              : MySQL port (default: 3306)'
	puts '  -u | --user username     : MySQL username (default: mysql)'
	puts '  -p | --password password : MySQL password (default: mysql)'
	puts ''
	puts 'Note: The database must exist.'
end

db_host = 'localhost'
db_port = '3306'
db_user = 'mysql'
db_password = 'mysql'

options = OptionParser.new { |option|
        option.on('-h', '--host HOST') { |host| db_host = host }
	option.on('-P', '--port PORT') { |port| db_port = port }
	option.on('-u', '--user USER') { |user| db_user = user }
	option.on('-p', '--password PASSWORD') { |pass| db_password = pass }
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

directory = ARGV[0]
db_name = ARGV[1]

`for i in #{directory}/*.sql ; do mysql -h #{db_host} -P #{db_port} -u #{db_user} --password=#{db_password} #{db_name} < $i ; done`

`for i in #{directory}/*.txt ; do mysqlimport -L -h #{db_host} -P #{db_port} -u #{db_user} --password=#{db_password} #{db_name} $i ; done`

