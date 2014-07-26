## mongoid-fts.gemspec
#

Gem::Specification::new do |spec|
  spec.name = "mongoid-fts"
  spec.version = "2.0.0"
  spec.platform = Gem::Platform::RUBY
  spec.summary = "mongoid-fts"
  spec.description = "enable mongodb's new fulltext simply and quickly on your mongoid models, including pagination."
  spec.license = "same as ruby's"

  spec.files =
["LICENSE",
 "README.md",
 "Rakefile",
 "lib",
 "lib/app",
 "lib/app/mongoid",
 "lib/app/mongoid/fts",
 "lib/app/mongoid/fts/index.rb",
 "lib/mongoid-fts",
 "lib/mongoid-fts.rb",
 "lib/mongoid-fts/able.rb",
 "lib/mongoid-fts/error.rb",
 "lib/mongoid-fts/index.rb",
 "lib/mongoid-fts/rails.rb",
 "lib/mongoid-fts/raw.rb",
 "lib/mongoid-fts/results.rb",
 "lib/mongoid-fts/stemming",
 "lib/mongoid-fts/stemming.rb",
 "lib/mongoid-fts/stemming/stopwords",
 "lib/mongoid-fts/stemming/stopwords/english.txt",
 "lib/mongoid-fts/stemming/stopwords/extended_english.txt",
 "lib/mongoid-fts/stemming/stopwords/full_danish.txt",
 "lib/mongoid-fts/stemming/stopwords/full_dutch.txt",
 "lib/mongoid-fts/stemming/stopwords/full_english.txt",
 "lib/mongoid-fts/stemming/stopwords/full_finnish.txt",
 "lib/mongoid-fts/stemming/stopwords/full_french.txt",
 "lib/mongoid-fts/stemming/stopwords/full_german.txt",
 "lib/mongoid-fts/stemming/stopwords/full_italian.txt",
 "lib/mongoid-fts/stemming/stopwords/full_norwegian.txt",
 "lib/mongoid-fts/stemming/stopwords/full_portuguese.txt",
 "lib/mongoid-fts/stemming/stopwords/full_russian.txt",
 "lib/mongoid-fts/stemming/stopwords/full_russiankoi8_r.txt",
 "lib/mongoid-fts/stemming/stopwords/full_spanish.txt",
 "lib/mongoid-fts/util.rb",
 "mongoid-fts.gemspec",
 "test",
 "test/helper.rb",
 "test/mongoid-fts_test.rb",
 "test/testing.rb"]

  spec.executables = []
  
  spec.require_path = "lib"

  spec.test_files = nil

  
    spec.add_dependency(*["mongoid", "~> 3.1"])
  
    spec.add_dependency(*["map", "~> 6.5"])
  
    spec.add_dependency(*["coerce", "~> 0.0"])
  
    spec.add_dependency(*["unicode_utils", "~> 1.4"])
  
    spec.add_dependency(*["stringex", "~> 2.0"])
  
    spec.add_dependency(*["fast-stemmer", "~> 1.0"])
  

  spec.extensions.push(*[])

  spec.rubyforge_project = "codeforpeople"
  spec.author = "Ara T. Howard"
  spec.email = "ara.t.howard@gmail.com"
  spec.homepage = "https://github.com/ahoward/mongoid-fts"
end
