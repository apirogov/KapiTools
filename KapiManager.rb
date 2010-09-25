#!/usr/bin/env ruby
#KapiManager - Kapiland CLI management tool
#Copyright (C) 2010 Anton Pirogov
#Licensed under the GPL version 3 or later

require 'readline'        #for better prompt
require_relative 'login'  #mechanize and login stuff
require_relative 'funcs'  #functions for autokapi
include Funcs

#Login
init_and_login()

#create fab cache (needed for group type checking and for faster access)
Funcs.create_cache([])

#helper func for completion - filter out and prepare
def filter(array,input)
  array.select{|x| x.match(Regexp.new("^"+input[-1]+".*"))!=nil}.map{|x| (input[0...-1].join(' ')+' '+x).strip}
end
#routine for completion
complete = lambda { |input|
  addempty = false    #adds empty "token" for a new unfinished command...
  addempty = true if input[-1]==' '
  input = input.strip.split(' ')
  input << '' if addempty

  #special exit shortcut
  if input[0] == 'q'
    return ['logout']
  end

  comp = []   #completion items array

  #complete context sensitively...

  if input[0] == 'group'
    if input.length == 2
      comp = filter($groups.keys.map{|x| x.to_s}+['list','create','delete'], input)
    elsif input.length == 3
      if ['list','create','delete'].index(input[1]) == nil
        comp = filter(['prod', 'abort','add','remove'], input)
      end
    elsif input.length == 5 && input[2] == 'prod'
      comp = filter(['until','time','amount'], input)
    elsif input.length == 6 && input[4] == 'until'
      require 'date'
      dat = Date.today
      dates = []
      8.times do
        dates << dat.to_s
        dat = dat.next
      end
      comp = filter(dates, input)
    end

  elsif input[0] == 'list'
    comp = filter(['production','research','warehouse'], input)

  else  #complete a method
    meths = (Funcs.public_instance_methods-HelpFuncs.public_instance_methods).map{|x| x.to_s}
    comp = filter(meths+['amount','until','time'], input)
  end

  return comp
}

Readline.completer_word_break_characters = "" #make completion line wide... for context sensitivity
Readline.completion_proc = complete     #add simple completion

#main loop - dynamically call methods depending on issued commands
while true
  line = Readline.readline('>> ').chomp

  #check for exit commands
  break if line.match(/(logout)|(exit)/) != nil

  command = line.split(' ')

  next if command.length < 1  #nothing written -> next looping

  #execute corresponding method with given arguments
  if Funcs.method_defined?(command[0].to_sym)
    method(command[0].to_sym).call(command.slice(1,command.length-1))

    #add to history if not duplicate or empty
    Readline::HISTORY.push(line) unless line.strip == "" || Readline::HISTORY.to_a.index(line) != nil
  else
    puts 'Command not found: '+command[0]
  end
end

logout()

