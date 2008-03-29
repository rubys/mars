task :default => [:test]

task :test do
  ruby "-rubygems", "test.rb"
end

task :prereqs do
  ruby "-rubygems", "prereqs.rb"
end
