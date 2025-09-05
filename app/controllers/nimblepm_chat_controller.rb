require 'net/http'
require 'uri'
require 'json'

class NimblepmChatController < ApplicationController
  skip_forgery_protection
  # Allow public access regardless of global login requirement
  skip_before_action :check_if_login_required
  no_authorization_required! :ping, :create

  def ping
    render json: { ok: true, time: Time.now.utc.iso8601 }
  end

  def create
    chatflowid = (params[:chatflowid].presence || default_chatflowid).to_s
    message    = params[:message].to_s
    history    = params[:history].presence || []

    if message.blank?
      render json: { error: 'invalid_request', message: 'message is required' }, status: :bad_request and return
    end

    api_host = ENV.fetch('FLOWISE_API_HOST', 'https://ask.nimble.engineer')
    uri = URI.parse("#{api_host}/api/v1/prediction/#{chatflowid}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 5
    http.read_timeout = 90

    req = Net::HTTP::Post.new(uri.request_uri)
    req['Content-Type'] = 'application/json'
    if (api_key = ENV['FLOWISE_API_KEY']).present?
      req['Authorization'] = "Bearer #{api_key}"
    end

    payload = {
      question: message,
      history: history,
      streaming: false
    }
    req.body = payload.to_json

    res = http.request(req)
    status = res.code.to_i

    # Pass through JSON response (parse safely)
    parsed = {}
    if res.body && !res.body.empty?
      begin
        parsed = JSON.parse(res.body)
      rescue JSON::ParserError
        parsed = { 'raw' => res.body }
      end
    end
    render json: parsed, status: status
  rescue => e
    render json: { error: 'proxy_error', message: e.message }, status: :bad_gateway
  end

  private

  def default_chatflowid
    ENV['FLOWISE_CHATFLOW_ID'].presence || 'e2dfade6-7e37-4fd9-bdae-fb40b614e126'
  end
end
