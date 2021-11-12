require 'discordrb'
require 'json'
require 'httparty'
require 'down'

module Baboolya
  class Main
    attr_accessor :bot, :channels, :config, :thr, :lists

    Discordrb::LOGGER = Discordrb::Logger.new(false, [File.open('dbg.txt', 'a+')])

    def initialize
      unless File.exists?( 'cfg.json' )
        File.open( 'cfg.json', 'w+' ) {|f| f.write( JSON.pretty_generate({ 
          'token' => '', 
          'id' => '',
          'prefix' => '!', 
          'owner' => [],
          'groups' => { 'access_token' => '' },
          'ignored' => []
        }))}
        puts "Создан новый конфиг, заполните его."
      end

      @config = JSON.parse( File.read( 'cfg.json' ) )
      @lists = JSON.parse( File.read( 'list.json' ) )
      @bot = Discordrb::Commands::CommandBot.new( 
        token: @config[ 'token' ],
        log_mode: :debug,
        client_id: @config[ 'id' ],
        prefix: @config[ 'prefix' ],
        help_command: false,
        ignore_bots: true,
        intents: [
          :servers,
          :server_members,
          :server_bans,
          :server_emojis,
          :server_webhooks,
          :server_messages,
          :server_message_reactions,
          :direct_messages
        ],
        no_permission_message: "You don't have enough permissions to do this, hehe."
      )
      @channels = {}
      @thr = {}
      @cfg_mutex = Mutex.new
      @error_log = Mutex.new
      @started = false
    end

    def start
      @bot.ready do | e |
        puts "Ready!"
        @bot.update_status( 'Baboolya', 'Baking...', nil )

        @config[ 'owner' ].each do | own |
          @bot.set_user_permission( own, 3 )
        end

        update_info

        if !@started then
          ignore_users
          register_modules
          GC.start(full_mark: true, immediate_sweep: true)

          @started = true
        end

        @bot.update_status( 'Baboolya', '!help/!get_help', nil )
      end

      @bot.pm do | e |
        if !@config[ 'owner' ].include?( e.user.id ) then
          b = e.message.timestamp.to_s.gsub( /\s\+\d+$/, '' ) + " #{ e.user.name } [#{ e.user.id }]: "
          File.open( 'pm.log', 'a' ) { |f| f.write( b + e.message.content.split( "\n" ).join( "\n" + b ) + "\n" ) }
        end
      end

      @bot.server_create do | e |
        s = e.server
        c = e.server.general_channel
      end

      @bot.member_join do | e |
        next unless @bot.profile.id != e.user.id
        if e.server.channels.count == 0 then
          Discordrb::LOGGER.info( "[TRACK ERROR] GOT ERROR WITH ZERO CHANNEL AND NOT WORKING MEMBERS!" )
          @bot.stop
        end

        emb = Discordrb::Webhooks::Embed.new

        emb.color = "#00FF00"
        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: "User has joined the server!", url: "" )
        emb.add_field( name: "Discord ID", value: "#{ e.user.name }##{ e.user.discriminator }" )
        emb.add_field( name: "User link", value: "<@#{ e.user.id }>" )
        emb.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new( url: "https://cdn.discordapp.com/avatars/#{ e.user.id }/#{ e.user.avatar_id }.jpg?size=256" )

        @bot.send_message( 702044438498639925, '', false, emb )
        e.user.add_role( 700376794880278580 )
      end

      @bot.member_leave do | e |
        next unless @bot.profile.id != e.user.id
        if e.server.channels.count == 0 then
          Discordrb::LOGGER.info( "[TRACK ERROR] GOT ERROR WITH ZERO CHANNELS AND NOT WORKING MEMBERS!" )
          @bot.stop
        end

        emb = Discordrb::Webhooks::Embed.new

        emb.color = "#FF0000"
        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: "User has left the server!", url: "" )
        emb.add_field( name: "Discord ID", value: "#{ e.user.name }##{ e.user.discriminator }" )
        emb.add_field( name: "User link", value: "<@#{ e.user.id }>" )
        emb.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new( url: "https://cdn.discordapp.com/avatars/#{ e.user.id }/#{ e.user.avatar_id }.jpg?size=256" )

        @bot.send_message( 702044438498639925, '', false, emb )
      end

      @bot.message( containing: /https?:../i, in: 700429523644317806 ) do | e |
        next if ( e.author.on( e.server.id ).role?( 861474248401092638 ) or /https?:..tenor\.com/ix.match?( e.message.content ) or /https?[^\s]+\.gif/ix.match?( e.message.content ) )

        emb = Discordrb::Webhooks::Embed.new

        emb.color = "#FF0000"
        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: "Запостил ссылку без роли", url: "" )
        emb.add_field( name: "ID", value: "<@#{ e.user.id }> [#{ e.user.name }##{ e.user.discriminator }]" )
        emb.add_field( name: "Сообщение", value: e.message.content[0..500] )
        emb.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new( url: "https://cdn.discordapp.com/avatars/#{ e.user.id }/#{ e.user.avatar_id }.jpg?size=256" )

        @bot.send_message( 750645395981336607, "", false, emb )
        e.message.delete()

        begin
          e.user.pm.send_embed do | em |
            em.color = "#FF0000"
            em.author = Discordrb::Webhooks::EmbedAuthor.new( name: "Oops, something went wrong.", url: "", icon_url: 'http://images3.wikia.nocookie.net/siegenax/ru/images/2/2c/CM.png' )
            em.add_field( name: "Issue?", value: "You tried to post in \"#artist-office\" without the role!" )
            em.add_field( name: "Rule?", value: "\"#artist-office\" uses @Artist role to allow to post art. However, everyone is free to comment. This was done to prevent posting art by newcomers, who haven't yet learned the culture of the server. To receive a role, send a DM to one of the admins (@Sultan or @Emir) with your art galleries attached." )
            em.add_field( name: "Contact?", value: "If you think you received this message by mistake, contact admins via DMs (Direct Messages)." )
            em.add_field( name: "You?", value: "Please, do not ask me. I'm only a simple Babushka bot, I won't be able to answer your complex hi-tech questions. It's between you cool kids." )
          end
        rescue => err
          @bot.send_message( 750645395981336607, "Участник не оповещён, у него заблокирована личка!", false )
        end
      end

      @bot.message_edit( in: 700429523644317806 ) do | e |
        next unless !e.author.on( e.server.id ).role?( 861474248401092638 ) && /https?:../i.match?( e.message.content )

        emb = Discordrb::Webhooks::Embed.new

        emb.color = "#FF0000"
        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: "Отредактировал и добавил ссылку", url: "" )
        emb.add_field( name: "ID", value: "<@#{ e.user.id }> [#{ e.user.name }##{ e.user.discriminator }]" )
        emb.add_field( name: "Сообщение", value: e.message.content[0..500] )
        emb.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new( url: "https://cdn.discordapp.com/avatars/#{ e.user.id }/#{ e.user.avatar_id }.jpg?size=256" )

        @bot.send_message( 750645395981336607, "", false, emb )
        e.message.delete()

        begin
          e.user.pm.send_embed do | em |
            em.color = "#FF0000"
            em.author = Discordrb::Webhooks::EmbedAuthor.new( name: "Oops, something went wrong.", url: "", icon_url: 'http://images3.wikia.nocookie.net/siegenax/ru/images/2/2c/CM.png' )
            em.add_field( name: "Issue?", value: "You tried to post in \"#artist-office\" without the role!" )
            em.add_field( name: "Rule?", value: "\"#artist-office\" uses @Artist role to allow to post art. However, everyone is free to comment. This was done to prevent posting art by newcomers, who haven't yet learned the culture of the server. To receive a role, send a DM to one of the admins (@Two Royals or @Family member) with your art galleries attached." )
            em.add_field( name: "Contact?", value: "If you think you received this message by mistake, contact admins via DMs (Direct Messages)." )
            em.add_field( name: "You?", value: "Please, do not ask me. I'm only a simple Babushka bot, I won't be able to answer your complex hi-tech questions. It's between you cool kids." )
          end
        rescue => err
          @bot.send_message( 750645395981336607, "Участник не оповещён, у него заблокирована личка!", false )
        end
      end

      @bot.reaction_add( emoji: "⚠️" ) do | e |
        em = e.message.reactions.find { |emoji| emoji.name == e.emoji.name }
        is_op = [ 168064956548382720, 251254954419945472, 161079996130131969, 151129747517210624, 171183557790793729, 341169289354674186 ].include?( e.user.id )
        is_count = ( em.count >= 3 && !em.me )

        move_to_trash( e.message, e.user.id ) if is_op
        alarm_trash( e.message, e.channel.id ) if is_count & !is_op
      end

      @bot.mention do | e |
        a = [
          "hi there!",
          "yeah, sup?",
          "ayo!",
          "stay where you are!",
          "keep going!",
          "staph",
          "https://www.youtube.com/watch?v=jfrL4GFsyDY",
          "why, #{ e.user.name }, why? Why, why do you do it? Why, why get up? Why keep pinging me? Do you believe you're doing this for something, for more than your survival? Can you tell me what it is, do you even know? Is it freedom or truth, perhaps peace — could it be for love? Illusions, #{ e.user.name }, vagaries of perception. Temporary constructs of a feeble human intellect trying desperately to justify an existence that is without meaning or purpose. And all of them as artificial as the Matrix itself. Although, only a human mind could invent something as insipid as love. You must be able to see it, #{ e.user.name }, you must know it by now! You can't win, it's pointless to keep fighting! Why, #{ e.user.name }, why, why do you persist? "
        ]
        e.respond "<@#{ e.user.id }>, #{ a.sample }"
      end

      @bot.raw do | e |
        update_info
        ev = @bot.servers[ 700375065396772964 ]

        next if ev.nil?

        if ev.channels.count == 0 then
          Discordrb::LOGGER.info( "[TRACK ERROR] GOT ERROR WITH ZERO CHANNELS AND NOT WORKING MEMBERS ON SERVER RAW!" )
          @bot.stop
        end
      end

      @bot.run
    end

    def register_modules
      Thread.new {
        Baboolya.constants.select do | c |
          if Baboolya.const_get( c ).is_a? Class then
            if c.to_s == "Main" then
              next
            end

            m = Baboolya.const_get( c ).new( self )

            if Baboolya.const_get( c ).method_defined? "commands" then
              m.commands
            end
          end
        end
      }
    end

    def update_info
      @bot.servers.each do | k, v |
        @channels[ k ] = {}
        v.roles.each do | arr, i |
          perm = arr.permissions
          @bot.set_role_permission( arr.id, ( perm.kick_members or perm.ban_members or perm.administrator or perm.manage_server ) ? 2 : 1 )
        end
        v.channels.each {| arr | @channels[ k ][ arr.name ] = arr.id }
      end
    end

    def move_to_trash( msg, u )
    a = msg.author
      emb = Discordrb::Webhooks::Embed.new

        emb.color = "#FF0000"
        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: "Nuked by ⚠️", url: "" )
        emb.add_field( name: "#ID", value: "#{ msg.id }" )
        emb.add_field( name: "User", value: "<@#{ a.id }> [#{ a.name }##{ a.discriminator }]" )
        emb.add_field( name: "Nuker", value: "<@#{ u }>" )
        emb.add_field( name: "Content", value: ( msg.content != "" ? msg.content[0..500] : "-" ) )
        emb.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new( url: "https://cdn.discordapp.com/avatars/#{ a.id }/#{ a.avatar_id }.jpg?size=256" )

        if ( msg.content =~ /^https?:\/\/[^\s]+$/ )
          emb.image = Discordrb::Webhooks::EmbedImage.new( url: msg.content.match( /^https?:\/\/[^\s]+$/ )[0] )
        end

        @bot.send_message( 750645395981336607, "", false, emb )

        if ( msg.attachments.count != 0 )
          begin
            img = Down.download( msg.attachments[0].url )
            @bot.send_file( 750645395981336607, img, caption: "Dump of image from issue [#ID #{msg.id}]" )
           img = nil
         rescue => e
           puts e.inspect
           @bot.send_message( 750645395981336607, "Error on saving image :/", false )
         end
        end

        msg.delete()
    end

    def alarm_trash( msg, ch )
      a = msg.author

      emb = Discordrb::Webhooks::Embed.new

        emb.color = "#FFA500"
        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: "Notify by ⚠️", url: "" )
        emb.add_field( name: "id", value: "<@#{ a.id }> [#{ a.name }##{ a.discriminator }]" )
        emb.add_field( name: "link", value: "[link](https://discord.com/channels/700375065396772964/#{ ch }/#{ msg.id })" )
        emb.add_field( name: "msg", value: ( msg.content != "" ? msg.content[0..500] : "-" ) )
        emb.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new( url: "https://cdn.discordapp.com/avatars/#{ a.id }/#{ a.avatar_id }.jpg?size=256" )

        if ( msg.attachments.count != 0 )
          emb.image = Discordrb::Webhooks::EmbedImage.new( url: msg.attachments[0].url )
        elsif ( msg.content =~ /^https?:\/\/[^\s]+$/ )
          emb.image = Discordrb::Webhooks::EmbedImage.new( url: msg.content.match( /^https?:\/\/[^\s]+$/ )[0] )
        end

        @bot.send_message( 750645395981336607, "", false, emb )

        msg.react( "⚠️" )
    end

    def can_do( s, t, c = nil )
      return @bot.profile.on( s ).permission?( t.to_sym, c )
    end

    def ignore_users
      return if @config[ 'ignored' ].count == 0

      @config[ 'ignored' ].each do | u |
        @bot.ignore_user( u )
      end
    end

    def save_config
      @cfg_mutex.synchronize do
        File.open( 'cfg.json', 'w+' ) {|f| f.write( JSON.pretty_generate( @config ) ) }
      end
    end
    
    def save_list
      @cfg_mutex.synchronize do
        File.open( 'list.json', 'w+' ) {|f| f.write( JSON.pretty_generate( @lists ) ) }
      end
    end

    def error_log( err, m )
      @error_log.synchronize do
        puts "New error for #{ m } on errors log."
        s = "[#{ m }] #{ err }:\n#{ err.backtrace.join( "\n" ) }\n#{ "=" * 10 }\n"
        File.open( 'error.log', 'a' ) {|f| f.write( s ) }
      end
    end

    def parse( i )
      return i.gsub( /[^\d]+/, '' ).to_i
    end
  end
end
