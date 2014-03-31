# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__),'lib','peas','version.rb'])
spec = Gem::Specification.new do |s|
  s.name = 'peas'
  s.version = Peas::VERSION
  s.author = 'Tom Buckley-Houston'
  s.email = 'tom@tombh.co.uk'
  s.homepage = 'http://github.com/tombh/peas'
  s.platform = Gem::Platform::RUBY
  s.summary = 'PaaS for the people'
  s.files = `git ls-files`.split("
")
  s.require_paths << 'lib'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.rdoc','peas.rdoc']
  s.rdoc_options << '--title' << 'peas' << '--main' << 'README.rdoc' << '-ri'
  s.bindir = 'bin'
  s.executables << 'peas'
  s.add_development_dependency('rake')
  s.add_development_dependency('rdoc')
  s.add_development_dependency('aruba')
  s.add_runtime_dependency('gli','2.9.0')
end
