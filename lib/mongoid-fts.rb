module Mongoid
  module FTS
  #
    const_set(:Version, '0.0.1') unless const_defined?(:Version)

    class << FTS
      def version
        const_get :Version
      end

      def dependencies
        {
          'mongoid'       => [ 'mongoid'       , '~> 3.1' ] ,
          'map'           => [ 'map'           , '~> 6.5' ] ,
          'coerce'        => [ 'coerce'        , '~> 0.0' ] ,
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

    begin
      require 'rubygems'
    rescue LoadError
      nil
    end

    if defined?(gem)
      dependencies.each do |lib, dependency|
        gem(*dependency)
        require(lib)
      end
    end

    begin
      require 'pry'
    rescue LoadError
      nil
    end


  #
    def FTS.search(*args)
      options = Map.options_for(args)

      _searches = FTS._search(*args)

      Results.new(_searches)
    end

    def FTS._search(*args)
      options = Map.options_for!(args)

      search = args.join(' ')

      text   = options.delete(:text) || Index.default_collection_name.to_s
      limit  = [Integer(options.delete(:limit) || 128), 1].max
      models = [options.delete(:models), options.delete(:model)].flatten.compact

      models = FTS.models if models.empty?

      _searches =
        models.map do |model|
          context_type = model.name.to_s
          
          cmd = Hash.new

          cmd[:text] ||= text

          cmd[:limit] ||= limit

          (cmd[:search] ||= '') << search

          cmd[:project] ||= {'_id' => 1, 'context_type' => 1, 'context_id' => 1}

          cmd[:filter] ||= {'context_type' => context_type}

          options.each do |key, value|
            cmd[key] = value
          end

          Map.for(session.command(cmd)).tap do |_search|
            _search[:_model] = model
            _search[:_cmd] = cmd
          end
        end

      Raw.new(_searches, :_search => search, :_text => text, :_limit => limit, :_models => models)
    end

  #
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

  #
    class Results < ::Array
      attr_accessor :_searches
      attr_accessor :_models

      def initialize(_searches)
        @_searches = _searches
        @_models = []
        _denormalize!
        @page = 1
        @per = size
      end

      def paginate(*args)
        options = Map.options_for!(args)

        page = Integer(args.shift || options[:page] || @page)
        per = Integer(args.shift || options[:per] || options[:size] || @per)

        @page = [page.abs, 1].max
        @per = [per.abs, 1].max

        offset = (@page - 1) * @per
        length = @per 

        slice = Array(@_models[offset, length])

        replace(slice)

        self
      end

      def page(*args)
        if args.empty?
          return @page
        else
          options = Map.options_for!(args)
          page = args.shift || options[:page]
          options[:page] = page
          paginate(options)
        end
      end

      def per(*args)
        if args.empty?
          return @per
        else
          options = Map.options_for!(args)
          per = args.shift || options[:per]
          options[:per] = per
          paginate(options)
        end
      end

      def num_pages
        (size.to_f / per).ceil
      end

      def total_pages
        num_pages
      end

  # TODO - text sorting more...
  #
      def _denormalize!
      #
        collection = self

        collection.clear
        @_models = []

        return self if @_searches.empty?

      #
        _models = @_searches._models

        _position = proc do |model|
          _models.index(model) or raise("no position for #{ model.inspect }!?")
        end

        results =
          @_searches.map do |_search|
            _search['results'] ||= []

            _search['results'].each do |result|
              result['_model'] = _search._model
              result['_position'] = _position[_search._model]
            end

            _search['results']
          end

        results.flatten!
        results.compact!

        results.sort! do |a, b|
          score = Float(b['score']) <=> Float(a['score'])

          case score
            when 0
              a['_position'] <=> b['_position']
            else
              score
          end
        end

      #
        batches = Hash.new{|h,k| h[k] = []}

        results.each do |entry|
          obj = entry['obj']

          context_type, context_id = obj['context_type'], obj['context_id']

          batches[context_type].push(context_id)
        end

      #
        models = FTS.find_in_batches(batches)

      #
        limit = @_searches._limit

      #
        replace(@_models = models[0 ... limit])

        self
      end
    end

  #
    class Index
      include Mongoid::Document

      belongs_to(:context, :polymorphic => true)

      field(:title, :type => String)
      field(:keywords, :type => Array)
      field(:fulltext, :type => String)

      index(
        {:context_type => 1, :title => 'text', :keywords => 'text', :fulltext => 'text'},
        {:weights => { :title => 100, :keywords => 50, :fulltext => 1 }, :name => 'search_index'}
      )

      index(
        {:context_type => 1, :context_id => 1},
        {:unique => true, :sparse => true}
      )

      before_validation do |index|
        index.normalize
      end

      before_upsert do |index|
        index.normalize
      end

      validates_presence_of(:context_type)

      def normalize
        if !defined?(@normalized) or !@normalized
          normalize!
        end
      end

      def normalize!
        index = self

        unless [index.keywords].join.strip.empty?
          index.keywords = FTS.list_of_strings(index.keywords)
        end

        unless [index.title].join.strip.empty?
          index.title = index.title.to_s.strip
        end

        unless [index.keywords].join.strip.empty?
          index.keywords = index.keywords.map{|keyword| keyword.strip}
        end

        unless [index.fulltext].join.strip.empty?
          index.fulltext = index.fulltext.to_s.strip
        end

      ensure
        @normalized = true
      end

      def Index.teardown!
        Index.remove_indexes
        Index.destroy_all
      end

      def Index.setup!
        Index.create_indexes
      end

      def Index.reset!
        teardown!
        setup!
      end

      def Index.rebuild!
        batches = Hash.new{|h,k| h[k] = []}

        each do |index|
          context_type, context_id = index.context_type, index.context_id
          next unless context_type && context_id
          (batches[context_type] ||= []).push(context_id)
        end

        models = FTS.find_in_batches(batches)

        reset!

        models.each{|model| add(model)}
      end

      def Index.add(model)
        to_search = Index.to_search(model)

        title    = to_search.has_key?(:title) ?  Coerce.string(to_search[:title]) : nil
        keywords = to_search.has_key?(:keywords) ?  Coerce.list_of_strings(to_search[:keywords]) : nil
        fulltext = to_search.has_key?(:fulltext) ?  Coerce.string(to_search[:fulltext]) : nil

        context_type = model.class.name.to_s
        context_id   = model.id

        conditions = {
          :context_type => context_type,
          :context_id   => context_id
        }

        attributes = {
          :title        => title,
          :keywords     => keywords,
          :fulltext     => fulltext
        }

        new(conditions).upsert

        where(conditions).first.tap do |index|
          if index
            index.update_attributes(attributes)
          end
        end
      end

      def Index.remove(model)
        context_type = model.class.name.to_s
        context_id = model.id

        conditions = {
          :context_type => context_type,
          :context_id   => context_id
        }

        where(conditions).first.tap do |index|
          if index
            index.destroy rescue nil
          end
        end
      end

      def Index.to_search(model)
        to_search = nil

        if model.respond_to?(:to_search)
          to_search = Map.for(model.to_search)
        else
          to_search = Map.new

          to_search[:title] =
            %w( title ).map do |attr|
              model.send(attr) if model.respond_to?(attr)
            end.compact.join(' ')

          to_search[:keywords] =
            %w( keywords tags ).map do |attr|
              model.send(attr) if model.respond_to?(attr)
            end.compact

          to_search[:fulltext] =
            %w( fulltext text content body description ).map do |attr|
              model.send(attr) if model.respond_to?(attr)
            end.compact.join(' ')
        end

        unless %w( title keywords fulltext ).detect{|key| to_search.has_key?(key)}
          raise ArgumentError, "you need to define #{ model }#to_search"
        end

        to_search
      end
    end

    def FTS.index
      Index
    end

  #
    module Mixin
      def Mixin.code
        @code ||= proc do
          class << self
            def search(*args, &block)
              options = Map.options_for(args)

              options[:model] = self

              FTS.search(*args, &block)
            end

            def _search(*args, &block)
              options = Map.options_for(args)

              options[:model] = self

              FTS.search(*args, &block)
            end
          end

          after_save do |model|
            FTS::Index.add(model) rescue nil
          end

          after_destroy do |model|
            FTS::Index.remove(model) rescue nil
          end
        end
      end

      def Mixin.included(other)
        unless other.is_a?(Mixin)
          begin
            super
          ensure
            other.module_eval(&Mixin.code)
            FTS.models.push(other)
            FTS.models.uniq!
          end
        end
      end
    end

    def FTS.included(other)
      unless other.is_a?(FTS::Mixin)
        other.send(:include, FTS::Mixin)
      end
    end

  #
    def FTS.models
      @models ||= []
    end

    def FTS.list_of_strings(*args)
      args.flatten.compact.map{|arg| arg.to_s}.select{|arg| !arg.empty?}.uniq
    end

    def FTS.session
      @session ||= Mongoid::Sessions.default
    end

    def FTS.session=(session)
      @session = session
    end

    def FTS.find_in_batches(queries = {})
      models =
        queries.map do |model_class, model_ids|
          unless model_class.is_a?(Class)
            model_class = eval(model_class.to_s)
          end

          model_ids = Array(model_ids)

          begin
            model_class.find(model_ids)
          rescue Mongoid::Errors::DocumentNotFound
            model_ids.map do |model_id|
              begin
                model_class.find(model_id)
              rescue Mongoid::Errors::DocumentNotFound
                nil
              end
            end
          end
        end

      models.flatten!
      models.compact!
      models
    end

    def FTS.enable!(*args)
      options = Map.options_for!(args)

      unless options.has_key?(:warn)
        options[:warn] = true
      end

      begin
        session = Mongoid::Sessions.default
        session.with(database: :admin).command({ setParameter: 1, textFTSEnabled: true })
      rescue Object => e
        unless e.is_a?(Mongoid::Errors::NoSessionsConfig)
          warn "failed to enable search with #{ e.class }(#{ e.message })"
        end
      end
    end
  end

  Fts = FTS

  if defined?(Rails)
    class FTS::Engine < ::Rails::Engine
      paths['app/models'] = ::File.dirname(__FILE__)
    end

    Rails.configuration.after_initialize do
      Mongoid::FTS.enable!(:warn => true)
    end
  else
    Mongoid::FTS.enable!(:warn => true)
  end
end


=begin

  Model.mongo_session.command(text: "collection_name", search: "my search string", filter: { ... }, project: { ... }, limit: 10, language: "english")

  http://blog.serverdensity.com/full-text-search-in-mongodb/

  http://blog.mongohq.com/mongodb-and-full-text-search-my-first-week-with-mongodb-2-4-development-release/

  http://docs.mongodb.org/manual/single/index.html#document-tutorial/enable-text-search

=end
