ctx = OpenSSL::SSL::SSLContext.new
ctx.ssl_version = :TLSv1_2

Rails.application.config.x.client = Client.new(ENV["UPSTREAM"],
                             ca_chain: ENV["CERT_CHAIN"],
                             cert_file: ENV["CERT"],
                             key_file: ENV["KEY"], #"4_client/private/istio.dev.nexmo.cloud.key.pem",
                             key_passphrase: ENV["PASSPHRASE"],
                             servername: ENV["SERVERNAME"])