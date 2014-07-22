module Mongoid
  module FTS
    module Util 
      def models
        [
          Mongoid::FTS::Index
        ]
      end

      def reset!
        Mongoid::FTS.setup!(:warn => true)

        models.each do |model|
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
        models.each{|model| model.create_indexes}
      end

      def destroy_all
        models.map{|model| model.destroy_all}
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

      def connect!
        Mongoid.configure do |config|
          config.connect_to('mongoid-fts')
        end
      end

      def utf8ify(string)
        string.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      end

      def terms_for(*args, &block)
        options = Map.options_for!(args)

        words = words_for(*args)

        list = []

        words.each do |word|
          next if stopword?(word)
          stems = stems_for(word)

          stems.each do |stem|
            next if stopword?(stem)

            block ? block.call(stem) : list.push(stem)

            substems = stem.split(/_/)

            if options[:subterms] and substems.size > 1
              substems.each do |substem|
                subterms = terms_for(substem.gsub(/_+/, '-'))

                subterms.each do |subterm|
                  block ? block.call(subterm) : list.push(subterm)
                end
              end
            end
          end
        end

        block ? nil : list
      end

      def words_for(*args, &block)
        options = Map.options_for!(args)

        string = args.join(' ')
        #string.gsub!(/_+/, '-')
        #string.gsub!(/[^\w]/, ' ')

        list = []

        UnicodeUtils.each_word(string) do |word|
          word = utf8ify(word)

          strip!(word)

          next if word.empty?

          block ? block.call(word) : list.push(word)

=begin
          if word =~ /_/
            words = words_for(word.gsub(/_+/, '-'))
            words.each do |word|
              block ? block.call(word) : list.push(word)
            end
          end
=end
        end

        block ? nil : list
      end

      def stems_for(*args, &block)
        options = Map.options_for!(args)

        words = Coerce.list_of_strings(*args)

        words.map! do |word|
          word = utf8ify(word)
        end

        Stemming.stem(*words)
      end

      def stopword?(word)
        word = utf8ify(word)
        word = UnicodeUtils.nfkd(word.to_s.strip.downcase)
        word.empty? or Stemming::Stopwords.stopword?(word)
      end

      def strip!(word)
        word = utf8ify(word)
        word.replace(UnicodeUtils.nfkd(word.to_s.strip))
        word.gsub!(/\A(?:[^\w]|_|\s)+/, '')  # leading punctuation/spaces
        word.gsub!(/(?:[^\w]|_|\s+)+\Z/, '') # trailing punctuation/spaces
        word
      end

      extend Util
    end

    extend Util
  end
end
