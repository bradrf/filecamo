Gem::Specification.new do |s|
  s.name        = 'filecamo'
  s.version     = File.readlines('lib/filecamo.rb').grep(/VERSION/){|v|v.match(/'([^']+)'/)[1]}[0]
  s.summary     = 'File content generator and manipulator.'
  s.description = 'Generate and manipulate entire directory trees of either binary or text file content.'
  s.authors     = ['Brad Robel-Forrest']
  s.email       = 'brad@bitpony.com'
  s.files         = `git ls-files -z`.split("\x0")
  s.executables = ['filecamo']
  s.homepage    = 'https://github.com/bradrf/filecamo#readme'
  s.license     = 'MIT'
  s.add_runtime_dependency 'better_bytes', '~> 0.0.1'
  s.add_runtime_dependency 'literate_randomizer', '~> 0.4.0'
  s.add_runtime_dependency 'ruby-filemagic', '~> 0.7.1'
end
