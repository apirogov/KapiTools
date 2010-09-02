#!/usr/bin/env ruby
#AutoKapi
#Copyright (C) 2010 Anton Pirogov
#Licensed under the GPL version 3 or later

#TODO: a bit refactoring, adding support for type checking for groups, then something with ressource calculation?

#Contains helping functions invisible to the user
module HelpFuncs

  #add spaces to achieve wished size of string
  def strpad(str,num)
    str+=' '*(num-str.length)
    return str
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
    rows=site.search('/html/body/table/tr[2]/td/div/div[4]/table/tr')

    #create readable text lines for each row
    textrows = []
    rows.each{|x|
      str = ''
      x.element_children.each{|y| str += y.text + ' '}
      textrows << str
    }

    #filter junk out and output
    textrows.delete_if{|row| row.split(' ')[0].match(/:/) == nil }
    puts textrows
  end

  #get list of warehouse items
  def list_warehouse()
    #create "new tab" with research facilities
    warehouse = $agent.click($city.link_with(:href=>/page=lager/))

    #get table cells and recreate table as text
    tablerows = warehouse.search('//*[@id="TABLE_MY_PRODUCTS_IN_STOCK"]/tr')

    rowstrings=[]
    tablerows.each{|x|
      if x.to_s.match(/>\d+/)!=nil
        str=''
        x.element_children.each{|y| str += strpad(y.text,20) }
        rowstrings << str.strip
      end
    }

    puts rowstrings
  end
end

#Contains functions which are the commands for the user
module Funcs
  include HelpFuncs

  PRODTAB_XPATH = '/html/body/table/tbody/tr[2]/td/div/div[4]/table'    #used quite often

  #get info like bar/capital/level etc
  def info(commands)
    #extract info rows
    infos = $city.search('/html/body/table/tr/td/table/tr/td[2]/table/tr')
    lines=[]
    infos.each{|y| lines << y.text.strip}#

    #remove junk and output
    lines[0] = lines[0][0..lines[0].index("\n")].strip
    lines[3] = lines[3][0..lines[3].index("\n")].strip
    lines[-1] = lines[-1][0...lines[-1].index("(")].strip
    puts lines
  end

  #list production/research/warehouse
  def list(commands)
    what = commands[0].to_s

    if (what != 'production' && what != 'research' && what != 'warehouse')
      puts "Usage: list production/research/warehouse"
      return
    end

    list_prod_or_res('prod') if what=='production'
    list_prod_or_res('res') if what=='research'
    list_warehouse if what=='warehouse'
  end

  #create facility_id => direct link hash
  def create_cache(commands)
    $prodlinkcache = Hash.new

    #Go to town view -> main page
    $browser.link(:id,'href_stadt').click
    #go to production
    $browser.link(:id,'href_prod').click

    $browser.table(:xpath,PRODTAB_XPATH).rows.to_a.each_with_index{|factory,i|
      rowtext = $browser.table(:xpath,PRODTAB_XPATH).rows[i].text
      fac = rowtext.split(' ')[0]   #get facilityId of row

      if fac.split(':').length == 2  #a facility row
        failed = false
        begin
          link = $browser.table(:xpath,PRODTAB_XPATH).rows[i].links[0].html.match(/main.php.*"/).to_s #get the fac. url
          #create a real url
          link = 'http://s6.kapilands.eu/'+link
          link = link.gsub("&amp;","&")[0...-1] #make real & and drop the final "
        rescue
          failed = true
        end

        #no error getting link -> add to hash
        $prodlinkcache[fac] = link if !failed
      end
    }

    #output:
    #$prodlinkcache.each{|key,val| puts key + "=>"+val }
    puts "Temporary factory cache created!"
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


    link = nil
    #rowtext nil && link !nil or vice versa, but not both

    #if no prodlinkcache built or facility id not in there -> go to page and check
    if $prodlinkcache == nil || $prodlinkcache[facilityid] == nil
      #Go to town view -> main page
      $browser.link(:id,'href_stadt').click
      #go to production
      $browser.link(:id,'href_prod').click

      rowtext=nil
      index=0
      #get row text and index of accodring building id
      $browser.table(:xpath,PRODTAB_XPATH).rows.to_a.each_with_index{|factory,i|
        if factory.text.match(/.*#{facilityid}.*/)
          rowtext = $browser.table(:xpath,PRODTAB_XPATH).rows[i].text
          index = i
          break
        end
      }
    else
      link = $prodlinkcache[facilityid]
    end

    #abort production? try...
    if product == 'abort'
      #not cached link -> do check
      if rowtext != nil && rowtext.match(/.*bereit.*/)
        puts 'Nothing to abort!'
        return false
      end

      #open page either from cachelink or from site
      if link != nil
        $browser.goto(link)
      else
        $browser.table(:xpath,PRODTAB_XPATH).rows[index].links[0].click
      end

      #exception handling because of cached link -> cant see "bereit"...
      begin
        $browser.link(:id,'A_PRODUKTION_ABBRECHEN').click
      rescue
        puts "Nothing to abort!"
        return false
      end

      puts "Production in #{facilityid} aborted!"
      return true
    end

    #not cached link -> do check
    if rowtext != nil && rowtext.match(/.*bereit.*/)==nil
        puts "Abort current production first!"
        return false
    end

    #load production page either from cachelink or from site
    if link!=nil
      $browser.goto(link)
    else
      $browser.table(:xpath,PRODTAB_XPATH).rows[index].links[0].click
    end

    #exception handling because of cached link -> cant see "bereit"...
    if link==nil
      begin
        test = $browser.link(:id,'A_PRODUKTION_ABBRECHEN').html
       #should raise exception here
       puts "Abort current production first!"
       return false
     rescue
       #fine... not found -> can produce
      end
    end

    #create product name -> link index hash and index -> intern index array
    proditems = $browser.table(:xpath,'/html/body/table/tbody/tr[2]/td/div/table').rows[0]
    indexhash = Hash.new
    itoreali = Array.new
    proditems.cells.each_with_index{|c,i|
      indexhash[c.links[0].images[0].src.split('/')[-1].split('.')[0].downcase.to_sym] = i
    }
    proditems.cells.each_with_index{|c,i|
      itoreali.push c.links[0].html.split(' ')[3].split(')')[0].to_i
    }

    if indexhash[product.downcase.to_sym] == nil
      puts "You can't produce #{product} here!" #invalid prod for facility -> fail
      return false
    end

    #start production
    proditems.cells[indexhash[product.downcase.to_sym]].links[0].click
    form = $browser.table(:id,'TABLE_PRODUKT_PRODUZIEREN_MYPRODUCTTABLE').row(:id,'TABLE_PRODUKT_PRODUZIEREN_MYPRODUCTTABLE_TRID_'+itoreali[indexhash[product.downcase.to_sym]].to_s)

    #calculate absolute amount from time
    if way=='time'
      perhour = $browser.cell(:xpath,"//span[@id='SPAN_PRODUKT_PRODUZIEREN_PLATZHALTER']/table/tbody/tr/td/table/tbody/tr[2]/td").text.split("\n")[-1].split(' ')[-3].to_f
      number = (perhour*number.split(':')[0].to_i + perhour/60*number.split(':')[1].to_i).round
    end

    #set amount
    form.cells[0].text_fields[0].value = number
    #click button
    $browser.button(:value, ' jetzt produzieren ').click

    #check for "not enough stuff" error
    begin
      if $browser.cell(:xpath,"//div[@id='DIV_Spielfeld_Unterseiten_Overlay_ProduktBuy']/table/tbody/tr/td[@class='white2']/table/tbody/tr[2]/td[@class='white']").text.match('brauchst du') != nil
        puts "Not enough ressources!"
        return false
      end
    rescue
      #not found? gooood!
    end

    puts "Production of #{number} #{product} in #{facilityid} started!"
    return true
  end

#TODO: WHAT FRIGGIN MORON DID WRITE THIS FUNC?? oh, dammit, I did... RE-FUCKING-FACTOR!!! and COMMENT
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
    help += "create_cache (run once after login, speeds up group productions 2-3x)\n"
    puts help
  end
end
