# TLSProxy

Version 0.0.18

#### Overview

TLSProxy is a service that accepts incoming http calls and wraps them in an ssl request to
an uptream https host, using a client certificate and performing certificate validation.

It is intended to allow legacy services that make http calls to perform mutual TLS with
istio, without the need for the legacy services to implement certificate validation and ssl.

It is intended to run on a private network, permitting connections only from private services, as it does
zero authentication and merely forwards requests.

In brief, tlsproxy should behave like the following openssl command:

    openssl s_client -connect istio-ingressgateway.istio-system.svc.cluster.local:443 -CAfile /etc/certs/cert-chain.pem -key /etc/certs/client-key.pem  -cert /etc/certs/client-cert.pem
    
    <tls handshake negotiation redacted>
    ---
    GET /mtls/test HTTP/1.1
    Accept: application/json
    Content-Type: application/json
    Host: <redacted>
    
    HTTP/1.1 200 OK
    content-type: application/json; charset=utf-8
    etag: W/"8e8f966667caf9262bb4c8e9e668453f"
    cache-control: max-age=0, private, must-revalidate
    x-request-id: 56916249-28fa-46bb-a481-4d34d77b3538
    x-runtime: 0.001456
    x-envoy-upstream-service-time: 3
    date: Tue, 17 Sep 2019 12:00:36 GMT
    server: istio-envoy
    transfer-encoding: chunked
    
    23
    {"request":"/mtls/test","ssl":true}
    
and should proxy external calls through TLS as above.