#!/usr/bin/env ruby
#AutoKapi
#Copyright (C) 2010 Anton Pirogov
#Licensed under the GPL version 3 or later

#TODO: marketsell function -> make it work (post thingy doesnt work -.-)
#TODO: update Tutorial with marketsell
#TODO: maybe then something with ressource calculation?

#Contains helping functions invisible to the user
module HelpFuncs
  PRODTAB_XPATH = '/html/body/table/tr[2]/td/div/div[4]/table'    #used quite often

  #add spaces to achieve wished size of string
  def strpad(str,num)
    str+=' '*(num-str.length)
    return str
  end

  #Get the text of a row with spaces in between the td's
  def tr_text(row)
      str = ''
      row.element_children.each{|td| str += td.text.strip + ' '}
      return str
  end

  #because normal strip doesnt work anymore oO
  def my_strip(str)
    str.gsub(/\W+$/,'').gsub(/^\W+/,'')
  end

  #create facility_id => {link, type} hash
  def create_cache(commands)
    $facilitycache = Hash.new   #init empty cache
    site = $agent.click($city.link_with(:href=>/page=gebs/))  #open page
    rows=site.search(PRODTAB_XPATH+'/tr') #get table rows

    #filter out the facility id's and the links
    rows.each{|row|
      rowtext = tr_text(row)  #get text string from row
      fac = rowtext.split(' ')[0]   #get facilityId of row

      if fac.split(':').length == 2  #a real facility row?
          link = row.element_children[-1].first_element_child['href'] #get the fac. url
          #no error getting link -> add url to hash
          if link != nil
            #create a real url
            link = 'http://s6.kapilands.eu/'+link
            #get type
            type = rowtext.split(' ')[1].downcase
            $facilitycache[fac.downcase] = {:link => link, :type => type}
          end
      end
    }
    #output:
    $facilitycache.each{|key,val| puts key + "=>"+val } if $DEBUG
    puts "Temporary factory cache created!" if $DEBUG
  end

  #get list of production or research facilities
  def list_prod_or_res(type)
    #create "new tab" with production/research facilities
    if type == 'prod'
      site = $agent.click($city.link_with(:href=>/page=gebs/))
    elsif type == 'res'
      site = $agent.click($city.link_with(:href=>/page=forschs/))
    else
      return false
    end

    #get table with facilities -> extract and parse rows
    rows=site.search(PRODTAB_XPATH+'/tr')

    #create readable text lines for each row
    textrows = []
    rows.each{|row| textrows << tr_text(row) }

    #filter junk out and output
    textrows.delete_if{|row| row.split(' ')[0].match(/:/) == nil }
    puts textrows
  end

  #get list of warehouse items with infos (used for list and marketsell)
  def parse_warehouse()
    #create "new tab" with warehouse
    warehouse = $agent.click($city.link_with(:href=>/page=lager/))

    #get table cells and recreate table as text
    tablerows = warehouse.search('//*[@id="TABLE_MY_PRODUCTS_IN_STOCK"]/tr')

    rowstrings=[]
    tablerows.each{|x|
      if x.to_s.match(/>\d+/)!=nil
        str=''
        x.element_children.each_with_index{|y,i|
          td = y.text
          td.gsub!('.','') if i == 0  #remove dots from amount numbers
          str += strpad(td,20)
        }
        rowstrings << str.strip
      end
    }

    return rowstrings
  end
end

#Contains functions which are the commands for the user
module Funcs
  include HelpFuncs

  #get info like bar/capital/level etc
  def info(commands)
    #extract info rows
    infos = $city.search('/html/body/table/tr/td/table/tr/td[2]/table/tr')
    lines=[]
    infos.each{|y| lines << y.text.strip}

    #remove junk and output
    lines[0] = lines[0][0..lines[0].index("\n")]
    lines[3] = lines[3][0..lines[3].index("\n")]
    lines[-1] = lines[-1][0...lines[-1].index("(")]
    lines.map!{|l| my_strip(l) }
    puts lines
  end

  #list production/research/warehouse
  def list(commands)
    what = commands[0].to_s

    if (what != 'production' && what != 'research' && what != 'warehouse')
      puts "Usage: list production|research|warehouse"
      return
    end

    list_prod_or_res('prod') if what=='production'
    list_prod_or_res('res') if what=='research'
    puts parse_warehouse if what=='warehouse'
  end



  #set production for a building:
  #prod Kongo:39247345 abort
  #prod Kongo:39247345 Holz amount/time 34568345/12:34
  def prod(commands)
    #get arguments
    facilityid = commands[0].to_s.downcase
    product = commands[1].to_s
    way = commands[2].to_s
    number = commands[3].to_s

    if facilityid=="" || product =="" || product != "abort" && (way =="" || number=="" || (way != 'amount' && way != 'time'))
      puts "Usage: prod <factoryid> <product> <time>|<amount> HH[:MM]|<number>\n\tor: prod <factoryid> abort"
      return false
    end


    link = nil    #url of the facility
    #if no facilitycache built or facility id not in there -> go to page and get it
    if $facilitycache == nil || $facilitycache[facilityid] == nil
      site = $agent.click($city.link_with(:href=>/page=gebs/))  #open page
      rows=site.search(PRODTAB_XPATH+'/tr') #get table rows

      rowtext=nil
      rows.each{|row|                #get rowtext of accodring building id
        rowtext = tr_text(row)        #get text string from row
        fac = rowtext.split(' ')[0]   #get facilityId of row
        if fac.downcase == facilityid         #the one we look for?
          link = row.element_children[-1].first_element_child['href'] #get the fac. url
          if link != nil             #no error getting link -> add url to hash
            link = 'http://s6.kapilands.eu/'+link         #create a real url
          end
          break                       #get out to not get overwritten
        end
       }
    else  #must be cached -> get from cache
      link = $facilitycache[facilityid][:link]
    end

    #still no link? facility doesnt exist!
    if link==nil
      puts facilityid+' does not exist!'
      return false
    end

    #abort production? try...
    if product == 'abort'
      #not cached link -> do check
      if rowtext != nil && rowtext.match(/bereit/)
        puts 'Nothing to abort!'
        return false
      end

      #open page
      prodsite = $agent.get(link)

      #look for abort link.. and check that there's really something to do
      cancel = prodsite.link_with(:text=>/abbrechen/)
      control = prodsite.search('//*[@id="SPAN_PRODUKTION_PRODUZIERT_FERTIGIN"]').text.match(/Fertig in/)

      if cancel != nil && control != nil  #link found -> abort
        $agent.click(cancel)
        puts "Production in #{facilityid} aborted!"
        return true
      else              #link not found
        puts 'Nothing to abort!'
        return false
      end
    end

    #check that is ready to use
    if rowtext != nil && rowtext.match(/bereit/)==nil
        puts 'Abort current production first!'
        return false
    end

    #load facility page
    prodsite = $agent.get(link)

    #check that really nothing is running here that must be canceled
    cancel = prodsite.link_with(:text=>/abbrechen/)
    control = prodsite.search('//*[@id="SPAN_PRODUKTION_PRODUZIERT_FERTIGIN"]').text.match(/Fertig in/)
    if cancel!=nil && control != nil  #OMG its producing!
       puts 'Abort current production first!'
       return false
    end

    #create product name -> link index hash and index -> intern index array
    proditems = prodsite.search('/html/body/table/tr[2]/td/div/table/tr/td')
    prodinfos = prodsite.search('/html/body/table/tr[2]/td/div/table/tr/script')
    indexhash = Hash.new
    itoreali = Array.new
    i=0
    proditems.each {|elem|
      indexhash[elem.first_element_child.first_element_child['src'].split('/')[-1].split('.')[0].downcase.to_sym] = i
      i+=1
    }
    proditems.each {|elem|
      itoreali.push elem.first_element_child['onclick'].split(' ')[-1].split(')')[0].to_i
    }

    index = indexhash[product.downcase.to_sym]    #save index of chosen product

    if index == nil
      puts "You can't produce #{product} here!" #invalid prod for facility -> fail
      return false
    end

    # -- start production --

    #get form element for textfields + button
    form = prodsite.forms[1]
    #calculate absolute amount from time
    if way=='time'
      #get the stuff out from the script segment (mechanize cant eval js -.-)
      datastring = prodinfos[index].inner_text.split('</div>')[1]
      perhour = datastring.split('pro Std.')[0].split(' ')[-1].to_f
      #calculate amount using number per hour
      number = (perhour*number.split(':')[0].to_i + perhour/60*number.split(':')[1].to_i).round.to_s
    end

    #set amount in the right textbox
    form.fields[index].value = number
    #click button
    started = form.submit

    #check whether the starting was successful
    if started.body.match('zu produzieren brauchst du') != nil
      puts 'Not enough ressources!'
      return false
    end

    puts "Production of #{number} #{product} in #{facilityid} started!"
    return true
  end

  def group(commands)
    if commands[0]==nil
      puts "Usage: group create|delete <name> <type>\nor: group <name> abort\nor: group <name> add|remove <id>\nor: group <name> prod <product> amount|time number|HH:MM"
      return false
    end

    #get subcommand
    cmd = commands[0]

    #create a new group
    if cmd=='create'
      if commands[1]==nil || commands[2]==nil
        puts "Usage: group create <name> <type>"
        return false
      end

      grp = Group.new
      grp.name = commands[1].downcase
      grp.type = commands[2].downcase

      if $groups[grp.name.to_sym]==nil
        $groups[grp.name.to_sym] = grp
        puts "Group #{commands[1]} of type #{commands[2]} created!"
      else
        puts "Group #{commands[1]} already exists!"
      end

    #delete existing group
    elsif cmd=='delete'
      if commands[1]==nil
        puts "Usage: group delete <name>"
        return false
      end

      $groups.delete(commands[1].to_sym)
      puts "Group #{commands[1]} deleted!"

    #list the groups which currently exist
    elsif cmd=='list'
      $groups.keys.each{|key| puts key.to_s+" (#{$groups[key].type})" }

    else
      #its not list and not abort and has no extra options? show usage info
      if commands[2]==nil && commands[1]!='list' && commands[1]!='abort'
          help([])
          return false
      end

      #get further subcommands
      name = cmd
      cmd = commands[1]

      #check that the group exists
      if $groups[name.to_sym]==nil
        puts 'Group does not exist!'
        return false
      end

      #add a facility to a group (double entries automatically removed) - can process a list of ids
      if cmd=='add' #todo: add type check
        2.upto(commands.length-1) do |i|
          if $facilitycache[commands[i].downcase] != nil #facility does really exist
            if $facilitycache[commands[i].downcase][:type].downcase == $groups[name.to_sym].type.downcase  #type matching?
              $groups[name.to_sym].add(commands[i].downcase)
              puts "#{commands[i]} added to #{name}!"
            else
              puts "#{$facilitycache[commands[i].downcase][:type]+' '+commands[i]} can not be added to the #{$groups[name.to_sym].type} group #{name}!"
            end
          else
            puts "#{commands[i]} does not exist!"
          end
        end

      #remove a facility from a group - can process a list of ids
      elsif cmd=='remove'
        2.upto(commands.length-1) do |i|
          if $groups[name.to_sym].ids.index(commands[i].downcase) != nil #its in the group
            $groups[name.to_sym].remove(commands[i].downcase)
            puts "#{commands[i].downcase} removed from #{name}!"
          else  #not in group
            puts "#{commands[i].downcase} is not in #{name}!"
          end
        end

      #list the facilities of a group
      elsif cmd=='list'
        $groups[name.to_sym].ids.each{|id| puts id}

      #abort the production of a whole group
      elsif cmd=='abort'
        $groups[name.to_sym].ids.each{|id|
          puts "Aborting #{id}..."
          prod([id,'abort'])
        }

      #start a production task in all facilites of group
      elsif cmd=='prod'
        $groups[name.to_sym].ids.each{|id|
          puts "Starting production in #{id}..."
          prod([id,commands[2],commands[3],commands[4]])
        }
      end

    end
  end

  #sell amount of product at specified price at market
  def marketsell(commands)
    #check arguments
    if commands.length < 3
      puts "usage: marketsell <product> <quality> <amount>|all <price>\n"
      return false
    end

    product = commands[0].to_s.downcase
    quality = commands[1].to_s
    amount = commands[2].to_s
    price = commands[3].to_s.gsub(',','.')    #convert european floating point , -> .

    #get user money amount to calculate whether there is enough to pay 10% fee
    money = $city.search('/html/body/table/tr/td/table/tr/td[2]/table/tr')[1].text
    money = my_strip(money).gsub(/^\w+: /,'').gsub('.','').gsub(',','.').to_f

    #create "new tab" with warehouse
    warehouse = $agent.click($city.link_with(:href=>/page=lager/))
    #get table with data about warehouse to see whats there and how much...
    iteminfo = parse_warehouse()
    #convert to hash
    iteminfo.map!{|row|
      items = row.split(' ').map{|item| my_strip(item)}
      {:amount=>items[0], :product=>items[1].downcase, :quality=>items[2], :averageprice=>items[3]}
    }

    #check whether specified item in specified quality is present in warehouse and get index
    index = nil
    itemfound = false
    iteminfo.each_with_index{|row,i|
      if row[:product]==product && row[:quality]==quality
        itemfound = true
        index=i
        break
      end
    }
    if !itemfound
      puts 'You do not posess '+product+' of quality '+quality+'!'
      return false
    end

    #specified all as amount?
    if amount == 'all'
      amount = iteminfo[index][:amount]
    end

    #check whether there's enough money to sell on market (10% fee)
    expectedfee = amount.to_f * price.to_f / 10.0 #calculate market fee
    if money < expectedfee
      puts "You have not enough money to pay 10% fee! You need: #{expectedfee.to_s}c"
      return false
    end

    puts "TODO"
    return false
    #TODO: fix! and fillout form... do checks... sell

    #manually forge post request
    link = warehouse.search('//form')[1]['action']
    postdata = []
    #get number of rows
    num =  warehouse.search('//input[@name="p_anz[]"]').length
    0.upto(num-1) do |i|
      #add the amount field for each row
      val = warehouse.search('//input[@name="p_anz[]"]')[i]['value']
      if i != index
        postdata.push ["p_anz%5B%5D", val]
      else
        postdata.push ["p_anz%5B%5D", amount]
      end
      #add the hidden fields
      postdata.push ["w_anz%5B%5D", warehouse.search('//input[@name="w_anz[]"]')[i]['value']]
      postdata.push ["q_anz%5B%5D]", warehouse.search('//input[@name="q_anz[]"]')[i]['value']]
    end
    #add rest of data
    postdata.push ["wbet",price.gsub('.',',')]
    postdata.push ["vbet","0"]
    postdata.push ["fname",""]

    puts link
    p postdata

    page = $agent.post('http://s6.kapilands.eu/'+link, postdata,{'Content-Type'=>'application/x-www-form-urlencoded'})
    puts page.body
  end

  #outputs help for all commands with syntax
  def help(commands)
    help=""
    help += "help\ninfo\n"
    help += "list production|research|warehouse\n"
    help += "group list\n"
    help += "group create <name> <type>\n"
    help += "group delete <name>\n"
    help += "group <name> add|remove <id> [<id>, <id>, ...]\n"
    help += "group <name> list\n"
    help += "group <name> abort\n"
    help += "group <name> prod <product> amount|time number|HH:MM\n"
    help += "prod <id> abort\nprod <id> <product> amount|time number|HH:MM\n"
    help += "marketsell <product> <quality> <amount>|all <price>\n"
    puts help
  end
end
