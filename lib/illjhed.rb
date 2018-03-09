# frozen_string_literal: true

require './lib/illjhed/ill_lookup.rb'
require './lib/illjhed/ldap_lookup.rb'
require 'awesome_print'

# Lookup JHED using LDAP and populate the UserInfo fields with match info
module Illjhed
  def self.run(nvtgc, limit)
    ill = IllLookup.new(nvtgc)
    # users = ill.fetch_users(limit)
    users = ill.fetch_users(limit)

    i = 0
    users.each do |user|
      ap user[:username]
      result = match_user(user, nvtgc)
      ap result
      if result
         ill.update_user_by_username(user[:username], result)
      end
      i += 1
    end
  end

  def self.match_user(user, nvtgc)
    ldap = LdapLookup.new(nvtgc)
    ldap.match_field('uid', user[:username].downcase)
  end
end

abort 'Usage:illjhed <NVGTC: apl|afl|msel|lsc|sais|welch> limit=1' unless ARGV.size >= 1
limit = ARGV[1] || '1'
Illjhed.run(ARGV[0], limit)
