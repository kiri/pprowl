#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
#
# PProwl Config
#
$KCODE="UTF8"
$LOAD_PATH.push(File.dirname(__FILE__))
require 'kconv'
require 'yaml'
require 'base64'

class PProwlConfig
  @@config = nil
  
  @apikey = nil
  @username = nil
  @password = nil
  @filename = nil
  
  def initialize( filename, application = nil )
    begin
      @filename = filename
      @@config = YAML.load_file( @filename );
      raise "#{filename} is invalid yaml." unless @@config
    rescue Errno::ENOENT
      raise "#{filename} is not exist."
    end
    
    load_prowl
    
    if application
      load(application)
    end
  end
  
  def load_prowl
    @apikey = @@config[:prowl][:apikey] if @@config[:prowl] and @@config[:prowl][:apikey]
    unless @apikey
      puts "Prowl apikey is not found."
      exit
    end
  end
  
  def load( application )
    @@config[:applications].each{|c|
      if c[:application] == application

        unless /^base64::/ =~ c[:config][:password]
          c[:config][:password] = "base64::" + Base64.encode64(c[:config][:password]).chomp
          File.open( @filename, 'w' ){|io| YAML.dump( @@config, io ) }
        end

        @username = c[:config][:username]
        @password = Base64.decode64((c[:config][:password]).sub(/^base64::/,''))

        break
      end
    }

    unless @username or @password
      puts "#{@filename} is not enough configured."
      exit
    end
    
  end
  
  attr_reader :apikey
  attr_reader :username
  attr_reader :password
end
