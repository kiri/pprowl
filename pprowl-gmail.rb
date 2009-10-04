#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
#
# Gmail
#
$KCODE="UTF8"
$LOAD_PATH.push( File.dirname( __FILE__ ) + '/lib' )
require 'kconv'
require 'open-uri'
require 'openssl'
require 'rubygems'
require 'feed-normalizer'
require 'yaml'
require 'base64'
require 'time'
require 'stringio'

require 'pprowl'
require 'pprowlconfig'

application = "Gmail"
event_title = "New Mail"
priority = -1
url = "https://mail.google.com/mail/feed/atom"
title_max_length = 24
author_max_length = 12
begin
  config = PProwlConfig.new( File.dirname( __FILE__ )+"/config.yaml", application )
rescue => e
  puts e.message
  exit
end

username = config.username
password = config.password

module OpenSSL
  module SSL
    remove_const :VERIFY_PEER
  end
end
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

#class Net::HTTP
#  def initialize_new(address, port = nil)
#    # proxy_class = Net::HTTP::Proxy( 'proxy.example.com', 8080 )
#   # proxy_class.new( address, port )
#    initialize_old(address, port)
#  end
#  alias :initialize_old :initialize
#  alias :initialize :initialize_new
#end

begin
  open( url, :http_basic_authentication => [username, password] ){|io|
    FeedNormalizer::FeedNormalizer.parse( StringIO.new(io.read.gsub(/((?:<modified>|<issued>)\d{4}-\d{2}-\d{2}T)24(:\d{2}:\d{2}Z)/,'\100\2')) ).items.sort{|x,y|
      (x.date_published||Time.now)<=>(y.date_published||Time.now) }.each{|i|
      author = i.authors[0].sub( /^\n(.*)\n(.*)\n$/m, '\1' )
      if author.scan( /.{1}/ ).length > author_max_length
        author = author.scan( %r{.{#{author_max_length}}|.+$} )[0] + "…"
      end

      title = i.title or "(no title)"
      if title.scan( /.{1}/ ).length > title_max_length
            title = title.scan( %r{.{#{title_max_length}}|.+$} )[0] + "…"
      end

      description = title + "(" + author + "):" + ( i.description or "(no body)" )
      id = i.id

      if i.date_published == nil
        puts "date_published is nil " + description
        next
      end
      date_published = i.date_published.localtime.to_s
      #date_published = ( i.date_published != nil ? i.date_published.localtime.to_s : Time.now.to_s )

      PProwl.add(
      :application => application,
      :event       => event_title,
      :description => description,
      :priority    => priority,
      :id          => id,
      :date        => date_published
      ) and sleep 5
    }
  }
rescue Errno::ECONNRESET => e
  puts e.message # Connection reset by peer - SSL_connect 
rescue OpenURI::HTTPError => e
  puts e.message # 502 Bad Gateway
end
