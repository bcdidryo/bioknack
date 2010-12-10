#!/usr/bin/ruby

require 'rubygems'
require 'optparse'
require 'dbi'

def print_help()
        puts 'Usage: bk_mesh_mysql_import.rb [-h host] [-P port] [-u username] [-p password] binfile database'
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

file = ARGV[0]
db_name = ARGV[1]

def update_record(key, value, keys, bag)
	if keys.include?(key) then
		# Key present. Create duplicates and update value for the new entries.
		new_records = []
		bag.each { |record|
			new_record = record.dup
			new_record[key] = value
			new_records |= [ new_record ]
		}
		bag |= new_records
	else    
		# Key absent. Add value to all entries only.
		if bag.length == 0 then
			bag |= [ { key => value } ]
		else
			bag.each { |record|
				record[key] = value
			}
		end
		keys << key
	end

	return [keys, bag]
end

db_mesh = DBI.connect("DBI:Mysql:database=#{db_name};host=#{db_host};port=#{db_port}", db_user, db_password)

input = `cat #{file}`

backfile_keys = []
other_keys = []

input.each { |line|
	line.chomp!

	if line =~ /^\w*\s?\w+\s=\s/ then
		entry = line.match(/^(\w*\s?\w+)\s=\s(.*)$/)
		key = entry[1].sub(/\s/, '_')

		if key == 'ENTRY' then
			# They get their own table.
			next
		end

		if key =~ /MED|M\d+/ and not backfile_keys.include?(key) then
			backfile_keys << key
		elsif not key =~ /MED|M\d+/ and not other_keys.include?(key) then
			other_keys << key
		end
	end
}

# Create tables:
db_mesh.do('DROP TABLE IF EXISTS descriptor')
db_mesh.do('DROP TABLE IF EXISTS descriptor_entry')
db_mesh.do('DROP TABLE IF EXISTS descriptor_backfile_posting')

db_mesh.do('CREATE TABLE descriptor (' <<
		'ENTRY_KEY INT UNSIGNED,' <<
		other_keys.map { |x| x + ' VARCHAR(1000)' }.join(',') <<
		')'
)
db_mesh.do('CREATE TABLE descriptor_entry (ENTRY_KEY INT UNSIGNED, ENTRY VARCHAR(2000))')
db_mesh.do('CREATE TABLE descriptor_backfile_posting (' <<
		'ENTRY_KEY INT UNSIGNED,' <<
		backfile_keys.map { |x| x + ' VARCHAR(1000)' }.join(',') <<
		')'
)

# For each entry in the BIN file, we create an entry in the bag and
# add another entry when we see a duplicate key.
descriptor_bag = []
backfile_bag = []
entry_list = []

descriptor_keys = []
backfile_keys = []

entry_key = 0
input.each { |line|
	line.chomp!

	if line == '*NEWRECORD' then
		descriptor_bag = []
		backfile_bag = []
		entry_list = []

		descriptor_keys = []
		backfile_keys = []
	elsif line == '' then
		# End of a record. Insert record's data into the database.

		entry_list.each { |value|
			db_mesh.do('INSERT INTO descriptor_entry (' <<
					'ENTRY_KEY, ENTRY' <<
					') VALUES (' <<
					'?, ?' <<
					')',
					entry_key, value)
		}

		descriptor_bag.each { |record|
			keys = []
			values = []
			record.keys.each { |key|
				keys << key
				values << record[key]
			}
			db_mesh.do('INSERT INTO descriptor (' <<
					'ENTRY_KEY,' <<
					keys.join(',') <<
					') VALUES (' <<
					'?,' <<
					values.map{ '?' }.join(',') <<
					')',
					entry_key, *values)
		}

                backfile_bag.each { |record|
			keys = []
			values = []
                        record.keys.each { |key|
				keys << key
				values << record[key]
                        }
                        db_mesh.do('INSERT INTO descriptor_backfile_posting (' <<
                                        'ENTRY_KEY,' <<
                                        keys.join(',') <<
                                        ') VALUES (' <<
                                        '?,' <<
                                        values.map{ '?' }.join(',') <<
                                        ')',
                                        entry_key, *values)
                }

		entry_key += 1
	elsif line =~ /^\w*\s?\w+\s=\s/ then
		entry = line.match(/^(\w*\s?\w+)\s=\s(.*)$/)
		key = entry[1].sub(/\s/, '_')
		value = entry[2]

		if key == 'ENTRY' then
			entry_list << value
			next
		end

		if key =~ /MED|M\d+/ then
			# "Backfile postings"
			backfile_keys, backfile_bag = update_record(key, value, backfile_keys, backfile_bag)
			next
		end

		# Everything else goes into the main tables.
		descriptor_keys, descriptor_bag = update_record(key, value, descriptor_keys, descriptor_bag)
	else
		puts 'Woops...'
		puts 'Do not get line: ' << line
		exit
	end

}

db_mesh.disconnect

