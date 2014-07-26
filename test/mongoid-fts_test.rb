# encoding: utf-8
#
require_relative 'helper'

Testing Mongoid::FTS do
#
  testing 'wording' do
    assert{ Mongoid::FTS.words_for('dogs cats fishes') == %w[ dogs cats fishes ] }
    assert{ Mongoid::FTS.words_for('foo-bar baz_bub') == %w[ foo bar baz_bub ] }
  end

#
  testing 'stemming' do
    assert{ Mongoid::FTS.stems_for('dogs cats fishes') == %w[ dog cat fish ] }
  end

#
  testing 'terming' do
    assert{ Mongoid::FTS.terms_for('dogs and the cats and those fishes') == %w[ dog cat fish ] }
    assert{ Mongoid::FTS.terms_for('the foo-bar and then baz_bub') == %w[ foo bar baz_bub ] }
    assert{ Mongoid::FTS.terms_for('the foo-bar and then baz_bub', :subterms => true) == %w[ foo bar baz_bub baz bub ] }
  end

#
  testing 'fuzzy' do
    assert{ 
      actual = Mongoid::FTS.fuzzy("über")
      expected = ["_ü", "üb", "be", "er", "r_", "_üb", "übe", "ber", "er_", "_u", "ub", "_ub", "ube"]

      actual.zip(expected).all? do |a,b|
        a = Mongoid::FTS.utf8ify(a)
        b = Mongoid::FTS.utf8ify(b)
        a == b
      end
    }
  end

#
  testing 'that models can, at minimum, be indexed and searched' do
    a = A.create!(:content => 'dogs')
    b = B.create!(:content => 'cats')

    assert{ Mongoid::FTS.index(a) }
    assert{ Mongoid::FTS.index(b) }

    assert{ Mongoid::FTS.search('dog') == [a] }
    assert{ Mongoid::FTS.search('cat') == [b] }
    assert{ Mongoid::FTS.search('Cat') == [b] }
  end

#
  testing 'fuzzy search' do
    a = A.create!(:title => 'über')

    assert{ Mongoid::FTS.index(a) }

    assert{ Mongoid::FTS.search('uber') == [a] }
    assert{ Mongoid::FTS.search('üb') == [a] }
  end

#
  testing 'that rare words float to the front of the results' do
    a = A.create!(:content => 'dog')
    b = A.create!(:content => 'dog dog')
    c = A.create!(:content => 'dog dog dog')
    d = A.create!(:content => 'dog dog dog cat')
    
    assert{ Mongoid::FTS.index(A) }
    assert{ Mongoid::FTS.search('cat dog') == [d] }
  end

#
  testing 'that word specificity affects the search' do
    a = A.create!(:content => 'cat@dog.com')
    b = A.create!(:content => 'dogs')
    c = A.create!(:content => 'dog')
    d = A.create!(:content => 'cats')
    e = A.create!(:content => 'cat')

    assert{ Mongoid::FTS.index(A) }

    assert{ Mongoid::FTS.search('cat@dog.com') == [a] }
    assert{ Mongoid::FTS.search('cat') == [e, d, a] }
    assert{ Mongoid::FTS.search('dog') == [c, b, a] }
  end

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

#
  testing 'that keywords are considered more highly than fulltext' do
    a = A.create!(:title => 'the cats', :content => 'like to meow')
    b = A.create!(:title => 'the dogs', :content => 'do not like to meow, they bark at cats')

    assert{ Mongoid::FTS.search('cat').count == 2 }
    assert{ Mongoid::FTS.search('cat').first == a }

    assert{ Mongoid::FTS.search('meow').count == 2 }
    assert{ Mongoid::FTS.search('bark').count == 1 }
    assert{ Mongoid::FTS.search('dog').first == b }
  end

#
  testing 'basic pagination' do
     11.times{|i| A.create! :content => "cats #{ i }" }

     assert{ A.search('cat').paginate(:page => 1, :size => 2).to_a.size == 2 }
     assert{ A.search('cat').paginate(:page => 2, :size => 5).to_a.size == 5 }

     accum = []

     n = 6
     size = 2
     (1..n).each do |page|
       list = assert{ A.search('cat').paginate(:page => page, :size => size) }
       accum.push(*list)
       assert{ list.num_pages == n }
       assert{ list.total_pages == n }
       assert{ list.current_page == page }
     end

     a = accum.map{|i| i}.sort_by{|m| m.content}
     b = A.all.sort_by{|m| m.content}

     assert{ a == b }
  end

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
