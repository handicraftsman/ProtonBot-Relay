ProtonBot::Plugin.new do
  @name        = 'Relays'
  @version     = ProtonBot::Memos::VERSION
  @description = 'Relays for ProtonBot'

  core.permhash['admin'] << 'manage-relays'

  @relays = bot.db_cross.query('relays').ensure.write.finish

  core.help_add('relays', 'addrelay', 'addrelay <serv!chan> <serv!chan>', 'Adds relay')
  cmd(cmd: 'addrelay') do |dat|
    unless @relays
      @relays = bot.db_cross.query('relays').ensure.write.finish
    end
    p1 = dat[:split][0].split('!')
    p2 = dat[:split][1].split('!')
    if p1.length != 2
      dat.nreply 'Invalid p1!'
    elsif p2.length != 2
      dat.nreply 'Invalid p2!'
    else
      obj = {
        'id' => dat[:split][0] + "@" + dat[:split][1],
        'p1' => {
          'server'  => p1[0],
          'channel' => p1[1]
        },
        'p2' => {
          'server'  => p2[0],
          'channel' => p2[1]
        }
      }
      if bot.db_cross.query('relays').ensure.select('id' => (dat[:split][0] + "@" + dat[:split][1])).finish.empty? &&
         bot.db_cross.query('relays').ensure.select('id' => (dat[:split][1] + "@" + dat[:split][0])).finish.empty?
        bot.db_cross.query('relays').ensure.insert(obj).write.finish
        @relays << obj
      end
      dat.nreply 'Done!'
    end
  end.perm!('manage-relays')

  core.help_add('relays', 'delrelay', 'delrelay <serv!chan> <serv!chan>', 'Deletes relay')
  cmd(cmd: 'delrelay') do |dat|
    to_del = nil
    @relays.each do |r|
      if r['id'] == dat[:split][0] + "@" + dat[:split][1]
        to_del = r
        break
      end
      if r['id'] == dat[:split][1] + "@" + dat[:split][0]
        to_del = r
        break
      end
    end
    bot.db_cross.query('relays').ensure.delete(to_del).write.finish
    @relays.delete(to_del)
    dat.nreply 'Done!'
  end.perm!('manage-relays')

  core.help_add('relays', 'relayinfo', 'relayinfo (id)', 'Shows info about relay')
  cmd(cmd: 'relayinfo') do |dat|
    if dat[:split].empty?
      dat.nreply ProtonBot::Bot::Messages::NOT_ENOUGH_PARAMETERS
    else
      dat[:split].each do |id|
        if @relays[id.to_i]
          r = @relays[id.to_i]
          s = "%C%BLUE#{r['p1']['server']}!#{r['p1']['channel']}%N <-> %C%PURPLE#{r['p2']['server']}!#{r['p2']['channel']}%N"
          dat.nreply("%Br#{id}:%N #{s}")
        else
          dat.nreply("No such relay: #{id}")
        end
      end
    end
  end

  fun :getchan do |dat, relay, cid=:reply_to|
    this  = {'server' => dat[:plug].name, 'channel' => dat[cid]}
    other = nil
    if    relay['p1'] == this
      other = relay['p2']
    elsif relay['p2'] == this
      other = relay['p1']
    end
    [this, other]
  end

  fun :getop do |this, other|
    if other
      bot.plugs[other['server']]
    else
      nil
    end
  end

  hook(type: :privmsg) do |dat|
    unless @relays
      @relays = bot.db_cross.query('relays').ensure.write.finish
    end
    @relays.each_with_index do |v, k|
      this, other = *getchan(dat, v)
      if op = getop(this, other) and op.chans[other['channel']] and dat[:message][0] != "\x01"
        op.privmsg(other['channel'], "%N[%Br#{k}%B]%N %B<%N#{dat[:nick]}%B>%N #{dat[:message]}")
      end
    end
  end

  hook(type: :ctcp) do |dat|
    unless @relays
      @relays = bot.db_cross.query('relays').ensure.write.finish
    end
    @relays.each_with_index do |v, k|
      this, other = *getchan(dat, v)
      if op = getop(this, other) and op.chans[other['channel']]
        if dat[:cmd] == 'ACTION'
          op.privmsg(other['channel'], "%N[%Br#{k}%B]%N %B<%N#{dat[:nick]}%B>%N %C%BLUE* #{dat[:split].join(' ')}")
        else
          op.privmsg(other['channel'], "%N[%Br#{k}%B]%N %B<%N#{dat[:nick]}%B>%N %C%BLUE[CTCP] #{dat[:message]}")
        end
      end
    end
  end

  hook(type: :ujoin) do |dat|
    unless @relays
      @relays = bot.db_cross.query('relays').ensure.write.finish
    end
    @relays.each_with_index do |v, k|
      this, other = *getchan(dat, v, :channel)
      if op = getop(this, other) and op.chans[other['channel']]
        op.privmsg(other['channel'], "%N[%Br#{k}%B]%N %B%C%PURPLE#{dat[:nick]}%N has joined %B%C%GREEN#{dat[:channel]}%N")
      end
    end
  end

  hook(type: :upart) do |dat|
    unless @relays
      @relays = bot.db_cross.query('relays').ensure.write.finish
    end
    @relays.each_with_index do |v, k|
      this, other = *getchan(dat, v, :channel)
      if op = getop(this, other) and op.chans[other['channel']]
        op.privmsg(other['channel'], "%N[%Br#{k}%B]%N %B%C%PURPLE#{dat[:nick]}%N has left %B%C%GREEN#{dat[:channel]}%N")
      end
    end
  end

  hook(type: :uquitc) do |dat|
    unless @relays
      @relays = bot.db_cross.query('relays').ensure.write.finish
    end
    @relays.each_with_index do |v, k|
      this, other = *getchan(dat, v, :channel)
      if op = getop(this, other) and op.chans[other['channel']]
        op.privmsg(other['channel'], "%N[%Br#{k}%B]%N %B%C%PURPLE#{dat[:nick]}%N has quit %B%C%BLUE(#{dat[:reason]})%N")
      end
    end
  end

  hook(type: :ukick) do |dat|
    unless @relays
      @relays = bot.db_cross.query('relays').ensure.write.finish
    end
    @relays.each_with_index do |v, k|
      this, other = *getchan(dat, v, :channel)
      if op = getop(this, other) and op.chans[other['channel']]
        op.privmsg(other['channel'], "%N[%Br#{k}%B]%N %B%C%PURPLE#{dat[:nick]}%N has " +
          "kicked %B%C%PURPLE#{dat[:target]}%N from %B%C%GREEN#{dat[:channel]}%N " +
          "%B%C%BLUE(#{dat[:reason]})%N")
      end
    end
  end

  hook(type: :unickc) do |dat|
    unless @relays
      @relays = bot.db_cross.query('relays').ensure.write.finish
    end
    @relays.each_with_index do |v, k|
      this, other = *getchan(dat, v, :channel)
      if op = getop(this, other) and op.chans[other['channel']]
        op.privmsg(other['channel'], "%N[%Br#{k}%B]%N %B%C%PURPLE#{dat[:nick]}%N is now known as %B%C%PURPLE#{dat[:to]}%N")
      end
    end
  end
end