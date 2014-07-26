module Mongoid
  module FTS
    class Index
    #
      include Mongoid::Document

    #
      belongs_to(:context, :polymorphic => true)

    #
      field(:literals, :type => Array)

      field(:title, :type => Array)

      field(:keywords, :type => Array)

      field(:fuzzy, :type => Array)

      field(:fulltext, :type => Array)

    #
      index(
        {
          :context_type => 1,
          :context_id   => 1
        },

        {
          :unique => true,
          :sparse => true
        }
      )

    # FIXME - this hack gets around https://github.com/mongoid/mongoid/issues/3080
    #
      index_options[

        normalize_spec(
          :context_type     => 1,

          :literals         => 'text',

          :title            => 'text',

          :keywords         => 'text',

          :fuzzy            => 'text',

          :fulltext         => 'text'
        )

      ] = 

        normalize_index_options(
          :name => 'search_index',

          :default_language => 'none',

          :weights => {
            :literals         => 200,

            :title            => 90,

            :keywords         => 50,

            :fulltext         => 1
          }
        )
    #
    #

      before_validation do |index|
        index.normalize
      end

      before_upsert do |index|
        index.normalize
      end

      before_save do |index|
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

        %w( literals title keywords fulltext ).each do |attr|
          index[attr] = FTS.list_of_strings(index[attr])
        end
      ensure
        @normalized = true
      end

      def inspect(*args, &block)
        Map.for(as_document).inspect(*args, &block)
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

      def Index.add!(model)
        to_search = Index.to_search(model)

        literals         = to_search.has_key?(:literals) ?  Coerce.list_of_strings(to_search[:literals]) : nil

        title            = to_search.has_key?(:title) ?  Coerce.string(to_search[:title]) : nil

        keywords         = to_search.has_key?(:keywords) ?  Coerce.list_of_strings(to_search[:keywords]) : nil

        fuzzy            = to_search.has_key?(:fuzzy) ?  Coerce.list_of_strings(to_search[:fuzzy]) : nil

        fulltext         = to_search.has_key?(:fulltext) ?  Coerce.string(to_search[:fulltext]) : nil

        context_type = model.class.name.to_s
        context_id   = model.id

        conditions = {
          :context_type => context_type,
          :context_id   => context_id
        }

        attributes = {
          :literals         => literals,
          :title            => title,
          :keywords         => keywords,
          :fuzzy            => fuzzy,
          :fulltext         => fulltext
        }

        index = nil
        n = 42

        n.times do |i|
          index = where(conditions).first
          break if index

          begin
            index = create!(conditions)
            break if index
          rescue Object
            nil
          end

          sleep(rand) if i < (n - 1)
        end

        if index
          begin
            index.update_attributes!(attributes)
          rescue Object
            raise Error.new("failed to update index for #{ conditions.inspect }")
          end
        else
          raise Error.new("failed to create index for #{ conditions.inspect }")
        end

        index
      end

      def Index.add(*args, &block)
        add!(*args, &block)
      end

      def Index.remove!(*args, &block)
        options = args.extract_options!.to_options!
        models = args.flatten.compact

        model_ids = {}

        models.each do |model|
          model_name = model.class.name.to_s
          model_ids[model_name] ||= []
          model_ids[model_name].push(model.id)
        end

        conditions = model_ids.map do |model_name, model_ids|
          {:context_type => model_name, :context_id.in => model_ids}
        end

        any_of(conditions).destroy_all
      end

      def Index.remove(*args, &block)
        remove!(*args, &block)
      end

      def Index.to_search(model)
      #
        to_search = nil

      #
        if model.respond_to?(:to_search)
          to_search = Map.for(model.to_search)
        else
          to_search = Map.new

          to_search[:literals] =
            %w( id ).map do |attr|
              model.send(attr) if model.respond_to?(attr)
            end

          to_search[:title] =
            %w( title ).map do |attr|
              model.send(attr) if model.respond_to?(attr)
            end

          to_search[:keywords] =
            %w( keywords tags ).map do |attr|
              model.send(attr) if model.respond_to?(attr)
            end

          to_search[:fulltext] =
            %w( fulltext text content body description ).map do |attr|
              model.send(attr) if model.respond_to?(attr)
            end
        end

      #
        required = %w( literals title keywords fuzzy fulltext )
        actual = to_search.keys

=begin
        missing = required - actual
        unless missing.empty?
          raise ArgumentError, "#{ model.class.inspect }#to_search missing keys #{ missing.inspect }"
        end
=end

        invalid = actual - required
        unless invalid.empty?
          raise ArgumentError, "#{ model.class.inspect }#to_search invalid keys #{ invalid.inspect }"
        end

      #
        literals = FTS.normalized_array(to_search[:literals])
        title    = FTS.normalized_array(to_search[:title])
        keywords = FTS.normalized_array(to_search[:keywords])
        fuzzy    = FTS.normalized_array(to_search[:fuzzy])
        fulltext = FTS.normalized_array(to_search[:fulltext])

      #
        if to_search[:fuzzy].nil?
          fuzzy = [title, keywords]
        end

      #
        to_search[:literals]         = FTS.literals_for(literals).uniq
        to_search[:title]            = (title + FTS.terms_for(title)).uniq
        to_search[:keywords]         = (keywords + FTS.terms_for(keywords)).uniq
        to_search[:fuzzy]            = FTS.fuzzy_for(fuzzy).uniq
        to_search[:fulltext]         = (FTS.terms_for(fulltext, :subterms => true)).uniq

      #
        to_search
      end
    end
  end
end
