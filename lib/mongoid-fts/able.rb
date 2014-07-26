module Mongoid
  module FTS
    module Able
      def Able.code
        @code ||= proc do
          class << self
            def fts_search(*args, &block)
              options = Map.options_for!(args)

              options[:model] = self

              args.push(options)

              FTS.search(*args, &block)
            end
            alias :search :fts_search

            def _fts_search(*args, &block)
              options = Map.options_for!(args)

              options[:model] = self

              args.push(options)

              FTS.search(*args, &block)
            end
            alias :_search :_fts_search
          end

          after_save do |model|
            FTS::Index.add(model)
          end

          after_destroy do |model|
            FTS::Index.remove(model) rescue nil
          end

          has_one(:fts_index, :as => :context, :class_name => '::Mongoid::FTS::Index')
        end
      end

      def Able.included(other)
        unless other.is_a?(Able)
          begin
            super
          ensure
            other.module_eval(&Able.code)

            FTS.models.dup.each do |model|
              FTS.models.delete(model) if model.name == other.name
            end

            FTS.models.push(other)
            FTS.models.uniq!
          end
        end
      end
    end

    def FTS.included(other)
      other.send(:include, FTS::Able)
    end

    def FTS.able
      Able
    end
  end
end
