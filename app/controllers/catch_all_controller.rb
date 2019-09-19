class CatchAllController < ApplicationController
  # respond_to :html, :js
  # catch all proxy route
  def index

    headers = request.env.select {|k,v| k =~ /^HTTP_/}

    resp = Rails.configuration.x.client.get params[:path], params.except(:path, :controller, :action, :format, :debug, :catch_all), headers

    respond_to do |format|
      format.json { render_json(resp, params[:debug] && params[:debug] == 'true') }
    end
  end

  def favicon
    render "", status: :not_found
  end

  def render_json(resp, debug=false)
    res = { body: JSON.parse(resp[:body]) }
    if debug
      res[:log] = resp[:log].join("\n")
    end
    render json: res
  end

end
