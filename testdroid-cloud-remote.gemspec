# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
 gem.name = "testdroid-cloud-remote"
  gem.homepage = "http://github.com/sakari.rautiainen@bitbar.com/testdroid-cloud-remote"
  gem.license = "MIT"
  gem.summary = %Q{Testdroid Cloud remote contol}
  gem.description = %Q{Remote control testdroid cloud devices}
  gem.email = "sakari.rautiainen@bitbar.com"
  gem.authors = ["Sakari Rautiainen"]
 
  gem.version       = '0.1.1'
 
  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']
  gem.add_dependency 'stomp', '~> 1.2.6'
  gem.add_dependency 'json', '~> 1.7.5'
  gem.add_development_dependency 'json', '~> 1.7.5'
  gem.add_development_dependency 'rspec', '~> 2.4'
  gem.add_development_dependency 'rubygems-tasks', '~> 0.2'
end
