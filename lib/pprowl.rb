#
# -*- encoding: utf-8 -*-
#
# PProwl Database
#
$KCODE="UTF8"
$LOAD_PATH.push( File.dirname( __FILE__ ) )

require 'rubygems'
require 'dm-core'
require 'dm-validations'
require 'prowl'
require 'pprowlconfig'

DataMapper::Logger.new( STDOUT, :error )

DataMapper.setup( :default, {
  :adapter  => "sqlite3",
  :database => "#{File.dirname( __FILE__ )}/../db/pprowl.sqlite3",
  :timeout  => 10000
})

class PProwl
  include DataMapper::Resource
  
  property :serial,      Serial
  property :id,          String,  :nullable=>false, :unique_index => true, :unique  => true, :length => 1024
  property :date,        Time
  property :completed,   Boolean, :default => false
  
  storage_names[:default] = 't_pprowl'
  auto_upgrade!
  
  @@apikey = PProwlConfig.new( File.dirname( __FILE__ ) + "/../config.yaml" ).apikey
  
  def self._del
    begin
      PProwl.all( :date.lt => Time.now - 60*60*24 ).each{|m| m.destroy }
    rescue  DataObjects::ConnectionError => e
      if e.message =~ %r{database is locked}
        sleep 0.1
        retry
      else
        raise
      end
    end
  end
  private_class_method :_del
  
  def self._add( message )
    if message[:id] == nil or message[:date] == nil
      return false
    end

    begin
      transaction{|tr|
        status = PProwl.new(
        :id   => message[:id],
        :date => message[:date]
        ).save
        
        if status == false
          tr.rollback
          return false
        end

        status = Prowl.add(
        @@apikey,
        :application => message[:application],
        :event       => message[:event] + "(" + Time.parse(message[:date]).strftime('%H:%M') + ")",
        :description => message[:description],
        :priority    => message[:priority]
        )

        if status == 200
          PProwl.first( :id => message[:id], :completed => false ).update( :completed => true )
        else
          puts "Prowl API returned a error.(#{status})"
          case status
          when 400
            puts "Bad request, the parameters you provided did not validate."
          when 401
            puts "Not authorized, the API key given is not valid, and does not correspond to a user."
          when 405
            puts "Method not allowed, you attempted to use a non-SSL connection to Prowl."
          when 406
            puts "Not acceptable, your IP address has exceeded the API limit."
          when 500
            puts "Internal server error, something failed to execute properly on the Prowl side."
          else
            puts "This error status is unknown."
          end
          
          tr.rollback
          return false
        end
      }
    rescue DataObjects::IntegrityError => e
      raise
    rescue DataObjects::ConnectionError => e
      if e.message =~ %r{database is locked}
        sleep 0.1
        retry
      else
        raise
      end
    end
  end
  private_class_method :_add
  
  def self.add( message )
    if Time.parse( message[:date] ) < Time.now - 60*60*1
      return false
    end

    _add( message ) or return false
    _del
  end
end
