# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "message_router/version"

Gem::Specification.new do |s|
  s.name        = "message_router"
  s.version     = MessageRouter::VERSION
  s.authors     = ["Brad Gessler", "Paul Cortens", "Christopher Bertels"]
  s.email       = ["brad@bradgessler.com", "paul@thoughtless.ca", "bakkdoor@flasht.de"]
  s.homepage    = ""
  s.summary     = %q{Route messages}
  s.description = %q{a DSL for routing SMS, Twitter, and other short message formats.}

  s.rubyforge_project = "message_router"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
