module Mongoid
  module FTS
    class Results < ::Array
      attr_accessor :_searches
      attr_accessor :_models

      def initialize(_searches)
        @_searches = _searches
        @_models = []
        _denormalize!
        @page = 1
        @per = size
        @num_pages = 1
      end

      def paginate(*args)
        results = self
        options = Map.options_for!(args)

        page = Integer(args.shift || options[:page] || @page)
        per = args.shift || options[:per] || options[:size]

        if per.nil?
          return Promise.new(results, page)
        else
          per = Integer(per)
        end

        @page = [page.abs, 1].max
        @per = [per.abs, 1].max
        @num_pages = (size.to_f / @per).ceil

        offset = (@page - 1) * @per
        length = @per 

        slice = Array(@_models[offset, length])

        replace(slice)

        self
      end

      class Promise
        attr_accessor :results
        attr_accessor :page

        def initialize(results, page)
          @results = results
          @page = page
        end

        def per(per)
          results.per(:page => page, :per => per)
        end
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

      alias_method(:current_page, :page)

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
        @num_pages
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

=begin
        results.sort! do |a, b|
          score = Float(b['score']) <=> Float(a['score'])

          case score
            when 0
              a['_position'] <=> b['_position']
            else
              score
          end
        end
=end

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
        result_index = {}

        results.each do |result|
          context_type = result['obj']['context_type'].to_s
          context_id = result['obj']['context_id'].to_s
          key = [context_type, context_id]

          result_index[key] = result
        end

      #
        models.each do |model|
          context_type = model.class.name.to_s
          context_id = model.id.to_s
          key = [context_type, context_id]

          result = result_index[key]
          model['_fts_index'] = result
        end

      #
        models.sort! do |model_a, model_b|
          a = model_a['_fts_index']
          b = model_b['_fts_index']

          score = Float(b['score']) <=> Float(a['score'])

          case score
            when 0
              a['_position'] <=> b['_position']
            else
              score
          end
        end

      #
        limit = @_searches._limit

      #
        replace(@_models = models[0 ... limit])

        self
      end
    end
  end
end
