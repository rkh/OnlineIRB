require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra-websocket'

class App < Sinatra::Base
  register Sinatra::Reloader
  set :server, 'thin'
  set :sockets, []
  enable :logging

  not_found do
    erb :"404.html"
  end

  get '/about' do
    erb :"about.html"
  end

  get '/index' do
    @ruby_v = "#{RUBY_VERSION}"
    @ruby_v << "p#{RUBY_PATCHLEVEL}" if RUBY_PATCHLEVEL
    erb :"index.html"
  end

  get '/' do
    unless (request.websocket? rescue nil)
      @ruby_v = "#{RUBY_VERSION}"
      @ruby_v << "p#{RUBY_PATCHLEVEL}" if RUBY_PATCHLEVEL
      erb :"ws.html"
    else
      request.websocket do |ws|
        ws.onmessage do |msg|
          ws.send( evaluate(msg) )
          settings.sockets << ws
        end
        ws.onclose do
          warn("websocket closed")
          settings.sockets.delete(ws)
        end
      end
    end
  end

  get '/unsupported' do
    erb :"index.html"
  end

  def evaluate(message)
    stdout_id = $stdout.to_i
    cmd = <<-EOF
      $SAFE = 3
      $stdout = StringIO.new
      begin
        class IRB < Sinatra::Base; #{message} ; end
      end
    EOF
    begin
      respond = eval(cmd, TOPLEVEL_BINDING)
      result  = " => #{respond.nil? ? 'nil' : respond }"
    rescue SecurityError
      result = "SecurityError: Can't process this line!"
    rescue Exception => e
      result = e.message.gsub(/<|>/,"")
    ensure
      begin
        output = get_stdout
      rescue
        output = ""
        result = "SyntaxError: Can't process this line!"
      end
      $stdout = IO.new(stdout_id)
    end
    output.empty? ? result : "#{output}<br />#{result}"
  end

  def get_stdout
    $stdout.rewind
    $stdout.read
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end

