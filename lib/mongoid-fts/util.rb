module Mongoid
  module FTS
    module Util 
    #
      def fts_models
        [
          Mongoid::FTS::Index
        ]
      end

      def reset!
        Mongoid::FTS.setup!(:warn => true)

        fts_models.each do |model|
          model.destroy_all

          begin
            model.collection.indexes.drop
          rescue Object => e
          end

          begin
            model.collection.drop
          rescue Object => e
          end

          begin
            model.create_indexes
          rescue Object => e
          end
        end
      end

      def create_indexes
        fts_models.each{|model| model.create_indexes}
      end

      def destroy_all
        fts_models.map{|model| model.destroy_all}
      end

    #
      def find_in_batches(queries = {})
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

      def find_or_create(finder, creator)
        doc = finder.call()
        return doc if doc

        n, max = 0, 2

        begin
          creator.call()
        rescue Object => e
          n += 1
          raise if n > max
          sleep(rand(0.1))
          finder.call() or retry
        end
      end

    #
      def terms_for(*args, &block)
        options = Map.options_for!(args)

        words = words_for(*args)

        list = options[:list] || []

        words.each do |word|
          word = word.downcase
          next if stopword?(word)

          stems = stems_for(word)

          stems.each do |stem|
            [stem, unidecode(stem)].uniq.each do |stem|
              next if stopword?(stem)

              block ? block.call(stem) : list.push(stem)

              substems = stem.split(/_/)

              if options[:subterms] and substems.size > 1
                substems.each do |substem|
                  terms_for(substem.gsub(/_+/, '-'), :list => list)
                end
              end
            end
          end
        end

        list.uniq!

        block ? nil : list
      end

      def words_for(*args, &block)
        options = Map.options_for!(args)

        string = args.join(' ')

        list = []

        UnicodeUtils.each_word(string) do |word|
          word = strip(utf8ify(word))

          next if word.empty?

          block ? block.call(word) : list.push(word)
        end

        block ? nil : list
      end

      def stems_for(*args, &block)
        options = Map.options_for!(args)

        words = Coerce.list_of_strings(*args).map{|word| utf8ify(word)}

        Stemming.stem(*words)
      end

      def literals_for(*args)
        words = FTS.normalized_array(args)

        return words.map{|word| "__#{ Digest::MD5.hexdigest(word) }__"}
      end

      def stopword?(word)
        word = utf8ify(word)
        word.empty? or Stemming::Stopwords.stopword?(word)
      end

      def strip(word)
        word = utf8ify(word)
        word.gsub!(/\A(?:[^\w]|_|\s)+/, '')  # leading punctuation/spaces
        word.gsub!(/(?:[^\w]|_|\s+)+\Z/, '') # trailing punctuation/spaces
        word
      end

      def fuzzy(*args)
        strings = Coerce.list_of_strings(args).map{|string| utf8ify(string)}

        list = []

        strings.each do |string|
          list.push(*ngrams_for(string))

          decoded = unidecode(string)

          unless decoded == string
            list.push(*ngrams_for(decoded))
          end
        end

        list.uniq
      end
      alias_method(:fuzzy_for, :fuzzy)

      def ngrams_for(*args)
        options = Map.options_for!(args)

        strings = Coerce.list_of_strings(args).map{|string| utf8ify(string)}

        list = []

        sizes = options[:sizes] || [2,3]

        strings.each do |string|
          chars = Util.chars('_' + string + '_')

          sizes.each do |size|
            (chars.size - (size - 1)).times do |i|
              ngram = chars[i, size].join
              list.push(ngram)
            end
          end

        end

        list
      end

      def chars(string)
        chars = []
        UnicodeUtils.each_grapheme(string.to_s){|g| chars.push(g)}
        chars
      end

      def unidecode(string)
        Stringex::Unidecoder.decode(utf8ify(string.to_s))
      end

      def utf8ify(string)
        UnicodeUtils.nfkd(
          begin
            string.force_encoding('UTF-8')
          rescue
            string.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
          end
        )
      end

      def normalized_array(*array)
        array.flatten.map{|_| _.to_s.strip}.select{|_| !_.empty?}.uniq
      end

      def list_of_strings(*args)
        args.flatten.compact.map{|arg| arg.to_s}.select{|arg| !arg.empty?}.uniq
      end

    #
      def index(*args, &block)
        if args.empty? and block.nil?
          Index
        else
          args.each do |arg|
            case arg
              when Class
                arg.all.each{|model| Index.add(model)}
              else
                Index.add(arg, &block)
            end
          end
        end
      end

      def unindex(*args, &block)
        Index.remove(*args, &block)
      end

      def index!(*args, &block)
        Index.add!(*args, &block)
      end

      def unindex!(*args, &block)
        Index.remove!(*args, &block)
      end

    #
      def models
        @models ||= []
      end

    #
      def session
        @session ||= Mongoid::Sessions.default
      end

      def session=(session)
        @session = session
      end

      def enable!(*args)
        options = Map.options_for!(args)

        unless options.has_key?(:warn)
          options[:warn] = true
        end

        begin
          session = Mongoid::Sessions.default
          session.with(database: :admin).command({ setParameter: 1, textSearchEnabled: true })
        rescue Object => e
          unless e.is_a?(Mongoid::Errors::NoSessionsConfig)
            warn "failed to enable search with #{ e.class }(#{ e.message })"
          end
        end
      end

      def setup!(*args)
        enable!(*args)
        Index.setup!
      end

      def connect!
        Mongoid.configure do |config|
          config.connect_to('mongoid-fts')
        end
      end

      def boolean_and(*strings)
        strings = Coerce.list_of_strings(*strings)
        strings.map{|s| '"%s"' % s.gsub('"', '')}.join(' ')
      end

      def boolean_or(*strings)
        strings = Coerce.list_of_strings(*strings)
        strings.join(' ')
      end

      extend Util
    end

    extend Util
  end
end
