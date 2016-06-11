#!/usr/bin/ruby -S rspec
#
#  Test the facter_cachable utility
#
#   Copyright 2016 JD Powell <waveclaw@hotmail.com>
#
#   See LICENSE for licensing.
#

require 'spec_helper'
require 'stringio'
require 'yaml'
require 'time'
require 'facter'
require 'facter/util/facter_cacheable'

default_data = {
  :single => "--- \n  string_value: tested",
  :list_like   => "--- \n  list_value: \n    - thing1\n    - thing2",
  :hash_like   =>
    "--- \n  hash_value: \n    alpha: one\n    beta: two\n    tres: three",
}

puppet_6 = {
  :single => "---\nstring_value: tested",
  :list_like   => "---\n  list_value:\n    - thing1\n    - thing2\n",
  :hash_like   =>
    "---\n  hash_value:\n    alpha: one\n    beta: two\n    tres: three\n",
}

case Facter.value(:puppetversion)
 when '3.6.0', '4.4.2'
   data = puppet_6
 else
   data = default_data
 end

# YAML.load* does not return symbols as hash keys!
expected = {
  :single => { "string_value" => 'tested' },
  :list_like   => { "list_value" => [ 'thing1', 'thing2' ] },
  :hash_like   => { "hash_value" => {
    'alpha' => 'one', 'beta'  => 'two', 'tres'  => 'three' } }
}

describe "Facter::Util::Facter_cacheable.cached?", :type => :function do

context "when the cache is hot" do
data.keys.each { |testcase|
    cache = "/tmp/#{testcase.to_s}.yaml"
    rawdata = StringIO.new(data[testcase])
    it "for #{testcase.to_s} values should return the cached value" do
      expect(Puppet.features).to receive(:external_facts?) { true }
      expect(Facter).to receive(:search_external_path) { ['/tmp'] }
      expect(File).to receive(:exist?).with('/tmp') { true } # get_cache
      expect(File).to receive(:exist?).with(cache) { true }
      expect(YAML).to receive(:load_file).with(cache) {
        YAML.load_stream(rawdata)
      }
      expect(File).to receive(:mtime).with(cache) { Time.now }
      expect(Facter::Util::Facter_cacheable.cached?(testcase)).to eq(
        expected[testcase])
    end
  }
  end

  context "when the cache is cold" do
    data.keys.each { |testcase|
        cache = "/tmp/#{testcase.to_s}.yaml"
        rawdata = StringIO.new(data[testcase])
        it "for #{testcase.to_s} values should return nothing" do
          expect(Puppet.features).to receive(:external_facts?) { true }
          expect(Facter).to receive(:search_external_path) { ['/tmp'] }
          expect(File).to receive(:exist?).with('/tmp') { true } # get_cache
          expect(File).to receive(:exist?).with(cache) { true }
          expect(YAML).to receive(:load_file).with(cache) {
            YAML.load_stream(rawdata)
          }
          expect(File).to receive(:mtime).with(cache) { Time.at(0) }
          expect(Facter::Util::Facter_cacheable.cached?(testcase)).to eq(nil)
        end
    }
  end

  context "when the cache is missing" do
    data.keys.each { |testcase|
        cache = "/tmp/#{testcase.to_s}.yaml"
        rawdata = StringIO.new(data[testcase])
        it "for #{testcase.to_s} values should return nothing" do
          expect(Puppet.features).to receive(:external_facts?) { true }
          expect(Facter).to receive(:search_external_path) { ['/tmp'] }
          expect(File).to receive(:exist?).with('/tmp') { true } # get_cache
          expect(File).to receive(:exist?).with(cache) { false }
          expect(YAML).to_not receive(:load_file).with(cache)
          expect(File).to_not receive(:mtime).with(cache)
          expect(Facter::Util::Facter_cacheable.cached?(testcase)).to eq(nil)
        end
    }
  end

  context "for garbage values" do
    cache = "/tmp/garbage.yaml"
    rawdata = StringIO.new('random non-yaml garbage')
    it "should return nothing" do
      expect(Puppet.features).to receive(:external_facts?) { true }
      expect(Facter).to receive(:search_external_path) { ['/tmp'] }
      expect(File).to receive(:exist?).with('/tmp') { true } # get_cache
      expect(File).to receive(:exist?).with(cache) { true }
      expect(YAML).to receive(:load_file).with(cache) {
          YAML.load_stream(rawdata)
      }
      expect(File).to receive(:mtime).with(cache) { Time.now }
      expect(Facter::Util::Facter_cacheable.cached?('garbage')).to eq(nil)
    end
  end
end

describe "Facter::Util::Facter_cacheable.cache", :type => :function do
data.keys.each { |testcase|
  result = StringIO.new('')
  key = (expected[testcase].keys)[0]
  value = expected[testcase][key]
  cache = "/tmp/#{key}.yaml"
  it "should store a #{testcase.to_s} value in YAML" do
    expect(Puppet.features).to receive(:external_facts?) { true }
    expect(Facter).to receive(:search_external_path) { ['/tmp'] }
    expect(File).to receive(:exist?).with('/tmp') { true } # get_cache
    expect(File).to receive(:exist?).with('/tmp') { true } # mk missing dir
    # cannot do this test with a lambda like the File.open block passed in
    expect(File).to receive(:open).with(cache, 'w') { result }
    # WTF? called 785 times?
    #expect(YAML).to receive(:dump).with({ key => value }, result) {
    #    YAML.dump({ key => value }, result)
    #}
    Facter::Util::Facter_cacheable.cache(key, value)
    expect(result.string).to eq(data[testcase])
  end
}
  context "for garbage values" do
    it "should output nothing" do
      result = StringIO.new('')
      cache = "/tmp/.yaml"
      expect(Puppet.features).to_not receive(:external_facts?) { true }
      expect(Facter).to_not receive(:search_external_path) { ['/tmp'] }
      expect(File).to_not receive(:exist?).with('/tmp') { true }
      expect(File).to_not receive(:open).with(cache, 'w') { result }
      Facter::Util::Facter_cacheable.cache(nil, nil)
      expect(result.string).to eq('')
    end
  end
end
