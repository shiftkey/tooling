require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/test_*.rb']
end

desc "Run tests"
task :default => :test
