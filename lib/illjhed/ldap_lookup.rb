# frozen_string_literal: true

require 'dotenv/load'
require 'net/ldap'

module Illjhed
  # Lookup LDAP diretory for user information
  class LdapLookup
    # created the ldap connection
    def initialize(nvtgc)
      @nvtgc = nvtgc
      ldap_connection_params = {
        host: ENV['LDAP_HOST'],
        port: ENV['LDAP_PORT_SSL'],
        encryption: { method: :simple_tls }, # required for ldaps
        auth: {
          method: :simple,
          username: ENV['LDAP_USER'],
          password: ENV['LDAP_PASSWORD']
        }
      }
      @ldap = Net::LDAP.new ldap_connection_params
    end

    def match_field(ldap_field, ill_field)
      # validate username not null
      return nil unless ldap_field && ill_field

      filter = Net::LDAP::Filter.eq(ldap_field, ill_field)
      found = ldap_lookup filter

      if found.empty?
        disabled = true
        found = ldap_lookup filter, disabled
      end

      return nil if found.empty?

      confidence = 5
      return_data confidence, found, disabled
    end

    def return_data(confidence, found, disabled)
      date_time = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      confidence = 'disabled ' + confidence.to_s if disabled

      # normalize
      if 'Bloomberg School of Public Health'  == found[:edupersonorgunitdn]
        found[:edupersonorgunitdn] = 'School of Public Health'
      end

      { firstname: found[:givenname],
        lastname: found[:sn],
        emailaddress: found[:mail],
        phone: found[:telephonenumber],
        status: found[:edupersonaffiliation],
        department: found[:edupersonorgunitdn],
        ssn: found[:jhejcardbarcode],
        userinfo2: confidence,
        # cleared: 'No',
        userinfo3: date_time }
    end

    def ldap_lookup(filter, disabled = false)
      treebase = disabled ? ENV['LDAP_BASE_DISABLED'] : ENV['LDAP_BASE']
      user = {}
      attrs = %w[dn uid givenname sn mail telephonenumber edupersonaffiliation
                 edupersonorgunitdn jhejcardbarcode]
      @ldap.search(
        base: treebase,
        filter: filter,
        attributes: attrs,
        return_result: false
      ) do |entry|
        entry.each do |attribute, values|
          user[attribute.to_sym] = '' if attribute
          user[attribute.to_sym] += values.join(',') if values
        end
      end
      user
    end
  end
end
