#!/usr/bin/ruby
#
#  Provide a caching API for facter facts.
#
#  Uses YAML storage in a single key hash based on
#  the name of the fact.
#
#  Based on https://puppet.com/blog/facter-part-3-caching-and-ttl
#
#   Copyright 2016 Jeremiah Powell <waveclaw@hotmail.com>
#
#   See LICENSE for licensing.
#
#
require 'facter'
require 'time'
require 'yaml'

module Facter::Util::Facter_cacheable
  @doc=<<EOF
  Cache a result for a TTL using facter that supports external facts.
  Default Time-to-live is 1 hour (3600 seconds).
EOF
  class << self
    # Get the on disk cached value or hit the callback to find it
    # @param key string The identifier for the data
    # @param ttl integer Time-to-live in seconds which defauls to 1 hr (3600)
    # @param source string Fully-qualified path to altnerative YAML file
    # @return [object] Cached value (hash, string, array, number, etc)
    # @api public
    def cached?(key, ttl = 3600, source = nil)
      cache = nil
      # which cache?
      mycache = get_cache(key, source)
      cache_file = mycache[:file]
      # check cache
      if File::exist?(cache_file) then
         begin
           cache = YAML.load_file(cache_file)
           # returns [{}] structures if valid for Cached Facts
           cache = cache[0] if cache.is_a? Array
           cache = nil unless cache.is_a? Hash
           cache_time = File.mtime(cache_file)
         rescue Exception => e
             Facter.debug("#{e.backtrace[0]}: #{$!}.")
             cache = nil
             cache_time = Time.at(0)
         end
      end
      if ! cache || (Time.now - cache_time) > ttl
         cache = nil
      end
      cache
    end

    # Write out a cache of data
    # @param key string The identifier for the data
    # @param ttl integer Time-to-live in seconds which defauls to 1 hr (3600)
    # @param source string Fully-qualified path to altnerative YAML file
    # @return [object] Cached value (hash, string, array, number, etc)
    # @api public
    def cache(key, value, source = nil)
       if key && value
         mycache = get_cache(key, source)
         cache_file = mycache[:file]
         cache_dir = mycache[:dir]
         begin
           if !File::exist?(cache_dir)
                Dir.mkdir(cache_dir)
           end
           # don't use the Rubyist standard pattern so we can test with rspec
           out = File.open(cache_file, 'w')
           YAML.dump({(key.to_s) => value}, out)
           out.close()
         rescue Exception => e
           Facter.debug("#{e.backtrace[0]}: #{$!}.")
         end
       end
    end

    # find a source
    # @param key [symbol] The identifier to use
    # @return file [string, string] The cachefile location
    # @api private
    def get_cache(key, source)
       if ! source
         cache_dir = '/etc/facter/facts.d'
         if Puppet.features.external_facts?
           for dir in Facter.search_external_path
             # the plugin facts directory in /var/lib is cleaned each run
             if (File.exist?(dir)) #and
               #dir != '/var/lib/puppet/facts.d' and
               #dir != '/opt/puppetlabs/puppet/cache/facts.d/') # PE 2015 location
               cache_dir = dir
               break
             end
           end
         end
         keystring = key.to_s
         cache_file = "#{cache_dir}/#{keystring}.yaml"
       else
           cache_dir = nil
           cache_file = source
       end
       {:file => cache_file, :dir => cache_dir }
    end
  end
end
