module Mongoid
  module FTS
    class Engine < ::Rails::Engine
      paths['app/models'] = ::File.dirname(__FILE__)

      config.before_initialize do
        Mongoid::FTS.enable!(:warn => true)
      end
    end
  end
end
