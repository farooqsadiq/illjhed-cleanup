#!/usr/bin/env ruby
#   Modularize
#   Exception Handling
#   Logs

require 'dotenv/load'
require 'sequel'
require 'tiny_tds'
require 'net/ldap'
require 'pry'
require 'awesome_print'
require 'json'

abort "Usage: ruby lib/create_lookup.rb <NVGTC: apl|afl|msel|lsc|sais|welch >"
unless ARGV.size == 1

lookup = Lookup.new(ARGV[0])
lookup.recreate_lookup_table
lookup.run

# welch ldap first pass takes AGES (multiple passes 4-6 just on the As)
# on "ca*" now
# welch 14,121 can be removed in first pass  # only takes a < 5 mins
# trans 1017306 will be deleted (226 not closed) started at 4pm , 10% at 11:40
end




# Populated the lookup table
class Lookup
  def initialize(nvtgc)
    @nvtgc = nvtgc
    @lookup_table = :UsersLookup
    @illiad_table = :UsersALL

    @db_connection_params = {
      adapter: 'tinytds',
      host: ENV['MSSQL_HOST'],
      port: ENV['MSSQL_PORT'],
      database: ENV['MSSQL_DATABASE'],
      user: ENV['MSSQL_USER'],
      password: ENV['MSSQL_PASSWORD']
    }

    @ldap_connection_params = {
      host: ENV['LDAP_HOST'],
      port: ENV['LDAP_PORT'],
      auth: {
        method: :simple,
        username: ENV['LDAP_USER'],
        password: ENV['LDAP_PASSWORD']
      }
    }
    @db = Sequel.connect @db_connection_params
    @ldap = Net::LDAP.new @ldap_connection_params

  end

  def run
    users = fetch_illiad_users
    p users
    i = 0
    users.each do |user|
      confidence = 0
      jhed = nil
      match = []

      # match on uid = JHED, confidence = 4, match = jhed
      filter = Net::LDAP::Filter.eq('uid', user[:username].downcase) \
      &  Net::LDAP::Filter.eq( 'eduPersonOrgUnitDn',  @nvgtc)
      jhed_users = ldap_lookup filter

      if !jhed_users.empty?
        jhed = jhed_users[:uid]
        confidence = 4
        match.push 'jhed'
        if jhed_users[:sn].downcase.include? user[:lastname].downcase
          confidence = 5
          match.push 'sn'
        end
        if jhed_users[:givenname].downcase.include? user[:firstname].downcase
          confidence = 5
          match.push 'givenname'
        end

      elsif user[:emailaddress]
        # match on email confidence = 4, match = email
        filter = Net::LDAP::Filter.eq('mail', user[:emailaddress].downcase) \
               & Net::LDAP::Filter.eq('eduPersonOrgUnitDn', @nvgtc)
        email_users = ldap_lookup filter
        unless email_users.empty?
          jhed = email_users[:uid]
          confidence = 4
          match.push 'email'
          if email_users[:sn].downcase.include? user[:lastname].downcase
            confidence = 5
            match.push 'sn'
          end
          if email_users[:givenname].downcase.include? user[:firstname].downcase
            confidence = 5
            match.push 'givenname'
          end
        end
        i += 1
        p "#{i}: #{user[:username]}, #{jhed}, " \
           + match.uniq.join(',') + " #{confidence}"

      elsif user[:address]
        # match on office address confidence = 2
        filter = Net::LDAP::Filter.eq('physicalDeliveryOfficeName',
                                      "*#{user[:address].downcase}*") \
              & Net::LDAP::Filter.eq('eduPersonOrgUnitDn', @nvgtc)
        address_users = ldap_lookup filter
        unless address_users.empty?
          jhed = address_users[:uid]
          confidence = 3
          match.push 'address'
        end

      end

      # store all values
      insert_lookup(user[:username], jhed, match.uniq.join(','), confidence)
      if jhed
        update_usersall(user[:username], jhed, match.uniq.join(','), confidence)
      end
    end
  end

  # TODO: this is not working, but can create in a db client
  def recreate_lookup_table
    @db.create_table!(@lookup_table) do
      primary_key :id
      String :illiad, unique: true
      String :ldap
      String :match
      Integer :confidence, default: 0
      DateTime :created_at
      DateTime :modified_at
    end
  end

  private

  def fetch_illiad_users
    begin
      # ds =@db[@illiad_table].left_outer_join(@lookup_table,
      #     illiad:  :username).where(userinfo1: nil, nvtgc: @nvgtc ).limit(5)
      ds = @db[@illiad_table].where(userinfo1: nil, nvtgc: @nvtgc).limit(2)
    rescue Sequel::Error => e
      p ds
    end
  end

  def insert_lookup(illiad, ldap, match, confidence)
    date_time = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    # binding.pry
    begin
      @db = Sequel.connect @db_connection_params
      @db[@lookup_table].insert(illiad: illiad,
                                ldap: ldap,
                                match: match,
                                confidence: confidence,
                                created_at: date_time,
                                modified_at: date_time)
    rescue Sequel::Error => e
      p e.message, illiad, ldap, match, confidence, date_time
    end
  end

  def update_usersall(illiad, ldap, match, confidence)
    date_time = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    begin
      @db = Sequel.connect @db_connection_params

      @db[@illiad_table].where(username: illiad).update(
        userinfo1: ldap,
        userinfo2: "#{confidence} #{match}",
        userinfo3: date_time
      )
    rescue Sequel::Error => e
      p e.message, illiad, ldap, match, confidence
    end
  end

  def ldap_lookup(filter)
    treebase = ENV['LDAP_BASE']
    user = {}
    attrs = %w[uid dn displayName email mail sn givenname]
    @ldap.search(base: treebase, filter: filter, attributes: attrs) do |entry|
      entry.each do |attribute, values|
        user[attribute.to_sym] = '' if attribute
        user[attribute.to_sym] += values.join(',') if values
      end
    end
    user
  end
end
