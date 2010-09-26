#!/usr/bin/env ruby
#KapiManager functions
#Copyright (C) 2010 Anton Pirogov
#Licensed under the GPL version 3 or later

#Contains helping functions invisible to the user
module HelpFuncs
  PRODTAB_XPATH = '/html/body/table/tr[2]/td/div/div[4]/table'    #used quite often

  #add spaces to achieve wished size of string
  def strpad(str,num)
    return str if (num-str.length)<0  #negative padding

    str+=' '*(num-str.length)
    return str
  end

  #Get the text of a row with spaces in between the td's
  def tr_text(row,separator=' ')
    str = ''
    row.element_children.each{|td| str += td.text.strip + separator}
    return str
  end

  #because normal strip doesnt work anymore oO
  def my_strip(str)
    return str.gsub(/\W+$/,'').gsub(/^\W+/,'')
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
    return true
  end

  #input - mechanize site object, output - hash {product-name => its index}
  def get_valid_products(fac)
    #facility id given? load page... (mainly for usage in completion routine)
    fac = $agent.get($facilitycache[fac.downcase][:link]) if fac.class.to_s == "String"

    proditems = fac.search('/html/body/table/tr[2]/td/div/table/tr/td')
    indexhash = Hash.new
    i=0
    proditems.each {|elem|
      indexhash[elem.first_element_child.first_element_child['src'].split('/')[-1].split('.')[0].downcase.to_sym] = i
      i+=1
    }
    return indexhash
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

    #prettify
    textrows.map!{|row|
      txt = row.split(' ')
      text = strpad(txt[0],20)+strpad(txt[1][0...13],14)+strpad(txt[2],6)
      text += strpad(txt[3],8)+strpad(txt[4...-1].join(' ')[0...21],22)+strpad(txt[-1],9)
      text
    }

    return textrows
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

  #parse a page at the market
  def parse_marketpage(page,quality=nil)
    rows = page.search("//div[@id='DIV_BUERO_VORDERGRUND']/table/tr/td/table//td[@class='white2']//tr/td/table/tr")
    rows.shift #remove info line

    #extract & align text data
    rows = rows.map {|item|
      item = tr_text(item,'TRENNER').split('TRENNER')
      item.pop  #drop buying link
      item.pop  #drop total price
      item = strpad(item[0].gsub('.',''), 12) + strpad(item[1][0...30],30) + strpad(item[2],4) + strpad(item[3].gsub('.',''),10)
      item
    }

    #remove lines not matching quality, if any given
    if quality!=nil
      rows.delete_if {|item|
        item.split(' ')[-2] != quality
      }
    end

    return rows
  end
end

#Contains functions which are the commands for the user
module Funcs
  include HelpFuncs

  #exit KapiManager
  def logout(commands)
    Login.logout();
    exit
  end

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
    return true
  end

  #list production/research/warehouse
  def list(commands)
    what = commands[0].to_s

    if (what != 'production' && what != 'research' && what != 'warehouse')
      puts "Usage: list production|research|warehouse"
      return
    end

    puts list_prod_or_res('prod') if what=='production'
    puts list_prod_or_res('res') if what=='research'
    puts parse_warehouse if what=='warehouse'
    return true
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

    if facilityid=="" || product =="" || product != "abort" && (way =="" || number=="" || (way != 'amount' && way != 'time' && way != 'until'))
      puts "Usage: prod <factoryid> <product> time|amount|until <HH[:MM]|number|date>\n\tor: prod <factoryid> abort"
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

    prodinfos = prodsite.search('/html/body/table/tr[2]/td/div/table/tr/script')  #for amount per hour etc.

    index = get_valid_products(prodsite)[product.downcase.to_sym] #save index of chosen product

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

    elsif way=='until'
      #get the stuff out from the script segment (mechanize cant eval js -.-)
      datastring = prodinfos[index].inner_text.split('</div>')[1]
      perhour = datastring.split('pro Std.')[0].split(' ')[-1].to_f

      #calculate time from now until the date and calculate amount...
      require 'time'
      datediff = Time.parse(number) - Time.now  #in seconds
      datediff = datediff.to_i / 60.0 / 60.0  #get hours as fraction
      number = (perhour * datediff).round.to_s
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
      puts "Usage: group create <name> <type>\ngroup delete <name>\ngroup list\ngroup <name> list\ngroup <name> abort\ngroup <name> add|remove <id>\ngroup <name> prod <product> amount|time|until <number|HH[:MM]|date>"
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
      name = cmd.downcase
      cmd = commands[1]

      #check that the group exists
      if $groups[name.to_sym]==nil
        puts 'Group does not exist!'
        return false
      end

      #add a facility to a group (double entries automatically removed) - can process a list of ids
      if cmd=='add'
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

      return true
    end
  end

  #sell amount of product at specified price at market
  def marketsell(commands)
    #check arguments
    if commands.length != 4
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
      puts 'You do not posess '+product+' Q'+quality+'!'
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

    #now here's a problem - the markup of the page is invalid so mechanize
    #can't parse it correctly (the form element seems to be empty)
    #I use a ugly workaround - save the page to a file, correct the HTML
    #and feed it over a file:// URL back into mechanize to continue...
    #
    #by the way I insert the amount we want to sell into the right field,
    #cause it doesnt work as it should over the mechanize form interface oO
    #
    #be careful! don't fuss with the following code... there's a high chance to break it

    #get the lines of the page
    pagestring = warehouse.body
    pagestring = pagestring.split("\n")

    #cut out form start tag + move form close tag, insert amount into right input
    formtag = nil
    row = nil
    pagestring.map! {|line|
      if row != nil   #increment row if we already found the first one
        row += 1
      end
      if line.match(/<FORM.*/) != nil  #form start tag -> extract and delete (moves to a different line)
        row = 0   #its the first row with the products -> begin counting
        formtag = line.match("<FORM.*'><b>Anzahl").to_s[0..-10]
        line.gsub!(formtag,'')
      end
      if line.match('</form></div></td></tr></table>')!=nil   #close tag gets moved
        line.gsub!('</form></div></td></tr></table>','</div></td></tr></table></form>')
      end
      if row == index   #found the row of the product we want to sell -> insert amount
        line.gsub!("name='p_anz[]' size='6' value='0'","name='p_anz[]' size='6' value='#{amount}'")
      end
      line
    }
    formtag.gsub!('main.php4','http://s6.kapilands.eu/main.php4') #make absolute url
    #insert form start tag where it should be
    pagestring.map! {|line|
      if line.match('<table width=100% border=0 cellspacing=0 cellpadding=0><tr>') != nil
        line = formtag + line
      end
      line
    }

    #write to temporary file
    pagestring = pagestring.join("\n")
    f=File.open('ware.html','w')
    f.puts pagestring
    f.close

    #load corrected markup from file and delete file
    path = File.expand_path(File.dirname(__FILE__))+'/ware.html' #absolute path required for file:// URL
    warehouse = $agent.get('file://'+path)
    File.delete('ware.html')

    ######################### END OF UGLY WORKAROUND ############################

    #set the price and submit the form
    form = warehouse.forms[1]
    form['wbet'] = price.gsub('.',',') #european floating sign back...
    page = form.submit

    if page.body.match('stimmen jetzt aber nicht') != nil
      puts 'Something went wrong... sorry :('
      return false
    end

    #confirm
    page = page.forms[1].submit

    #check whether it gives that message...
    if page.body.match(/Bei der Grundstoffe/) != nil
      puts "Your price is higher than NPC price! Can not sell!"
      return false
    end

    #okay :)
    puts "#{amount} of #{product} Q#{quality} sold to market!"
    return true
  end

  #shows the market table sorted by price (and optionally filtered by quality)
  def marketwatch(commands)
    if commands.length < 1
      puts "usage: marketwatch <product in plural> [optional quality]"
      return false
    end

    product = commands[0].to_s.downcase
    quality = commands[1].to_s

    market = $agent.click($city.link_with(:href=>/page=markt/))  #open page
    nonfood = $agent.click(market.link_with(:href=>/prod=1/))     #link to non food page
    food = $agent.get market.link_with(:href=>/prod=1/).node['href'].gsub('&prod=1','') #link to food page

    link = nonfood.link_with(:text=>Regexp.new("#{product[1..-1]}"))
    link = food.link_with(:text=>Regexp.new("#{product[1..-1]}")) if link==nil  #if not found in nonfood stuff

    if link == nil
      puts "Product not found!"
      return false
    end

    marketpage = $agent.click link

    #click on sorting link depending on what we want...
    if quality == ""
      marketpage = $agent.click(marketpage.link_with(:text=>/Preis/))
    else
      marketpage = $agent.click(marketpage.link_with(:text=>/Quali/))
    end

    if quality == ""  #show first page sorted by price
      puts parse_marketpage(marketpage)
      return true
    end

    rows = []
    while rows.length < 16
      rows += parse_marketpage(marketpage, quality)
      rows.flatten  #to break from inner array

      nextpage = marketpage.link_with(:text=>/weiter/)
      break unless nextpage   #if no next page nothing to do anymore

      marketpage = $agent.click(nextpage) #load next page
    end

    puts rows.reverse #reverse cause price is decreasing - I want it increasing
    return true
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
    help += "group <name> prod <product> amount|time|until number|HH<:MM>|date\n"
    help += "prod <id> abort\nprod <id> <product> amount|time|until <number|HH[:MM]|date>\n"
    help += "marketsell <product> <quality> <amount>|all <price>\n"
    help += "marketwatch <product in plural> [optional quality]\n"
    help += "logout\n"
    puts help
  end
end
