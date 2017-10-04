require 'faye'
require 'set'
Faye::WebSocket.load_adapter('puma')

class ServerAuth
  def incoming(message, callback)
    if (/\/meta\/*/ =~ message['channel'] || message['channel'] == '/online/client')
      return callback.call(message)
    end

    msg_token    = message['data'] && message['data']['authToken']

    token = 'openredu'

    if token != msg_token
      message['error'] = 'Invalid subscription auth token'
    end

    callback.call(message)
  end
end

app = Faye::RackAdapter.new(:mount => '/faye', :timeout => 25) do |bayeux|
  @users = Set.new
  @users_channels = {}

  bayeux.on(:handshake) do |client_id|
    p "#{client_id} handshaking"
  end

  bayeux.on(:subscribe) do |client_id, channel|
    p "#{client_id} subscribes on #{channel}"
  end

  bayeux.on(:unsubscribe) do |client_id, channel|
    p "#{client_id} unsubscribes on #{channel}"
    if(channel == '/online/server')
      @users.delete_if do |user|
        user['client_id'] == client_id
      end
      bayeux.get_client.publish(
        '/online/server',
        {users: @users.to_a.map { |x| x.select {|k,v| k != 'client_id' && k != 'authToken' && k != 'channel' }}, 'authToken' => 'openredu'}
      )
    end
  end

  bayeux.on(:publish) do |client_id, channel, data|
    if (channel == '/online/client')
      if @users_channels[data['channel']] == data['user_id']
        client = {'client_id' => client_id}
        @users << data.merge(client)

        bayeux.get_client.publish(
        '/online/server',
        {users: @users.to_a.map { |x| x.select {|k,v| k != 'client_id' && k != 'authToken' && k != 'channel' }}, 'authToken' => 'openredu'}
      )
      end
    end

    if (channel == '/online/confirm')
      @users_channels.merge!(data.reject{|k,v| k == 'authToken'})
    end

    p "#{client_id} published #{data} on #{channel}"
  end
end

app.add_extension(ServerAuth.new)
run app
