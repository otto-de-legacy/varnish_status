#!/usr/bin/env ruby


require "sinatra"
require "json"
require "timeout"
require "pp"
require "ostruct"
require "yaml"

require "./sano"

class VarnishBackendStatus
  attr_accessor :directors

  class Backend < OpenStruct
    def to_hash
      table
    end
  end

  class Director
    attr_reader :name, :status, :availability, :healthy_backends, :sick_backends
    attr_accessor :backends

    def initialize(name)
      @name = name
      @backends = []
      @status = "WARNING"
      @availability = 0

      @healthy_backends = 0
      @sick_backends = 0
    end

    def add_backend(be)
      @backends << be
      recalc_status

      true
    end

    def to_hash
      recalc_status

      {
        :name => @name,
        :status => @status,
        :backends => @backends.map { |b| b.to_hash },
        :availability => @availability,
        :healthy_backends => @healthy_backends,
        :sick_backends => @sick_backends,
      }
    end

    private

    def recalc_status
      @healthy_backends = @backends.select { |be| be.status == "HEALTHY" }.size
      @sick_backends = @backends.size - @healthy_backends

      @availability = (@healthy_backends.to_f / @backends.size)

      @status = "WARNING"
      @status = "OK" if @availability == 1
      @status = "CRITICAL" if @availability < CONFIG[:critical_threshold]
    end
  end

  def initialize
    @directors = {}
  end

  def to_json
    json_struct = {}

    @directors.each do |dname, dir|
      json_struct[dname] = dir.to_hash
    end

    JSON.dump(json_struct)
  end

  def self.create_from_varnishadm(proxy_target)
    varnish_ident = CONFIG[:varnishadm_opts]
    varnish_adm_cmd = CONFIG[:varnishadm]

    out=`#{varnish_adm_cmd} #{varnish_ident} backend.list`
    if out.empty?
      puts "no result from varnish (cmd: #{varnish_adm_cmd.inspect} #{varnish_ident})"
    end

    backend_status = VarnishBackendStatus.new

    out.split("\n").each do |line|
      m = line.match(/(\w+)\((([0-9]{1,3}\.){3}[0-9]{1,3})\,[:0-9]*\,(\d+)\) (\d+)\s*probe(.*)/)
      if m
        name = m[1]
        ip = m[2]
        port = m[4]
        refs = m[5]
        probe_status = m[6].strip.split(" ")

        status = probe_status[0]
        probes = probe_status[1..-1].join(" ")

        name_match = name.match(/(\w+)(_)(\w+)/)
        if !name_match
          host = name
          director = name
        else
          host = name_match[1]
          director = name_match[3]
        end
        backend_status.directors[director]  ||= Director.new(director)
        backend_status.directors[director].add_backend(Backend.new({:name => name, :ip => ip, :port => port, :refs => refs, :status => status.upcase, :probes => probes, :host => host}))
      end
    end

    backend_status
  end
end

CONFIG = YAML.load_file(File.join(File.dirname(__FILE__), "config.yaml"))

class VarnishStatus < Sinatra::Base
  set :root, File.dirname(__FILE__)

  get "/" do
    @vbs = VarnishBackendStatus.create_from_varnishadm(CONFIG[:proxy_mnemonic])

    erb :index
  end

  get "/internal/details" do
    content_type "application/json"

    vbs = VarnishBackendStatus.create_from_varnishadm(CONFIG[:proxy_mnemonic])
    vbs.to_json
  end

  get "/internal/status" do
    content_type "application/json"

    vbs = VarnishBackendStatus.create_from_varnishadm(CONFIG[:proxy_mnemonic])
    page = Sano::Page.new
    page.application.name = CONFIG[:proxy_name]

    vbs.directors.each do |dname, dir|
      director_detail = Sano::Detail.create do |d|
        d.name = dname
        d.status = dir.status
        d.message = "#{dir.healthy_backends} / #{dir.backends.size} in healthy state"
      end

      page.add_detail(director_detail)
    end

    page.to_json
  end
end
