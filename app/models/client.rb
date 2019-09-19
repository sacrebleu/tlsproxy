require 'net/http'
require 'openssl'
require 'openssl/x509'
require 'openssl/pkey'
require 'json'

class Client
  attr_reader :env, :opts

  # opts:
  #   :use_ssl    [true] - whether or not to use ssl
  #   :port        [443] - the endpoint port to connect to
  #   :ssl_timeout   [2] - the ssl timeout
  #   :verify_mode  [OpenSSL::SSL::VERIFY_PEER] - the openssl verify mode to use
  #   :verify_depth [2]  - the certificate depth to verify
  #
  def initialize(env, opts)
    @env = env
    @opts = opts
  end

  # perform an HTTP get against the remote cluster
  def get(path, params, headers)

    https = Net::HTTP.new(env, opts.fetch(:port, Net::HTTP.https_default_port))
    https.set_debug_output $stdout

    chain = opts.fetch(:ca_chain)

    https.use_ssl     = opts.fetch(:use_ssl, true)
    https.ssl_timeout = opts.fetch(:ssl_timeout, 2)
    https.ssl_version = :TLSv1_2_client
    https.verify_mode = opts.fetch(:verify_mode, OpenSSL::SSL::VERIFY_PEER)
    https.verify_depth = opts.fetch(:verify_depth, 2)
    https.ssl_verification_hostname = opts.fetch(:servername)

    if https.use_ssl?
      https.ca_file = chain
      https.cert = OpenSSL::X509::Certificate.new File.read(opts.fetch(:cert_file))
      https.key = OpenSSL::PKey::RSA.new File.read("#{opts.fetch(:key_file)}"), opts.fetch(:key_passphrase)
    end

    https.instance_eval {
      @ssl_context = OpenSSL::SSL::SSLContext.new(:TLSv1_2)
      options = OpenSSL::SSL::OP_NO_SSLv2 | OpenSSL::SSL::OP_NO_SSLv3 | OpenSSL::SSL::OP_NO_TLSv1 | OpenSSL::SSL::OP_NO_TLSv1_1
      if OpenSSL::SSL.const_defined?('OP_NO_COMPRESSION')
        options |= OpenSSL::SSL::OP_NO_COMPRESSION
      end
      @ssl_context.set_params(ca_file: chain, options: options)
    }

    # https.instance_variable_names.each do |v|
    #   Rails.logger.info "k: #{v}, v: #{https.instance_variable_get(v).inspect}"
    # end

    # Rails.logger.info https.ssl_context

    # Rails.logger.info https.pretty_print_instance_variables
    # # Rails.logger.info https
    # Rails.logger.info https.key
    # Rails.logger.info https.cert
    # Rails.logger.info https.ca_file
    # Rails.logger.info https.address

    https.start do |http|
      uri = URI::HTTPS.build(host: env, path: "/#{path}")
      uri.query = URI.encode_www_form(params.to_unsafe_h)

      req = Net::HTTP::Get.new(uri)

      # ensure headers are sent
      headers.each do |k,v|
        req[k] = v
      end

      req["Host"] = opts.fetch(:servername) # used for SNI on istio ingressgateway

      response = https.request(req)


      { body: response.body, log: log(req, response), headers: response.header }
    end
  end

  private

  def log(request, response)
    l = longest(request.each_header, response.each_header)
    buf = []

    buf << "Request #{request.method} #{request.uri}"
    request.each_header do |h|
      buf << "> %#{l}s - %s" % [h, request[h]]
    end
    # buf << ""

    buf << "Response %s %s" % [response.code, "-"*60]
    response.each_header do |h|
      # puts "< #{h}\t#{response[h]}"
      buf << "< %#{l}s - %s" % [h, response[h]]
    end

    buf << "< %#{l}s - %s" % ["Code", response.code]
    buf << "< %#{l}s - %s" % ["Body", JSON.parse(response.body.to_s)]

    buf
  end

  def longest(a, b)
    [a.to_a.collect{|s| s[0].length}.max, b.to_a.collect{|s| s[0].length}.max].max
  end

end