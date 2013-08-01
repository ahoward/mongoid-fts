## mongoid-fts.gemspec
#

Gem::Specification::new do |spec|
  spec.name = "mongoid-fts"
  spec.version = "0.4.4"
  spec.platform = Gem::Platform::RUBY
  spec.summary = "mongoid-fts"
  spec.description = "enable mongodb's new fulltext simply and quickly on your mongoid models, including pagination."

  spec.files =
["README.md",
 "Rakefile",
 "lib",
 "lib/app",
 "lib/app/mongoid",
 "lib/app/mongoid/fts",
 "lib/app/mongoid/fts/index.rb",
 "lib/mongoid",
 "lib/mongoid-fts.rb",
 "mongoid-fts.gemspec"]

  spec.executables = []
  
  spec.require_path = "lib"

  spec.test_files = nil

  
    spec.add_dependency(*["mongoid", "~> 3.1"])
  
    spec.add_dependency(*["map", "~> 6.5"])
  
    spec.add_dependency(*["coerce", "~> 0.0"])
  

  spec.extensions.push(*[])

  spec.rubyforge_project = "codeforpeople"
  spec.author = "Ara T. Howard"
  spec.email = "ara.t.howard@gmail.com"
  spec.homepage = "https://github.com/ahoward/mongoid-fts"
end
