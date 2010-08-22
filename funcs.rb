#!/usr/bin/env ruby
#AutoKapi
#Copyright (C) 2010 Anton Pirogov
#Licensed under the GPL version 3 or later

#Contains helping functions invisible to the user
module HelpFuncs
  #get list of production facilities
  def list_production()
    #Go to town view -> main page
    $browser.link(:id,'href_stadt').click
    #create "new tab" with production facilities
    $browser.link(:id,'href_prod').click
    #get table with facilities
    table=$browser.table(:xpath,'/html/body/table/tbody/tr[2]/td/div/div[4]/table').to_a
    table.delete_if{|row| row[0].match(/:/) == nil }
    puts table.map{|row| row.join("\t")}.join("\n")
  end

  #get list of research facilities
  def list_research()
    #Go to town view -> main page
    $browser.link(:id,'href_stadt').click
    #create "new tab" with research facilities
    $browser.link(:id,'href_forsch').click
    #get table with facilities
    table=$browser.table(:xpath,'/html/body/table/tbody/tr[2]/td/div/div[4]/table').to_a
    table.delete_if{|row| row[0].match(/:/) == nil }
    puts table.map{|row| row.join("\t")}.join("\n")
  end

  #get list of warehouse items
  def list_warehouse()
    #Go to town view -> main page
    $browser.link(:id,'href_stadt').click
    #create "new tab" with warehose
    $browser.link(:id,'href_lager').click

    #get table cells and recreate table as text
    stuff = $browser.table(:id,'TABLE_MY_PRODUCTS_IN_STOCK').to_a.flatten

    table = ""
    stuff.shift(5)
    stuff.each_with_index{|cell,index|
      if (index+1)%5 != 0
        table += cell+"\t\t"
      else
        table += "\n"
      end
    }
    puts table
  end
end

#Contains functions which are the commands for the user
module Funcs
  include HelpFuncs

  #get info like bar/capital/level etc
  def info(commands)
    infos=$browser.table(:xpath,'/html/body/table/tbody/tr/td/table/tbody/tr/td[2]/table')
    infos.to_a.flatten.each_with_index{|t,i| puts t.chomp.strip if i!=1}
  end

  #list production/research/warehouse
  def list(commands)
    what = commands[0].to_s

    if (what != 'production' && what != 'research' && what != 'warehouse')
      puts "Usage: list production/research/warehouse"
      return
    end

    list_production if what=='production'
    list_research if what=='research'
    list_warehouse if what=='warehouse'
  end

  #set production for a building:
  #prod Kongo:39247345 abort
  #prod Kongo:39247345 Holz amount/time 34568345/12:34
  def prod(commands)
    #get arguments
    facilityid = commands[0].to_s
    product = commands[1].to_s
    way = commands[2].to_s
    number = commands[3].to_s

    if facilityid=="" || product =="" || product != "abort" && (way =="" || number=="" || (way != 'amount' && way != 'time'))
      puts "usage: prod <factoryid> <product> <time>/<amount> HH[:MM]/<number>\n or: prod <factoryid> abort"
      return false
    end

    #Go to town view -> main page
    $browser.link(:id,'href_stadt').click
    #go to production
    $browser.link(:id,'href_prod').click

    #get row text and index of accodring building id
    rowtext=nil
    index=0
    $browser.table(:xpath,'/html/body/table/tbody/tr[2]/td/div/div[4]/table').rows.to_a.each_with_index{|factory,i|
      if factory.text.match(/.*#{facilityid}.*/)
        rowtext = $browser.table(:xpath,'/html/body/table/tbody/tr[2]/td/div/div[4]/table').rows[i].text
        index = i
        break
      end
    }

    #abort
    if product == 'abort'
      if rowtext.match(/.*bereit.*/)
        puts 'Nothing to abort!'
      else
        $browser.table(:xpath,'/html/body/table/tbody/tr[2]/td/div/div[4]/table').rows[index].links[0].click
        $browser.link(:id,'A_PRODUKTION_ABBRECHEN').click

        puts "Production in #{facilityid} aborted!"
      end

    #produce something
    else
      if rowtext.match(/.*bereit.*/)==nil
        puts "Abort current production first!"
      else
        $browser.table(:xpath,'/html/body/table/tbody/tr[2]/td/div/div[4]/table').rows[index].links[0].click
        proditems = $browser.table(:xpath,'/html/body/table/tbody/tr[2]/td/div/table').rows[0]

        #create product name -> link index hash and index -> intern index array
        indexhash = Hash.new
        itoreali = Array.new
        proditems.cells.each_with_index{|c,i|
          indexhash[c.links[0].images[0].src.split('/')[-1].split('.')[0].downcase.to_sym] = i
        }
        proditems.cells.each_with_index{|c,i|
          itoreali.push c.links[0].html.split(' ')[3].split(')')[0].to_i
        }

        if indexhash[product.downcase.to_sym] == nil
          puts "You can't produce #{product} here!" #invalid prod for facility
        else
          proditems.cells[indexhash[product.downcase.to_sym]].links[0].click
          form = $browser.table(:id,'TABLE_PRODUKT_PRODUZIEREN_MYPRODUCTTABLE').row(:id,'TABLE_PRODUKT_PRODUZIEREN_MYPRODUCTTABLE_TRID_'+itoreali[indexhash[product.downcase.to_sym]].to_s)

          #calculate absolute amount from time
          if way=='time'
            perhour = $browser.cell(:xpath,"//span[@id='SPAN_PRODUKT_PRODUZIEREN_PLATZHALTER']/table/tbody/tr/td/table/tbody/tr[2]/td").text.split("\n")[-1].split(' ')[-3].to_f
            puts perhour
            number = (perhour*number.split(':')[0].to_i + perhour/60*number.split(':')[1].to_i).round
          end

          #set amount
          form.cells[0].text_fields[0].value = number
          #click button
          $browser.button(:value, ' jetzt produzieren ').click

          puts "Production of #{number} #{product} in #{facilityid} started!"
        end
      end
    end
  end

  def group(commands)
    if commands[0]==nil
      puts "Usage: group create/delete <name> <type>\nor: group <name> abort\nor: group <name> add/remove <id>\nor: group <name> prod <product> amount/time number/HH:MM"
      return
    end

    cmd = commands[0]

    if cmd=='create'
      if commands[1]==nil
        puts "Usage: group create <name> <type>"
        return
      end
      grp = Group.new
      grp.name = commands[1]
      grp.type = commands[2]
      if $groups[grp.name.to_sym]==nil
        $groups[grp.name.to_sym] = grp
        puts "Group #{commands[1]} of type #{commands[2]} created!"
      else
        puts "Group #{commands[1]} already exists!"
      end
    elsif cmd=='delete'
      if commands[1]==nil
        puts "Usage: group delete <name>"
        return
      end
      $groups.delete(commands[1].to_sym)
      puts "Group #{commands[1]} deleted!"
    elsif cmd=='list'
      $groups.keys.each{|key| puts key }
    else
      if commands[2]==nil && commands[1]!='list' && commands[1]!='abort'
          help([])
          return
      end
      name = cmd
      cmd = commands[1]
      if cmd=='add' #todo: add type check
        2.upto(commands.length-1) do |i|
          $groups[name.to_sym].add(commands[i])
          puts "#{commands[i]} added to #{name}!"
        end
      elsif cmd=='remove'
        2.upto(commands.length-1) do |i|
          $groups[name.to_sym].remove(commands[i])
          puts "#{commands[i]} removed from #{name}!"
        end
      elsif cmd=='list'
        if $groups[name.to_sym]!=nil
          $groups[name.to_sym].ids.each{|id| puts id}
        else
          puts "Group does not exist!"
        end
      elsif cmd=='abort'
        if $groups[name.to_sym]!=nil
          $groups[name.to_sym].ids.each{|id|
            puts "Aborting #{id}..."
            prod([id,'abort'])
          }
        else
          puts "Group does not exist!"
        end
      elsif cmd=='prod'
        if $groups[name.to_sym]!=nil
          $groups[name.to_sym].ids.each{|id|
           puts "Starting production in #{id}..."
           prod([id,commands[2],commands[3],commands[4]])
          }
        else
          puts "Group does not exist!"
        end
      end
    end
  end

  def help(commands)
    help=""
    help += "help\ninfo\n"
    help += "list production|research|warehouse\n"
    help += "group list\n"
    help += "group create <name> <type>\n"
    help += "group delete <name>"
    help += "group <name> add|remove <id> [<id>, <id>, ...]\n"
    help += "group <name> list\n"
    help += "group <name> abort\n"
    help += "group <name> prod <product> amount|time number|HH:MM\n"
    help += "prod <id> abort\nprod <id> <product> amount|time number|HH:MM\n"
    puts help
  end
end
