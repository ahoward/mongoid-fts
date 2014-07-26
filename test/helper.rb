# -*- encoding : utf-8 -*-

# this triggers mongoid to load rails...
# module Rails; end

require_relative 'testing'
require_relative '../lib/mongoid-fts.rb'

Mongoid::FTS.connect!
Mongoid::FTS.reset!

class A
  include Mongoid::Document
  include Mongoid::FTS::Able
  field(:content, :type => String)
  def to_s; content; end

  field(:a)
  field(:b)
  field(:c)
end

class B
  include Mongoid::Document
  include Mongoid::FTS::Able
  field(:content, :type => String)
  def to_s; content; end

  field(:a)
  field(:b)
  field(:c)
end

class C
  include Mongoid::Document
  include Mongoid::FTS::Able
  field(:content, :type => String)
  def to_s; content; end

  field(:a)
  field(:b)
  field(:c)
end

