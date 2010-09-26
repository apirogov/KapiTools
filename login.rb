#!/usr/bin/env/ruby
#Login functions (used by different KapiTools independently)
#Copyright (C) 2010 Anton Pirogov
#Licensed under the GPLv3 or later

require 'rubygems'  if RUBY_VERSION < "1.9"
require 'mechanize'
require_relative 'config'

module Login
#init mechanize, login and return city page (starting point for everything)
#defines global $conf, $agent, $groups and $city
def Login.init_and_login
  $conf = Configuration.new    #try to load a config... or create a blank one
  $groups = $conf.groups       #global alias (for group functions)

  #get nick and pass from config or if not existing, ask
  if $conf.nickname==nil
    print 'Nickname: '
    nickname=gets.chomp
  else
    nickname = $conf.nickname
  end
  if $conf.password==nil
    print 'Password: '
    password=gets.chomp
  else
    password = $conf.password
  end

  puts 'Logging in...'

  #Init mechanize
  $agent = Mechanize.new
  $agent.user_agent = 'Mechanize'
  $agent.user_agent_alias = 'Linux Mozilla'

  #fill out form, login
  start = $agent.get('http://s6.kapilands.eu')
  login_form = start.form_with(:action => 'serverwahl.php4')
  login_form['USR'] = nickname
  login_form['pass'] = password
  start = $agent.submit login_form

  #check login success
  if start.body.match('Logout')
    puts 'Login successful!'
    #Login data verified -> save
    $conf.nickname = nickname
    $conf.password = password
  else
    puts 'Login failed! Maybe you misspelled your login data?'
    exit
  end

  #return city page - starting point for all actions
  $city = $agent.click(start.link_with(:href => /stadtuebersicht/))
end

#properly logout from kapiland
def Login.logout
  #save config & logout
  puts "Logout..."
  $conf.save
  $agent.click($city.link_with(:text => /.*Logout.*/))
end

end
