require "json"
require "socket"
require "time"

module Sano
  OK = 'OK'
  WARNING = 'WARNING'
  CRITICAL = 'CRITICAL'

  LEVELS = [ OK, WARNING, CRITICAL]

  class Page
    attr_accessor :application, :status, :system

    def initialize
      @details = []
      @datasources = []
      @application = Application.new
      @system = SystemInfo.new
      @properties = {}
    end

    def add_property(key, value)
      @properties[key] = value
    end

    def add_datasource(ds)
      @datasources << ds
    end

    def add_detail(detail)
      @details << detail

      calculate_status
      true
    end

    def to_json
      json_hash = {
        'application' => @application.to_h.merge({'statusDetails' => {}}),
        'system' => @system.to_h,
        'datasources' => [],
        'properties' => @properties
      }

      @details.each do |d|
        json_hash['application']['statusDetails'][d.name] = d.to_h
      end

      @datasources.each do |d|
        json_hash['datasources'] << d.to_h
      end

      JSON.dump(json_hash)
    end

    protected

    def calculate_status
      tmp_status = OK

      @details.each do |d|
        if LEVELS.index(d.status) > LEVELS.index(tmp_status)
          tmp_status = d.status
        end
      end

      @application.status = tmp_status
      @status = tmp_status
    end
  end

  class Application < Struct.new(:name, :status, :version)
    def to_h
      {
        'name' => name,
        'status' => status,
        'version' => (version || "UNSET")
      }
    end
  end

  class SystemInfo
    attr_accessor :hostname, :system_time

    def initialize
      @hostname = Socket.gethostbyname(Socket.gethostname).first
      @system_time = Time.now
    end

    def to_h
      {
        'hostname' => @hostname,
        'systemTime' => @system_time.iso8601
      }
    end
  end

  class Detail < Struct.new(:name, :status, :message, :link)
    attr_accessor :properties

    def initialize
      status = OK
      @properties = {}
    end

    def self.create(&block)
      d = Detail.new
      yield(d) if block_given?

      d
    end

    def to_h
      {
        'name' => name,
        'status' => status,
        'properties' => properties,
        'message' => message,
        'uri' => link
      }
    end
  end

  class Datasource
    attr_accessor :name, :type, :properties, :hosts

    def initialize(name, type, hosts = [], properties = {})
      @name = name
      @type = type
      @hosts = hosts
      @properties = properties
    end

    def self.create(&block)
      datasource = Datasource.new("unnamed", "unknown")

      yield(datasource) if block_given?

      datasource
    end

    def to_h
      {
        'name' => @name,
        'type' =>  @type,
        'hosts' => @hosts,
        'properties' => @properties
      }
    end
  end
end
