module Baboolya
  class Commands
    def initialize( client )
      @c = client
      @bot = client.bot
      @channels = client.channels
      @config = client.config
      @thr = client.thr
    end

    def commands
      @bot.command( 
        :help,
        description: "Get commands list in DM",
        usage: "No params required" 
      ) do | e | help( e, true ) end

      @bot.command( 
        :get_help,
        description: "Get commands list on channel",
        usage: "No params required"
      ) do | e | help( e, false ) end

      @bot.command(
        :info,
        description: "Get info about me",
        usage: "No params required"
      ) do | e | bot_info( e ) end

      @bot.command(
        :avatar,
        min_args: 1,
        description: "Show user's avatar (get link)",
        usage: "!avatar @kopcap"
      ) do | e, u | avatar( e, u ) end

      @bot.command(
        :empty,
        permission_level: 2,
        description: "Got list of empty roles on the server",
        usage: "!empty",
        permission_message: "Got no perms to do so, sorry."
      ) do | e | empty_roles( e ) end

      @bot.command(
        :ar,
        permission_level: 2,
        description: "Add citizen role to all users, that dont have it",
        usage: "!empty",
        permission_message: "Got no perms to do so, sorry."
      ) do | e | ar( e ) end

      @bot.command(
        :ign,
        min_args: 1,
        permission_level: 3,
        usage: "!ign @kopcap",
        permission_message: "Got no perms to do so, sorry."
      ) do | e, u | ignore( e, u, true ) end

      @bot.command(
        :unign,
        min_args: 1,
        permission_level: 3,
        usage: "!unign @kopcap",
        permission_message: "Got no perms to do so, sorry."
      ) do | e, u | ignore( e, u, false ) end

      @bot.command(
        :eval,
        min_args: 1,
        permission_level: 3,
        usage: "!eval <код для выполнения>",
        permission_message: "Got no perms to do so, sorry."
      ) do | e, *c | code_eval( e, c.join( ' ' ) ) end

      @bot.command(
        :msg,
        min_args: 2,
        permission_level: 3,
        usage: "!msg <channel> <message>",
        permission_message: "Got no perms to do so, sorry."
      ) do | e, ch, *c | s_msg( e, ch, c.join( ' ' ) ) end

      @bot.command(
        :pm,
        min_args: 2,
        permission_level: 3,
        usage: "!pm <user> <message>",
        permission_message: "Got no perms to do so, sorry."
      ) do | e, u, *c | s_pm( e, u, c.join( ' ' ) ) end

      @bot.command(
        :cls,
        permission_level: 3,
        usage: "!cls",
        permission_message: "Got no perms to do so, sorry."
      ) do | e |
        Gem.win_platform? ? ( system "cls" ) : ( system "clear && printf '\e[3J'" )
        e.message.create_reaction "\u2611"
      end

      @bot.command(
        :nuke,
        permission_level: 2,
        min_args: 1,
        description: "This command will delete specified amount (from 2 up to 100) of messages.",
        usage: "!nuke <amount>",
        permission_message: "Got no perms to do so, sorry."
      ) do | e, i | nuke( e, i ) end

      @bot.command(
        :die,
        permission_level: 3
      ) do | e | die( e ) end

      @bot.command(
        :server,
        permission_level: 3
      ) do | e | stats( e ) end
    end

    def s_msg( e, ch, c )
      if ch.to_s !~ /<#\d*>/ then
        e.respond "Can't find this channel"
        return
      end

      ch = @c.parse( ch )
      @bot.send_message( ch, c, nil );
    end

    def s_pm( e, u, c )
      if u.to_s !~ /<@!?\d*>/ then
        e.respond "Can't find this user"
        return
      end

      u = @c.parse( u )
      begin
        @bot.users[ u ].pm( c );
      rescue => err
        e.respond "PM is blocked..."
      end
    end

    def help( e, s )
      t = s ? e.user.pm : e.channel

      t.send_embed do | emb |
        emb.color = "#4A804C"
        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: 'Commands list', url: 'https://github.com/Kopcap94/Discord-AJ', icon_url: 'http://images3.wikia.nocookie.net/siegenax/ru/images/2/2c/CM.png' )

        @bot.commands.each do | k, v |
          if v.attributes[ :permission_level ] == 3 or ( !v.attributes[ :parameters ].nil? and v.attributes[ :parameters ][ :hidden ] ) then next; end

          text = "**Perm's level:** #{v.attributes[ :permission_level ] != 2 ? "all users" : "mods & admins"}\n**Desc:** #{ v.attributes[ :description ] }\n**Usage:** #{ v.attributes[ :usage ] }"
          emb.add_field( name: "#{ @bot.prefix }#{ v.name }", value: text )
        end
      end

      if !e.channel.pm? and s then
        e.message.create_reaction "\u2611"
      end
    end

    def empty_roles( e )
      roles = []

      @bot.servers[ e.server.id ].roles.each do | r | 
        roles.push( r.name ) if r.members.length == 0 && r.name !~ /everyone$/
      end

      if roles.empty? then
        e.respond "There're no empty roles, nice one!"
      else
        e.respond roles.join( "\n" );
      end
    end

    def ar( e )
      e.server.users.each do | u |
        if ( !u.on( e.server.id ).role?( 700376794880278580 ) ) then
          u.add_role( 700376794880278580 )
        end
      end

      e.respond "Done!"
    end

    def die( e )
      @c.thr.each {| k, thr | thr.kill }
      e.respond "I'll be back..."
      exit
    end

    def stats( e )
      ram = %x{ free }.lines.to_a[ 1 ].split[ 1, 3 ].map { | v | ( v.to_f / 1024.0 ).to_i }
      cpu = %x{ top -n1 }.lines.find{ | l | /Cpu\(s\):/.match( l ) }.split[ 1 ]

      e.channel.send_embed do | emb |
        emb.color = "#FFA500"

        emb.title = "Bot's server stats"
        emb.add_field( name: "CPU", value: "#{ cpu }%", inline: true )
        emb.add_field( name: "RAM", value: "#{ ram[ 1 ] }/#{ ram[ 0 ] } mb [#{ ( ( ram[ 1 ].to_f * 100.0 ) / ram[ 0 ].to_f ).to_i }%]", inline: true )

        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: 'AppleJuicetice', url: 'https://github.com/Kopcap94/Discord-AJ', icon_url: 'http://images3.wikia.nocookie.net/siegenax/ru/images/2/2c/CM.png' )
      end
    end

    def avatar( e, a )
      if a.to_s !~ /<@!?\d*>/ then
        e.respond "You have to ping this user, sorry"
        return
      end

      a = @c.parse( a )
      u = @bot.users.find { | u | u[ 0 ] == a }
      if u.nil? then
        e.respond "<@#{ e.user.id }>, can't find this user on the server."
        return
      end

      e.respond "<@#{ e.user.id }>, https://cdn.discordapp.com/avatars/#{ a }/#{ u[ 1 ].avatar_id }.jpg?size=512"
    end

    def nuke( e, a )
      return if e.channel.pm?

      a = @c.parse( a )
      if a.to_s.empty? or a == 1 then
        a = 2
      elsif a > 100 then
        a = 100
      end

      e.channel.prune( a )
      e.respond "<@#{ e.user.id }>, got pruned #{ a } messages."
    end

    def bot_info( e )
      e.channel.send_embed do | emb |
        emb.color = "#4A804C"

        emb.title = "#{ e.user.name }, I'm the Baboolya!"
        emb.description = "I'm a bot, written on Ruby. My main framework is ruby's gem `discordrb`. My additional framework is HTTParty."

        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: 'The Baboolya', url: 'https://github.com/Kopcap94', icon_url: 'http://images3.wikia.nocookie.net/siegenax/ru/images/2/2c/CM.png' )
        emb.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new( url: 'https://cdn.discordapp.com/avatars/702043012230021161/20da0dd870c7ed549e582cb45841d520.jpg' )
      end
    end

    def code_eval( e, c )
      begin
        eval c
      rescue => err
        system "cls"
        puts "Got error #{ err }:\n#{ err.backtrace.join( "\n" ) }"
      end
    end

    def ignore( e, u, s )
      u = @c.parse( u )

      if u == @config[ 'owner' ] then
        e.respond "I'd like to do so, but..."
        return
      elsif s and @bot.ignored?( u ) then
        e.respond "This user is already on my bad-users-to-ignore list ;)"
        return
      elsif s then
        @bot.ignore_user( u )
        @config[ 'ignored' ].push( u )
      else
        @bot.unignore_user( u )
        @config[ 'ignored' ].delete( u )
      end

      @c.save_config
      e.respond "User #{ @bot.users[ u ].username } #{ s ? "will be ignored" : "will not be ignored anymore" }."
    end
  end
end