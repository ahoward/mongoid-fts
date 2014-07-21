require_relative 'helper'

Testing Mongoid::FTS do
#
  testing 'wording' do
    assert{ Mongoid::FTS.words_for('dogs cats fishes') == %w[ dogs cats fishes ] }
    assert{ Mongoid::FTS.words_for('foo-bar baz_bub') == %w[ foo bar baz_bub baz bub ] }
  end

#
  testing 'stemming' do
    assert{ Mongoid::FTS.stems_for('dogs cats fishes') == %w[ dog cat fish ] }
  end

#
  testing 'terming' do
    assert{ Mongoid::FTS.terms_for('dogs and the cats and those fishes') == %w[ dog cat fish ] }
    assert{ Mongoid::FTS.terms_for('the foo-bar and then baz_bub') == %w[ foo bar baz_bub baz bub ] }
  end

=begin
##
#
  testing 'that models can, at minimum, be indexed and searched' do
    a = A.create!(:content => 'dog')
    b = B.create!(:content => 'cat')

    assert{ Mongoid::FTS.index(a) }
    assert{ Mongoid::FTS.index(b) }

    assert{ Mongoid::FTS.search('dog').map(&:model) == [a] }
    assert{ Mongoid::FTS.search('cat').map(&:model) == [b] }
  end

##
#
  testing 'that results are returned as chainable Mongoid::Criteria' do
     k = new_klass

     3.times{ k.create! :content => 'cats' }

     results = assert{ Mongoid::FTS.search('cat') }
     assert{ results.is_a?(Mongoid::Criteria) }
  end

##
#
  testing 'that word occurance affects the sort' do
    a = A.create!(:content => 'dog')
    b = A.create!(:content => 'dog dog')
    c = A.create!(:content => 'dog dog dog')
    
    assert{ Mongoid::FTS.index(A) }
    assert{ Mongoid::FTS.search('dog').map(&:model) == [c, b, a] }
  end

##
#
  testing 'that rare words float to the front of the results' do
    a = A.create!(:content => 'dog')
    b = A.create!(:content => 'dog dog')
    c = A.create!(:content => 'dog dog dog')
    d = A.create!(:content => 'dog dog dog cat')
    
    assert{ Mongoid::FTS.index(A) }
    Mongoid::FTS.search('cat dog').map(&:model) == [d, c, b, a] 
    assert{ Mongoid::FTS.search('cat dog').map(&:model) == [d, c, b, a] }
  end

##
#
  testing 'that word specificity affects the search' do
    a = A.create!(:content => 'cat@dog.com')
    b = A.create!(:content => 'dogs')
    c = A.create!(:content => 'dog')
    d = A.create!(:content => 'cats')
    e = A.create!(:content => 'cat')

    assert{ Mongoid::FTS.index(A) }

    assert{ Mongoid::FTS.search('cat@dog.com').map(&:model) == [a] }
    assert{ Mongoid::FTS.search('cat').map(&:model) == [e, d, a] }
    assert{ Mongoid::FTS.search('cats').map(&:model) == [d, e, a] }
    assert{ Mongoid::FTS.search('dog').map(&:model) == [c, b, a] }
    assert{ Mongoid::FTS.search('dogs').map(&:model) == [b, c, a] }
    #assert{ Mongoid::FTS.search('dog').map(&:model) == [c, b, a] }
  end

##
#
  testing 'that basic stemming can be performed' do
    assert{ Mongoid::FTS.stems_for('dogs cats fishes') == %w[ dog cat fish ] }
  end

  testing 'that words are stemmed when they are indexed' do
    a = A.create!(:content => 'dog')
    b = A.create!(:content => 'dogs')
    c = A.create!(:content => 'dogen')

    assert{ Mongoid::FTS.index(A) }

    assert{
      results = Mongoid::FTS.search('dog').map(&:model)
      results.include?(a) and results.include?(b) and !results.include?(c)
    }
  end

##
#
  testing 'that counts are kept regarding each seen token' do
    a = A.create!(:content => 'dog')
    b = A.create!(:content => 'dogs')
    c = A.create!(:content => 'cat')

    assert{ Mongoid::FTS.index(A) }


    assert{ Mongoid::FTS::Token.count == 3 }
    assert{ Mongoid::FTS::Token.all.map(&:value).sort == %w( cat dog dogs ) }
    assert{ Mongoid::FTS::Token.total == 4 }
  end

  testing 'that removing a model from the index decrements counts appropriately' do
    2.times do |i|
      A.destroy_all

      a = A.create!(:content => 'dog')
      b = A.create!(:content => 'cat')
      c = A.create!(:content => 'cats dogs')

      remove = proc do |model|
        assert{
          if i == 0
            assert{ Mongoid::FTS.unindex(model) }
          else
            assert{ model.destroy; true }
          end
        }
      end

      assert{ Mongoid::FTS.index(A) }

      %w( cat dog cats dogs ).each do |search|
        assert{ Mongoid::FTS.search(search).first }
      end

      assert{ Mongoid::FTS::Token.where(:value => 'cat').first.count == 2 }
      assert{ Mongoid::FTS::Token.where(:value => 'dog').first.count == 2 }
      assert{ Mongoid::FTS::Token.total == 6 }
      assert{ Mongoid::FTS::Token.all.map(&:value).sort == %w( cat cats dog dogs ) }

      remove[ c ]
      assert{ Mongoid::FTS::Token.all.map(&:value).sort == %w( cat cats dog dogs ) }
      assert{ Mongoid::FTS::Token.total == 2 }
      assert{ Mongoid::FTS::Token.where(:value => 'cat').first.count == 1 }
      assert{ Mongoid::FTS::Token.where(:value => 'dog').first.count == 1 }


      remove[ b ]
      assert{ Mongoid::FTS::Token.all.map(&:value).sort == %w( cat cats dog dogs ) }
      assert{ Mongoid::FTS::Token.total == 1 }
      assert{ Mongoid::FTS::Token.where(:value => 'cat').first.count == 0 }
      assert{ Mongoid::FTS::Token.where(:value => 'dog').first.count == 1 }

      remove[ a ]
      assert{ Mongoid::FTS::Token.all.map(&:value).sort == %w( cat cats dog dogs ) }
      assert{ Mongoid::FTS::Token.total == 0 }
      assert{ Mongoid::FTS::Token.where(:value => 'cat').first.count == 0 }
      assert{ Mongoid::FTS::Token.where(:value => 'dog').first.count == 0 }
    end
  end

##
#
  testing 'that search uses a b-tree index' do
    a = A.create!(:content => 'dog')

    assert{ Mongoid::FTS.index(A) }
    assert{ Mongoid::FTS.search('dog').explain['cursor'] =~ /BtreeCursor/i }
  end

##
#
  testing 'that classes can export a custom [score|keywords|fulltext] for the search index' do
    k = new_klass do
      def to_haystack
        colors.push(color = colors.shift)

        {
          :score => score,

          :keywords => "cats #{ color }",

          :fulltext => 'now is the time for all good men...'
        }
      end

      def self.score
        @score ||= 0
      ensure
        @score += 1
      end

      def self.score=(score)
        @score = score.to_i
      end

      def score
        self.class.score
      end

      def self.colors
        @colors ||= %w( black white )
      end

      def colors
        self.class.colors
      end
    end

    a = k.create!(:content => 'dog')
    b = k.create!(:content => 'dogs too')

    assert{ a.haystack_index.score == 0 }
    assert{ b.haystack_index.score == 1 }

    assert do
      a.haystack_index.tokens.map(&:value).sort ==
        ["black", "cat", "cats", "good", "men", "time"]
    end
    assert do
      b.haystack_index.tokens.map(&:value).sort ==
        ["cat", "cats", "good", "men", "time", "white"]
    end

    assert{ Mongoid::FTS.search('cat').count == 2 }
    assert{ Mongoid::FTS.search('black').count == 1 }
    assert{ Mongoid::FTS.search('white').count == 1 }
    assert{ Mongoid::FTS.search('good men').count == 2 }
  end

##
#
  testing 'that set intersection and union are supported via search' do
    a = A.create!(:content => 'dog')
    b = A.create!(:content => 'dog cat')
    c = A.create!(:content => 'dog cat fish')

    assert{ Mongoid::FTS.index(A) }

    assert{ Mongoid::FTS.search(:any => 'dog').count == 3 }
    assert{ Mongoid::FTS.search(:any => 'dog cat').count == 3 }
    assert{ Mongoid::FTS.search(:any => 'dog cat fish').count == 3 }

    assert{ Mongoid::FTS.search(:all => 'dog').count == 3 }
    assert{ Mongoid::FTS.search(:all => 'dog cat').count == 2 }
    assert{ Mongoid::FTS.search(:all => 'dog cat fish').count == 1 }
  end

##
#
  testing 'that classes can export custom facets and then search them, again using a b-tree index' do
    k = new_klass do
      field(:to_haystack, :type => Hash, :default => proc{ Hash.new })
    end

    a = k.create!(:content => 'hello kitty', :to_haystack => { :keywords => 'cat', :facets => {:x => 42.0}})
    b = k.create!(:content => 'hello kitty', :to_haystack => { :keywords => 'cat', :facets => {:x => 4.20}})

    assert{ Mongoid::FTS.search('cat').where(:facets => {'x' => 42.0}).first.model == a }
    assert{ Mongoid::FTS.search('cat').where(:facets => {'x' => 4.20}).first.model == b }

    assert{ Mongoid::FTS.search('cat').where('facets.x' => 42.0).first.model == a }
    assert{ Mongoid::FTS.search('cat').where('facets.x' => 4.20).first.model == b }

    assert{ Mongoid::FTS.search('cat').where('facets' => {'x' => 42.0}).explain['cursor'] =~ /BtreeCursor/ }
    assert{ Mongoid::FTS.search('cat').where('facets' => {'x' => 4.20}).explain['cursor'] =~ /BtreeCursor/ }

    assert{ Mongoid::FTS.search('cat').where('facets.x' => 42.0).explain['cursor'] =~ /BtreeCursor/ }
    assert{ Mongoid::FTS.search('cat').where('facets.x' => 4.20).explain['cursor'] =~ /BtreeCursor/ }
  end

##
#
  testing 'that keywords are considered more highly than fulltext' do
    k = new_klass do
      field(:title)
      field(:body)

      def to_haystack
        { :keywords => title, :fulltext => body }
      end
    end

    a = k.create!(:title => 'the cats', :body => 'like to meow')
    b = k.create!(:title => 'the dogs', :body => 'do not like to meow, they bark at cats')

    assert{ Mongoid::FTS.search('cat').count == 2 }
    assert{ Mongoid::FTS.search('cat').first.model == a }

    assert{ Mongoid::FTS.search('meow').count == 2 }
    assert{ Mongoid::FTS.search('bark').count == 1 }
    assert{ Mongoid::FTS.search('dog').first.model == b }
  end

##
#
  testing 'that re-indexing a class is idempotent' do
    k = new_klass do
      field(:title)
      field(:body)

      def to_haystack
        { :keywords => title, :fulltext => body }
      end
    end

    k.destroy_all

    n = 10

    n.times do |i|
      k.create!(:title => 'the cats and dogs', :body => 'now now is is the the time time for for all all good good men women')
      assert{ Mongoid::FTS.search('cat').count == (i + 1) }
    end
    assert{ Mongoid::FTS.search('cat').count == n }

    n.times do
      k.create!(:title => 'a b c abc xyz abc xyz b', :body => 'pdq pdq pdq xyz teh ngr am')
    end

    assert{ Mongoid::FTS.search('cat').count == n }
    assert{ Mongoid::FTS.search('pdq').count == n }

    ca = Mongoid::FTS::Token.all.inject({}){|hash, token| hash.update token.id => token.value}

    assert{ k.search_index_all! }

    cb = Mongoid::FTS::Token.all.inject({}){|hash, token| hash.update token.id => token.value}

    assert{ ca.size == Mongoid::FTS::Token.count }
    assert{ cb.size == Mongoid::FTS::Token.count }
    assert{ ca == cb }
  end

##
#
   testing 'that not just any model can be indexed' do
     o = new_klass.create!
     assert{ begin; Mongoid::FTS::Index.add(o); rescue Object => e; e.is_a?(ArgumentError); end }
   end

##
#
  testing 'that results can be expanded efficiently if need be' do
     k = new_klass
     3.times{ k.create! :content => 'cats' }

     results = assert{ Mongoid::FTS.search('cat') }
     assert{ Mongoid::FTS.models_for(results).map{|model| model.class} == [k, k, k] }
  end

##
#
  testing 'basic pagination' do
     k = new_klass
     11.times{|i| k.create! :content => "cats #{ i }" }

     assert{ k.search('cat').paginate(:page => 1, :size => 2).to_a.size == 2 }
     assert{ k.search('cat').paginate(:page => 2, :size => 5).to_a.size == 5 }

     accum = []

     n = 6
     size = 2
     (1..n).each do |page|
       list = assert{ k.search('cat').paginate(:page => page, :size => size) }
       accum.push(*list)
       assert{ list.num_pages == n }
       assert{ list.total_pages == n }
       assert{ list.current_page == page }
     end

     a = accum.map{|i| i.model}.sort_by{|m| m.content}
     b = k.all.sort_by{|m| m.content}

     assert{ a == b }
  end

##
#
  testing 'that pagination preserves the #model terminator' do
     k = new_klass
     11.times{|i| k.create! :content => "cats #{ i }" }

     list = assert{ k.search('cat').paginate(:page => 1, :size => 2) }
     assert{ list.is_a?(Mongoid::Criteria) }

     models = assert{ list.models }
     assert{ models.is_a?(Array) }
  end

##
#
  test '.words_for' do
    {
      ' cats and dogs ' => %w( cats and dogs ),
      ' cats-and-dogs ' => %w( cats and dogs ),
      ' cats_and_dogs ' => %w( cats and dogs ),
      ' cats!and?dogs ' => %w( cats and dogs ),
    }.each do |src, dst|
      assert{ Mongoid::FTS::words_for(src) == dst }
    end
  end

  test '.stems_for' do
    {
      ' cats and dogs ' => %w( cat dog ),
      ' cats!and?dogs ' => %w( cats!and?dog ),
      ' fishing and hunting ' => %w( fish hunt ),
      ' fishing-and-hunting ' => %w( fishing-and-hunt ),
    }.each do |src, dst|
      assert{ Mongoid::FTS::stems_for(src) == dst }
    end
  end

  test '.tokens_for' do
   {
    'cats-and-dogs Cats!and?dogs foo-bar! The end. and trees' => %w( cats-and-dogs cats cat dogs dog Cats!and?dogs Cats cat dogs dog foo-bar foo bar end trees tree )
   }.each do |src, dst|
     assert{ Mongoid::FTS.tokens_for(src) == dst }
   end
  end
=end

protected

  def new_klass(&block)
    if Object.send(:const_defined?, :K)
      Object.const_get(:K).destroy_all
      Object.send(:remove_const, :K)
    end

    k = Class.new(A) do
      self.default_collection_name = :ks
      def self.name() 'K' end
    end

    Object.const_set(:K, k)

    k.class_eval do
      include ::Mongoid::FTS
      class_eval(&block) if block
    end

    k
  end

  setup do
    [A, B, C].map{|m| m.destroy_all}
    Mongoid::FTS.destroy_all
  end

=begin
  H = Mongoid::FTS
  T = Mongoid::FTS::Token
  I = Mongoid::FTS::Index

  at_exit{ K.destroy_all if defined?(K) }
=end
end
