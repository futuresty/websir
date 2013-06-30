require 'socket'

module Websir
	# module for manage server default params.
	module Param
		attr_accessor :params
		def params_with(params)
			self.params = self.class.default_params.dup
			if params 
				unless params.instance_of? Hash 
					raise "invalid params:it's must be hash"
				end
				params.each do |key, value|
					if self.params.keys.include? key 
						self.params[key] = value
					end
				end
			end
		end

		module DefaultParam
			# define default param for klass.
			def define_param(key, value)
				self.default_params ||= {}
				self.default_params[key] = value
			end
		end

		def self.included(klass)
			klass.extend(DefaultParam)
			class << klass
				attr_accessor :default_params
			end
		end

		private :params_with
	end

	# module for manage server status.
	module ServerFsm
		def state_initialize
			@status = :end
		end

		def change_state_to(another_state)
			case another_state
			when :start
				raise "status must be end." unless @status == :end 
				server_start self
				@status = :start
			when :end
				raise "status must be start." unless @status == :start 
				server_end self
				@status = :end
			end
		end

		def server_start(serv)
			puts "#{serv.params[:server_name]} start..."
		end

		def server_end(serv)
			puts "#{serv.params[:server_name]} stop..."
		end
	end

	class Server
		include Param
		include ServerFsm

		def initialize(params = nil)
			params_with params
			state_initialize
		end

		def start
			params = {}
			if block_given?
				yield params
			end
			params_with params

			@tcp_serv = TCPServer.new self.params[:port]
			@thread = Thread.new(@tcp_serv) do |serv|
				event_loop serv
			end
			change_state_to :start
		end

		def stop
			@tcp_serv.close if @tcp_serv
		end

		def join
			@thread.join if @thread
		end

		def handle_request(tcp_socket)
			lines = []
			while line = tcp_socket.gets and line !~ /^\s*$/
				lines << line.chomp
			end
			
			return if lines.size == 0 
			request_line = {}
			header = {}
			get_params = {}
			# analyse request line.
			args = lines[0].split
			keys = [:method, :uri, :version]
			keys.each_with_index do |key, index|
				request_line[key] = args[index]
			end

			# analyse header
			lines[1...-1].each do |ln|
				cmds = ln.split(/: /, 2)
				case cmds[0].downcase
				when "host"
					header[:host] = cmds[1]
				when "connection"
					header[:connection] = cmds[1]
				end
			end

			# analyse get params
			request_line[:uri].split("?", 2).each_with_index do |str, index|
				if index == 0
					request_line[:uri] = str
				else
					str.split("&&").each do |s|
						arr = s.split("=", 2)
						get_params[arr[0]] = arr[1]
					end
				end
			end
			# puts "request_line:#{request_line}\nheader:#{header}\nget_params:#{get_params}"
		end

		def event_loop(sock_serv)
			reading = []
			reading << sock_serv
			loop do
				# puts "<=="
				# reading.each {|socket| puts socket.object_id}
				# puts "==>"
				begin
					rds = IO.select(reading)
					rds[0].each do |socket|
						if socket == sock_serv
							reading <<  sock_serv.accept_nonblock
						else
							handle_request socket
							socket.close
							reading.delete socket
						end
					end
				rescue Errno::ENOTSOCK
					self.change_state_to :end
					break
				end
			end

		end

		private :event_loop

		define_param :server_name, "websir"
		define_param :port, 8080
		define_param :work_dir, File.dirname(__FILE__)
	end
end