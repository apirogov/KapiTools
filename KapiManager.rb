#!/usr/bin/env ruby
#KapiManager - Kapiland CLI management tool
#Copyright (C) 2010 Anton Pirogov
#Licensed under the GPL version 3 or later

require 'readline'        #for better prompt
require 'date'            #for date completion
require_relative 'login'  #mechanize and login stuff
require_relative 'funcs'  #functions for autokapi
include Funcs

#Login
Login.init_and_login()

#create fab cache (needed for group type checking and for faster access)
Funcs.create_cache([])

#helper func for completion - filter out the possible candidates
def mk_comp_candidates(array,input)
  array.select{|x| x.match(Regexp.new("^"+input[-1]+".*"))!=nil}
end

#helper function - dates candidates
def gen_dates
      dat, dates = Date.today, []
      8.times do dates << dat.to_s; dat = dat.next end
      return dates
end

#routine for completion... marketsell & marketwatch context completion not implemented
complete = lambda { |input|
  addempty = false    #adds empty "token" for a new unfinished command...
  addempty = true if Readline.line_buffer[-1]==' '
  input = Readline.line_buffer.strip.downcase.split(' ')
  input = [''] if input == []   #to fix a nilClass error
  input << '' if addempty

  #special exit shortcut
  if input[0] == 'q'
    return ['logout']
  end

  comp = []   #completion items array

  #complete context sensitively...
  if input[0] == 'group'
    if input.length == 2
      comp = mk_comp_candidates($groups.keys.map{|x| x.to_s}+['list','create','delete'], input)
    elsif input.length == 3
      if ['list','create','delete'].index(input[1]) == nil
        comp = mk_comp_candidates(['prod', 'abort','add','remove','list'], input)
      elsif input[1] == 'delete'
        comp = mk_comp_candidates($groups.keys.map{|x| x.to_s}, input)
      end
    elsif input.length >= 4 && input[2] == 'remove'
      comp = mk_comp_candidates($groups[input[1].to_sym].ids - input[3..-2], input)
    elsif input.length >= 4 && input[2] == 'add'
      comp = mk_comp_candidates($facilitycache.keys.map{|x| x.to_s}-$groups[input[1].to_sym].ids - input[3..-2], input)
    elsif input.length == 4 && input[2] == 'prod'
      comp = mk_comp_candidates(HelpFuncs.get_valid_products($groups[input[1].to_sym].ids[0]).keys.map{|x| x.to_s}, input)
    elsif input.length == 5 && input[2] == 'prod'
      comp = mk_comp_candidates(['until','time','amount'], input)
    elsif input.length == 6 && input[4] == 'until'
      comp = mk_comp_candidates(gen_dates(), input)
    end

  elsif input[0] == 'list'
    if input.length == 2
      comp = mk_comp_candidates(['production','research','warehouse'], input)
    end

  elsif input[0] == 'prod'
    if input.length == 2
      comp = mk_comp_candidates($facilitycache.keys.map{|x| x.to_s}, input)
    elsif input.length == 3
      comp = mk_comp_candidates(HelpFuncs.get_valid_products(input[1]).keys.map{|x| x.to_s}, input)
    elsif input.length == 4
      comp = mk_comp_candidates(['until','time','amount'], input)
    elsif input.length == 5 && input[3] == 'until'
      comp = mk_comp_candidates(gen_dates(), input)
    end

  else  #complete a method
    meths = (Funcs.public_instance_methods-HelpFuncs.public_instance_methods).map{|x| x.to_s}
    comp = mk_comp_candidates(meths, input)
  end

  return comp
}

#catch ^C interrupt on unixoid systems
if RUBY_PLATFORM.match(/(win|w)32$/) == nil #not windows
  stty_save = `stty -g`.chomp
  trap('INT') { puts ""; Login.logout(); system('stty', stty_save); exit }
end

Readline.completion_proc = complete           #add simple completion

#main loop - dynamically call methods depending on issued commands
while true
  line = Readline.readline('>> ').chomp

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

