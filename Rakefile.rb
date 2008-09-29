task :default => [:test]

desc "Run the unit tests"
task :test do
  ruby "-rubygems", "test.rb"
end

desc "Test for Mars prerequisites"
task :prereqs do
  ruby "-rubygems", "prereqs.rb"
end

desc "Clean up published files"
task :clean do
  CLEAN_FILES = FileList['./*.xml', './*.html']
  CLEAN_FILES.each do |fn|
    rm fn 
  end
  rmdir "images"
end

desc "Clean up all files"
task :clean_all do
  CLEAN_ALL_FILES = FileList['./*.xml', './*.html', './*.haml', './*.xslt', './*.ini', './*.css', './*.ico', './*.js', './images/*', "source/*", "http/*", "entry/*"]
  CLEAN_ALL_FILES.each do |fn|
    rm fn 
  end
  rmdir "images"
  rmdir "source"
  rmdir "http"
  rmdir "entry"
end

desc "Clean up cache files"
task :clean_cache do
  CLEAN_CACHE_FILES = FileList[ "source/*", "http/*", "entry/*"]
  CLEAN_CACHE_FILES.each do |fn|
    rm fn 
  end
  rmdir "source"
  rmdir "http"
  rmdir "entry"
end

desc "Install config files for haml/intertwingly example"
task :setup do
  FileList['./themes/intertwingly/*'].each do |f| cp "#{f}", "."  end
  mkdir "images"
  mv "feed-icon-10x10.png", "images"
end

desc "Run planet for haml example"
task :planet do
  ruby "planet.rb", "basic.ini"
end

desc "Splice planet for haml example"
task :splice do
  ruby "splice.rb", "basic.ini"
end
