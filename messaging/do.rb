require_relative '../config/boot'
require 'nats/client'

cursor = Mongoid::Sessions.default["90fd58e343c29e54fc1d4e19036595500b2bdc21_logs"].find.tailable.cursor
cursor.each do |doc|
	puts doc['line']
end