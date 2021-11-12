module Baboolya
  class List
    def initialize( client )
      @c = client
      @bot = client.bot
      @channels = client.channels
      @lists = client.lists
    end

    def commands
      @bot.command(
        :addimg,
        min_args: 2,
        description: "Add image to list",
        usage: "!addimg <listname> <imglink>"
      ) do | e, list, img | add_image( e, list, img ) end

      @bot.command(
        :showlists,
        description: "Get names of lists",
        usage: "No params required"
      ) do | e | show_lists( e ) end

      @lists.each do | name, arr |
        create_command( name )
      end
    end

    def create_command( name )
      @bot.command(
        ( "l" + name ).to_sym,
        description: "Get random image from list " + name,
        usage: "No params required" 
      ) do | e | post_image( e, name ) end

      @bot.command(
        ( "del" + name ).to_sym,
        permission_level: 2,
        min_args: 1,
        description: "Delete image from list " + name,
        usage: "!del" + name + " <id>" 
      ) do | e, id | delete_from_list( e, name, id.to_i ) end
    end

    def add_image( e, l, i )
      if e.channel.pm? then
        e.respond "Sorry buddy, but you have to do it on the server"
        return
      end

      if @lists[ l ].nil? then
        e.respond "Ok, lets create new list with name '#{ l }' since I don't have it."
        @lists[ l ] = []

        create_command( l )
      end

      @lists[ l ].push( i )
      @c.save_list

      e.respond "Done! Added image to list #{ l } with image ID ##{ @lists[ l ].count - 1 }."
    end
    
    def show_lists( e )
      if e.channel.pm? then
        e.respond "Sorry buddy, but you have to do it on the server"
        return
      end
      
      e.respond @lists.keys.join( "\n" )
    end

    def post_image( e, t )
      if e.channel.pm? then
        e.respond "Sorry buddy, but you have to do it on the server"
        return
      end

      if @lists[ t ].count == 0 then
        e.respond "Sorry, this list is empty, lol"
        return
      end

      get_image = @lists[ t ].sample
      emb = Discordrb::Webhooks::Embed.new
      emb.color = "#507299"
      emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: "List name: #{ t }", url: "" )
      emb.add_field( name: "ID", value: @lists[ t ].index( get_image ) )
      emb.image = Discordrb::Webhooks::EmbedImage.new( url: get_image )

      @bot.send_message( e.channel.id, '', false, emb )
    end

    def delete_from_list( e, t, id )
      if e.channel.pm? then
        e.respond "Sorry buddy, but you have to do this on the server"
        return
      end

      if @lists[ t ][ id ].nil? then
        e.respond "Sorry, can't find this id."
        return
      end

      @lists[ t ].delete_at( id )
      @c.save_list

      e.respond "Yeah, done! Image ID ##{ id } from list #{ t } got pruned."
    end
  end
end