# frozen_string_literal: true

require 'dotenv/load'
require 'sequel'
require 'tiny_tds'

module Illjhed
  # Loopup ILLiad UsersALL table for users in a nvtgc
  class IllLookup
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
      @db = Sequel.connect @db_connection_params
    end

    # retrive users for which JHED have not been found
    def fetch_users(limit)
      system_users = %w[AFL APL LSC MSEL SAIS WELCH reserve Nanjing ILS1]
      ds = @db[@illiad_table].where(
        userinfo1: nil,
        userinfo3: nil,
        emailaddress: nil,
        nvtgc: @nvtgc
      ).exclude(
        username: system_users,
        cleared: %w[DIS]
      ).order_by(
        :userinfo3
      ).limit(limit)
    rescue Sequel::Error => e
      p 'ERROR: ' + e.message + ds
    end

    # retrive users for which JHED have not been found
    def fetch_users(limit)
      system_users = %w[AFL APL LSC MSEL SAIS WELCH reserve Nanjing ILS1 welchharrison]
      ds = @db[@illiad_table].where(
        nvtgc: @nvtgc,
        cleared: 'No'
      ).exclude(
        username: system_users
      ).exclude(
        cleared: %w[DIS]
      ).exclude(
        Sequel.ilike(:UserName, '%@%')
      ).order_by(:nvtgc).order_by(:userinfo3).limit(limit)
      # ap ds.sql exit
    rescue Sequel::Error => e
      p 'ERROR: ' + e.message + ds
    end

    def fetch_welch_duplicate_users_in_welch(limit)
      system_users = %w[AFL APL LSC MSEL SAIS WELCH reserve Nanjing ILS1]
      ds = @db[@illiad_table].where(
        nvtgc: @nvtgc
      ).where(
        Sequel.ilike(
          :userinfo4,
          '%School of Medicine%',
          '%School of Public Health%',
          '%School of Nursing%'
        )
      ).exclude(
        username: system_users,
        nvtgc: 'WELCH',
        cleared: %w[DIS No]
      ).order_by(:nvtgc).order_by(:username).limit(limit)
    rescue Sequel::Error => e
      p 'ERROR: ' + e.message + ds
    end


    def update_user_by_username(username, data)
      @db = Sequel.connect @db_connection_params
      @db[@illiad_table].where(username: username).update(data)
    rescue Sequel::Error => e
      ap data
      p e.message
    end
  end
end
