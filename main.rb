#!/usr/bin/env ruby
#AutoKapi - Kapiland Premium Features for free
#Copyright (C) 2010 Anton Pirogov
#Licensed under the GPL version 3 or later

require "rubygems" if RUBY_VERSION < "1.9"
require "mechanize"

require "config.rb"
require "funcs.rb"
include Funcs


conf = Configuration.new    #try to load a config... or create a blank one
$groups = conf.groups       #global alias (for group functions)

#get nick and pass from config or if not existing, ask
if conf.nickname==nil
  print "Nickname:"
  nickname=gets.chomp
else
  nickname = conf.nickname
end
if conf.password==nil
  print "Password:"
  password=gets.chomp
else
  password = conf.password
end

puts "Logging in..."

#Init mechanize
$agent = Mechanize.new
$agent.user_agent = "Mechanize"
$agent.user_agent_alias = "Linux Mozilla"

#fill out form, login
start = $agent.get('http://s6.kapilands.eu')
login_form = start.form_with(:action => 'serverwahl.php4')
login_form['USR'] = nickname
login_form['pass'] = password
start = $agent.submit login_form

#check login success
if start.body.match('Logout')
  puts "Login successful!"
  #Login data verified -> save
  conf.nickname = nickname
  conf.password = password
else
  puts 'Login failed! Maybe you misspelled your login data?'
  exit
end
exit

#main loop - dynamically call methods depending on issued commands
command = ""
while true
  print ">> "
  command = gets.chomp
  break if command=='logout'

  command = command.split(' ')
  if Funcs.method_defined?(command[0].to_sym)
    method(command[0].to_sym).call(command.slice(1,command.length-1))
  else
    puts 'Command not found: '+command[0]
  end
end

#save config & logout
puts "Logout..."
conf.save
$agent.click(start.link_with(:text => /.*Logout.*/))
