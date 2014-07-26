module Mongoid
  module FTS
  #
    const_set(:Version, '2.0.0') unless const_defined?(:Version)

  #
    class << FTS
      def version
        const_get(:Version)
      end

      def dependencies
        {
          'mongoid'       => [ 'mongoid'       , '~> 3.1' ] ,
          'map'           => [ 'map'           , '~> 6.5' ] ,
          'coerce'        => [ 'coerce'        , '~> 0.0' ] ,
          'unicode_utils' => [ 'unicode_utils' , '~> 1.4' ] ,
          'stringex'      => [ 'stringex'      , '~> 2.0' ] ,
          'fast_stemmer'  => [ 'fast-stemmer'  , '~> 1.0' ] ,
        }
      end

      def libdir(*args, &block)
        @libdir ||= File.expand_path(__FILE__).sub(/\.rb$/,'')
        args.empty? ? @libdir : File.join(@libdir, *args)
      ensure
        if block
          begin
            $LOAD_PATH.unshift(@libdir)
            block.call()
          ensure
            $LOAD_PATH.shift()
          end
        end
      end

      def load(*libs)
        libs = libs.join(' ').scan(/[^\s+]+/)
        libdir{ libs.each{|lib| Kernel.load(lib) } }
      end
    end

  #
    require 'digest/md5'

    begin
      require 'rubygems'
    rescue LoadError
      nil
    end

    if defined?(gem)
      dependencies.each do |lib, dependency|
        #gem(*dependency)
        require(lib)
      end
    end

    begin
      require 'pry'
    rescue LoadError
      nil
    end

  #
    require 'unicode_utils/u'
    require 'unicode_utils/each_word'
    require 'unicode_utils/each_grapheme'

  #
    load FTS.libdir('error.rb')
    load FTS.libdir('util.rb')
    load FTS.libdir('stemming.rb')
    load FTS.libdir('raw.rb')
    load FTS.libdir('results.rb')
    load FTS.libdir('index.rb')
    load FTS.libdir('able.rb')

  #
    def FTS.search(*args)
      options = Map.options_for(args)

      _searches = FTS._search(*args)

      Results.new(_searches)
    end

    def FTS._search(*args)
    #
      options = Map.options_for!(args)

    #
      literals = Coerce.list_of_strings(options[:literals], options[:literal])

      terms = Coerce.list_of_strings(options[:terms], options[:searches], options[:term], options[:search], args)

      fuzzy = Coerce.list_of_strings(options[:fuzzy])

    #
      operator =
        case
          when options[:all] || options[:operator].to_s == 'and'
            if options[:all] != true
              terms.push(*Coerce.list_of_strings(options[:all]))
            end
            :and

          when options[:any] || options[:operator].to_s == 'or'
            if options[:any] != true
              terms.push(*Coerce.list_of_strings(options[:any]))
            end
            :or

          else
            :and
        end

    #
      if fuzzy.empty?
        fuzzy = terms 
      end

    #
      searches = []

    #
      strings =
        [
          FTS.literals_for(literals),
          FTS.terms_for(terms)
        ].uniq

      search =
        case operator
          when :and
            FTS.boolean_and(strings)
          when :or
            FTS.boolean_or(strings)
        end

      searches.push(search)

    #
      search = FTS.boolean_or(FTS.fuzzy_for(fuzzy))
      searches.push(search)

    #
      text   = options.delete(:text) || Index.default_collection_name.to_s
      limit  = [Integer(options.delete(:limit) || 128), 1].max
      models = [options.delete(:models), options.delete(:model)].flatten.compact

    #
      models = FTS.models if models.empty?

    #
      last = searches.size - 1

      searches.each_with_index do |search, i|
        _searches =
          if search.strip.empty?
            []
          else
            models.map do |model|
              context_type = model.name.to_s
              
              cmd = Hash.new

              cmd[:text] ||= text

              cmd[:limit] ||= limit

              (cmd[:search] ||= '') << search

              cmd[:project] ||= {'_id' => 1, 'context_type' => 1, 'context_id' => 1}

              cmd[:filter] ||= {'context_type' => context_type}

              Map.for(session.command(cmd)).tap do |_search|
                _search[:_model] = model
                _search[:_cmd] = cmd
              end
            end
          end

        raw = Raw.new(_searches, :_search => search, :_text => text, :_limit => limit, :_models => models)
        return raw if(i == last || !raw.empty?)
      end
    end

    def FTS.included(other)
      other.send(:include, Able)
      super
    end
  end

  Fts = FTS

  if defined?(Rails)
    load FTS.libdir('rails.rb')
  else
    Mongoid::FTS.enable!(:warn => true)
  end
end


=begin

  http://docs.mongodb.org/manual/reference/operator/query/text/

  http://docs.mongodb.org/v2.4/reference/command/text/

  Model.mongo_session.command(text: "collection_name", search: "my search string", filter: { ... }, project: { ... }, limit: 10, language: "english")

  http://blog.serverdensity.com/full-text-search-in-mongodb/

  http://blog.mongohq.com/mongodb-and-full-text-search-my-first-week-with-mongodb-2-4-development-release/

  http://docs.mongodb.org/manual/single/index.html#document-tutorial/enable-text-search

=end
