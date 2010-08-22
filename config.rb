# To change this template, choose Tools | Templates
# and open the template in the editor.
require 'base64'

class Configuration
  attr_accessor :nickname,:password,:groups

  def save
    f=File.open('autokapi.config','w')
    f.puts "nickname="+@nickname
    f.puts "password="+@password
    f.close
    File.open('autokapi.groups','w') do |f|
      Marshal.dump(@groups,f)
    end
  end


  def initialize
    puts 'Loading configuration files...' if $DEBUG

    if File.exists?('autokapi.config')
      f = File.open('autokapi.config','r')
      strings = f.readlines
      f.close

      #split each line to array [varname, value]
      #then assign each corresponding instance variable the according value
      strings.map!{|s| s=s.split('=') }
      strings.each{|record|
        self.instance_variable_set(('@'+record[0]).to_sym, record[1].chomp)
      }
    else
      puts 'No configuration file found!' if $DEBUG
    end
    if File.exists?('autokapi.groups')
      f = File.open('autokapi.groups','r') do |f|
        @groups = Marshal.load(f)
      end
    else
      puts 'No groups file found!'
      @groups = Hash.new
    end
  end
end

class Group
  attr_accessor :ids, :type, :name
  def initialize
    @ids = Array.new
  end

  def add(id)
    @ids.push id
    @ids.uniq!
  end

  def remove(id)
    @ids.delete(id)
  end
end
