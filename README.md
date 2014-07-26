NAME
------------------

mongoid-fts.rb

DESCRIPTION
------------------

enable mongodb's new fulltext simply and quickly on your mongoid models.

mongodb's built-in fulltext is handy, but has several warts which make it
difficult to use in real projects:

- queries are boolean OR by default, meaning a user typing more and more
  specific search queries gets back less and less specific search results
- lack of limit+offset on queries, making pagination a beast
- lack of substring/fuzzy search
- lack of literal search (find by id, uuid, etc. without hitting stemming/stopword functionality)
- ability to search across collections

mongoid-fts smoothes over these warts, and more, for your mongoid 3 and 4
projects supporting:

- pagination
- strict literal searching (including stopwords)
- cross models searching
- index is automatically kept in sync
- customize ranking with #to_search
- fuzzy search (title and keywords included by default)

INSTALL
------------------

````ruby

  gem 'mongoid-fts'

````

````bash

# required

  ~> bundle install

  ~> rake db:mongoid:create_indexes

# optional (this is done automatically)

  ~> rails runner 'Mongoid::FTS.enable!'

````

SYNOPSIS
------------------

````ruby

# use the mixin method on your models to give them a 'search' method.  fts
# will attempt to guess which fields you mean to search.  title will be
# weighted most highly, then the array of keywords, then the fulltext of the
# model
#
  class A
    include Mongoid::Document
    include Mongoid::FTS::Able

    field(:title)
    field(:keywords, :type => Array)
    field(:fulltext)
  end

# if your fields are named like this you can certain override what's indexed
#

  class B
    include Mongoid::Document
    include Mongoid::FTS::Able

    field(:a)
    field(:b, :type => Array, :default => [])
    field(:c)

    def to_search
      {
        :literals => [id, sku],
        :title => a,
        :keywords => (b + ['foobar']),
        :fuzzy => [a, b],
        :fulltext => c
      }
    end
  end


# after this searching is pretty POLS
#

  A.create!(:title => 'foo', :body => 'cats')
  A.create!(:title => 'foo', :body => 'cat')

  p A.search('cat').size #=> 2

  p A.search(:literal => A.first.id).size #=> 1

# you can to cross-model searches like so
#
  p Mongoid::FTS.search('cat', :models => [A, B])
  p Mongoid::FTS.search('dog', :models => [A, B])

# pagination is supported

  A.search('cats').page(10).per(3)

# or 

  A.search('cats').paginate(:page => 10, :per => 3)


# handy to know

  Mongoid::FTS::Index.rebuild! # re-index every currently known object - not super effecient

  Mongoid::FTS::Index.reset!   # completely drop/create indexes - lose all objects

  Mongoid::FTS.index(model)    # add an object to the fts index

  Mongoid::FTS.unindex(model)  # remove and object from the fts index

````

- this implementation has a work around for fulltext pagination, ref: https://groups.google.com/forum/#!topic/mongodb-user/2hUgOAN4KKk
- this implementation has a work around for the lack of logical and ref: https://groups.google.com/forum/#!topic/mongodb-user/2hUgOAN4KKk

regardless, the *interface* of this mixin is uber simple and should be quite
future proof.  as the mongodb teams moves search forward i'll track the new
implementation and preserve the current interface.  until it settles down,
however, i'll resist adding new features.

