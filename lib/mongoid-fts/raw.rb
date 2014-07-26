module Mongoid
  module FTS
    class Raw < ::Array
      attr_accessor :_search
      attr_accessor :_text
      attr_accessor :_limit
      attr_accessor :_models

      def initialize(_searches, options = {})
        replace(_searches)
      ensure
        options.each{|k, v| send("#{ k }=", v)}
      end
    end
  end
end
