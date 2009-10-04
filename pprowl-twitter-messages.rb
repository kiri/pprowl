#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
#
# Twitter Direct Messages
#
$KCODE="UTF8"
$LOAD_PATH.push( File.dirname( __FILE__ ) + '/lib' )
require 'kconv'
require 'open-uri'
require 'openssl'
require 'yaml'
require 'base64'
require 'rubygems'
require 'json'

require 'pprowl'
require 'pprowlconfig'

application = "Twitter"
event_title = "Direct Message"
priority = 0
url = "https://twitter.com/direct_messages.json"
config = PProwlConfig.new( File.dirname( __FILE__ ) + "/config.yaml", application )
username = config.username
password = config.password

module OpenSSL
  module SSL
    remove_const :VERIFY_PEER
  end
end
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

begin
  open( url, :http_basic_authentication => [username, password] ){|io|
    JSON.load( io ).sort{|x,y|
      Time.parse(x["created_at"]) <=> Time.parse(y["created_at"])}.each{ |j|
      description = j["sender"]["name"]+"("+j["sender_screen_name"]+"): "+j["text"]
      id = j["id"]
      created_at = j["created_at"]

      PProwl.add(
      :application => application,
      :event       => event_title,
      :description => description,
      :priority    => priority,
      :id          => id,
      :date        => created_at
      ) and sleep 5
    }
  }
rescue Errno::ECONNRESET => e
  puts e.message # Connection reset by peer - SSL_connect 
rescue OpenURI::HTTPError => e
  puts e.message # 502 Bad Gateway
end
