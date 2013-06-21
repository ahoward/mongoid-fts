NAME
  mongoid-fts.rb

DESCRIPTION
  enable mongodb's new fulltext simply and quickly on your mongoid models, including pagination.

SYNOPSIS

````ruby

  class A
    include Mongoid::Document
    include Mongoid::FTS

    field(:title)
    field(:body)

    def to_search
      {:title => title, :fulltext => body}
    end
  end


  class B
    include Mongoid::Document
    include Mongoid::FTS

    field(:title)
    field(:body)

    def to_search
      {:title => title, :fulltext => body}
    end
  end


  A.create!(:title => 'foo', :body => 'cats')
  A.create!(:title => 'bar', :body => 'dogs')

  B.create!(:title => 'foo', :body => 'cats')
  B.create!(:title => 'bar', :body => 'dogs')

  p FTS.search('cat', :models => [A, B])
  p FTS.search('dog', :models => [A, B])

  p A.search('cat')
  p B.search('cat')
  p A.search('dog')
  p B.search('dog')

  p A.search('cat dog').page(1).per(1)

````
