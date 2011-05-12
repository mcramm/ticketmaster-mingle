require 'rubygems'
require 'active_support'
require 'active_resource'

# Ruby lib for working with the Mingle API's XML interface.
# You should set the authentication using your login
# credentials with HTTP Basic Authentication.

# This library is a small wrapper around the REST interface

module MingleAPI
  class Error < StandardError; end
  class << self

    #Sets up basic authentication credentials for all the resources.
    def authenticate(auth)
      @server    = auth.server
      @username  = auth.username
      @password  = auth.password
      self::Base.user = auth.username
      self::Base.password = auth.password

      protocol = auth.ssl ? "https" : "http"
      resources.each do |klass|
        klass.site = klass.site_format % "#{protocol}://#{auth.username}:#{auth.password}@#{auth.server}/api/v2"
      end
    end

    def resources
      @resources ||= []
    end
  end

  class Base < ActiveResource::Base
    def self.inherited(base)
      MingleAPI.resources << base
      class << base
        attr_accessor :site_format
      end  
      base.site_format = '%s'
      super
    end
  end

  # Find projects
  #
  #   MingleAPI::Project.find(:all) # find all projects for the current account.
  #   MingleAPI::Project.find('my_project')   # find individual project by ID
  #
  # Creating a Project
  #
  #   project = MingleAPI::Project.new(:name => 'Ninja Whammy Jammy')
  #   project.save
  #   # => true
  #
  #
  # Updating a Project
  #
  #   project = MingleAPI::Project.find('my_project')
  #   project.name = "A new name"
  #   project.save
  #
  # Finding tickets
  # 
  #   project = MingleAPI::Project.find('my_project')
  #   project.tickets
  #


  class Project < Base

    #begin monkey patches

    def exists?(id, options = {})
      begin
        self.class.find(id)
        true
      rescue ActiveResource::ResourceNotFound, ActiveResource::ResourceGone
        false
      end
    end
    
    def new?
      !self.exists?(id)
    end

    def element_path(options = nil)
       self.class.element_path(self.id, options)
    end

    def encode(options={})
       val = []
       attributes.each_pair do |key, value|
         val << "project[#{URI.escape key}]=#{URI.escape value}" rescue nil
       end  
       val.join('&')
    end
   
    def create
        connection.post(collection_path + '?' + encode, nil, self.class.headers).tap do |response|
          self.id = id_from_response(response)
          load_attributes_from_response(response)
        end
    end

    #end monkey patches
 
    def tickets(options = {})
      Card.find(:all, :params => options.update(:identifier => id))
    end
    
    def id
      @attributes['identifier']
    end

  end

  # Find tickets
  #
  #  MingleAPI::Ticket.find(:all, :params => { :identifier => 'my_project' })
  #
  #  project = UnfuddleAPI::Project.find('my_project')
  #  project.tickets
  #  project.tickets(:name => 'a new name')
  #


  class Card < Base
    self.site_format << '/projects/:identifier/'

    #begin monkey patches

    def element_path(options = nil)
      self.class.element_path(self.number, options)
    end

    def encode(options={})
      val = []
      attributes.each_pair do |key, value|
        unless value.nil?
          case key 
          when 'card_type'
            if value.is_a? Hash
              name = value[:name]
            else
              name = value.name
            end
            val << "card[card_type_name]=#{URI.escape name}"
          when 'properties' 
            value.each {|property| 
              val << "card[properties][][name]=#{URI.escape property[0]}
                      &card[properties][][value]=#{URI.escape property[1]}"} rescue NoMethodError
          else
            val << "card[#{URI.escape key.to_s}]=#{URI.escape value.to_s}" rescue nil
          end
        end
      end
      val.join('&')
    end

    def update
      connection.put(element_path(prefix_options) + '?' + encode, nil, self.class.headers).tap do |response|
        load_attributes_from_response(response)
      end
    end

    def create
      connection.post(collection_path + '?' + encode, nil, self.class.headers).tap do |response|
        self.number = id_from_response(response)
        load_attributes_from_response(response)
      end
    end

    #end monkey patches

    def number
      @attributes['number']
    end

    def id
      @attributes['id']
    end

    def name
      @attributes['name']
    end

    def created_on
      @attributes['created_on']
    end

    def modified_on
      @attributes['modified_on']
    end

    def description
      @attributes['description']
    end

    def card_type
      @attributes['card_type']
    end

    def properties
      @attributes['properties']
    end

  end

  class Comment < Base
    self.site_format << '/projects/:identifier/cards/:number'

    def create
      connection.post(collection_path + '?' + encode, nil, self.class.headers).tap do |response|
        load_attributes_from_response(response)
      end
    end

    def encode(options={})
      val=[]
      attributes.each_pair do |key, value|
        val << "comment[#{URI.escape key}]=#{URI.escape value}" rescue nil
      end
      val.join('&')
    end

  end

end
