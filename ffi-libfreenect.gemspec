# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "ffi-libfreenect"
  s.version     = "0.1.1"
  s.date        = "2012-02-14"
  s.platform    = Gem::Platform::RUBY 
  s.authors     = ["Josh Grunzweig", "Eric Monti"]
  # s.email       = ["..."]
  s.homepage    = "http://github.com/jgrunzweig/ffi-libfreenect"
  s.summary     = %q{FFI bindings for the libfreenect OpenKinect library}
  s.description = %q{FFI bindings for the libfreenect OpenKinect library}

  # s.rubyforge_project = "asset_sync"
  s.rdoc_options += ["--title", "FFI Freenect", "--main",  "README.rdoc", "--line-numbers"]

  s.add_dependency("ffi", ">= 0.5.0")

  s.add_development_dependency "bundler"
  s.add_development_dependency "jeweler"
  s.add_development_dependency "rspec"
  s.add_development_dependency "yard"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
