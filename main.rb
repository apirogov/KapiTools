# To change this template, choose Tools | Templates
# and open the template in the editor.

require "rubygems" if RUBY_VERSION < "1.9"
require "watir-webdriver"

require "config.rb"

require "funcs.rb"
include Funcs

$DEBUG = true

conf = Configuration.new
$groups = conf.groups #global alias

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

$browser = Watir::Browser.new(:firefox)
$browser.goto('http://s6.kapilands.eu')
$browser.link(:href,'index.php?newacc=4').click
$browser.text_field(:name, 'USR').value = nickname
$browser.text_field(:name, 'pass').value = password
$browser.button(:value, '    login    ').click

if $browser.text.include? 'Logout'
  puts "Login successful!"
  #Login data verified -> save
  conf.nickname = nickname
  conf.password = password
else
  puts 'Login failed! Maybe you misspelled your login data?'
  exit
end

#main loop
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
conf.save
$browser.links.each{|l|
  if l.text.match(/.*Logout.*/)
    l.click
    break
  end
}
$browser.close
