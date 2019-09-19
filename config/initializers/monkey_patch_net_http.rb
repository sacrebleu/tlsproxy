# this monkey patch provides the ability to specify the ssl_verification_hostname which is necessary
# for SNI where we are connecting to an endpoint (e.g. an ingress gateway) from inside a cluster and need
# to manually specify the server hostname so the correct SSL certificate can be served to the client
module Net
  class HTTP
    attr_accessor :ssl_verification_hostname

    def connect
      D "Net::HTTP::connect monkeypatch"

      if proxy? then
        conn_address = proxy_address
        conn_port    = proxy_port
      else
        conn_address = address
        conn_port    = port
      end

      D "opening connection to #{conn_address}:#{conn_port}..."
      s = Timeout.timeout(@open_timeout, Net::OpenTimeout) {
        begin
          TCPSocket.open(conn_address, conn_port, @local_host, @local_port)
        rescue => e
          raise e, "Failed to open TCP connection to " +
              "#{conn_address}:#{conn_port} (#{e.message})"
        end
      }
      s.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      D "opened"
      if use_ssl?
        if proxy?
          plain_sock = BufferedIO.new(s, read_timeout: @read_timeout,
                                      continue_timeout: @continue_timeout,
                                      debug_output: @debug_output)
          buf = "CONNECT #{@address}:#{@port} HTTP/#{HTTPVersion}\r\n"
          buf << "Host: #{@address}:#{@port}\r\n"
          if proxy_user
            credential = ["#{proxy_user}:#{proxy_pass}"].pack('m0')
            buf << "Proxy-Authorization: Basic #{credential}\r\n"
          end
          buf << "\r\n"
          plain_sock.write(buf)
          HTTPResponse.read_new(plain_sock).value
          # assuming nothing left in buffers after successful CONNECT response
        end

        ssl_parameters = Hash.new
        iv_list = instance_variables
        SSL_IVNAMES.each_with_index do |ivname, i|
          if iv_list.include?(ivname) and
              value = instance_variable_get(ivname)
            ssl_parameters[SSL_ATTRIBUTES[i]] = value if value
          end
        end
        @ssl_context = OpenSSL::SSL::SSLContext.new
        @ssl_context.set_params(ssl_parameters)
        D "starting SSL for #{conn_address}:#{conn_port}..., verifying against #{@ssl_verification_hostname || @address}"
        s = OpenSSL::SSL::SSLSocket.new(s, @ssl_context)
        s.sync_close = true
        # Server Name Indication (SNI) RFC 3546
        s.hostname = @ssl_verification_hostname || @address if s.respond_to? :hostname=
        if @ssl_session and
            Process.clock_gettime(Process::CLOCK_REALTIME) < @ssl_session.time.to_f + @ssl_session.timeout
          s.session = @ssl_session if @ssl_session
        end
        ssl_socket_connect(s, @open_timeout)
        if @ssl_context.verify_mode != OpenSSL::SSL::VERIFY_NONE
          s.post_connection_check(@ssl_verification_hostname || @address)
        end
        @ssl_session = s.session
        D "SSL established"
      end
      @socket = BufferedIO.new(s, read_timeout: @read_timeout,
                               continue_timeout: @continue_timeout,
                               debug_output: @debug_output)
      on_connect
    rescue => exception
      if s
        D "Conn close because of connect error #{exception}"
        s.close
      end
      raise
    end
    private :connect
  end
end