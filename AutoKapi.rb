#!/usr/bin/env ruby
#AutoKapi - Kapiland Premium Features for free
#Copyright (C) 2010 Anton Pirogov
#Licensed under the GPL version 3 or later

require './login.rb'  #mechanize and login stuff
require './funcs.rb'  #functions for autokapi
include Funcs

#Login
init_and_login()

#create fab cache (needed for group type checking and for faster access)
Funcs.create_cache([])

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

logout()

