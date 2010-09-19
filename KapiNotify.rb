#!/usr/bin/env ruby
#KapiNotify - show message box when something changes in kapiland (production/research ready)
#Copyright (C) 2010 Anton Pirogov
#Licensed under the GPLv3 or later

require 'tk'  #for message box
require_relative 'login'
require_relative 'funcs'
include HelpFuncs

#show a message box with given text
def notify(str)
  Tk.messageBox('title'=>'KapiNotify', 'message'=>str)
end


#ensure only ONE instance of KapiNotify is running
tmp_file = File.expand_path(File.dirname(__FILE__)) +  "/KapiNotify.lock"
if File.exists?(tmp_file)
  puts "Already running (lock file)! Shutting down..."
  notify("KapiNotify is already running!\n\nIf you are sure that it is not, delete #{tmp_file}")
  exit
else
  f=File.open(tmp_file,'w')
  f.puts "This is a lock file, ensuring KapiNotify is started only once."
  f.close
end

#script gets killed -> shutdown, remove lock
trap("INT") {
  puts "KapiNotify shutting down..."
  logout()  #clean logout from kapiland (just to make sure)
  File.delete(tmp_file) #remove lock file
  exit
}

init_and_login()  #init mechanize, login to kapiland

puts "KapiNotify started!"

##### FUNCTIONS FOR KAPINOTIFY #####

#get initial info - type, id, task and current activity state
#(activity: bereit=false, everything else=true)
def get_infos
  array = list_prod_or_res('prod')+list_prod_or_res('res')
  array.map! {|item|
    item = item.split(' ')
    new = Hash.new
    new[:type] = item[1]
    new[:id] = item[0]
    new[:task] = item[4...-1].join(' ')

    if item[-1]=='bereit'
      new[:state] = false
    else
      new[:state] = true
    end

    new
  }
end

#get array telling where something changed
def compare_state(a, b)
  c = Array.new
  0.upto(a.length-1) do |i|
    c << (a[i][:state] == b[i][:state])
  end
  return c
end

##################

#get list of types, ids and tasks to inform user what finished doing what
#and also save activity state (true/false)
state = get_infos()
while true                #endless loop checking for updates
  newstate = get_infos()  #get current list with data

  msg = ''  #empty message for now...

  #check the changes and create a notification
  comparedata = compare_state(state, newstate)
  comparedata.each_with_index{|item, i|
    if !item && newstate[i][:state]==false  #something has finished!
      msg += "#{state[i][:type]} #{state[i][:id]} finished! (#{state[i][:task]})\n"
    end
  }
  notify(msg) if msg != ''  #we have changes -> show the message

  sleep 60          #checking every minute
  state = newstate  #replace old with new, start over
end

