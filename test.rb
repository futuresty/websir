$LOAD_PATH.unshift(File.dirname(__FILE__)) unless $LOAD_PATH.include?(File.dirname(__FILE__))
require 'websir'

w = Websir::Server.new
w.start do |params|
	params[:port] = 3000
end

# sleep 3
# w.stop
w.join