require 'fileutils'
require 'planet/config'
require 'planet/harvest'
require 'planet/spider'
require 'planet/splice'

# create a temporary working directory
base = File.dirname(File.expand_path(__FILE__))
work = File.join(base, 'test', 'work', 'reconstitute')
FileUtils.mkdir_p work

# skeleton config
config = Planet.config
config['Planet']['cache_directory'] = File.join(work, 'cache')
config['Planet']['template_files'] = 'themes/common/atom.xml.xslt'
config['Planet']['output_dir'] = File.join(work, 'output')

# add subscriptions
ARGV.each {|sub| config[sub] = {'__name__' => sub}}

# fetch
Planet.spider

# fill in the rest of the configuration
Dir[File.join(work, 'cache', 'source', '*')].each do |source|
  source = Planet.harvest(source)
  config['Planet']['name'] = source.feed.title
  config['Planet']['link'] = source.feed.link
  config['Planet']['owner_name'] = source.feed.author_detail.name
  config['Planet']['owner_email'] = source.feed.author_detail.email
end

# produce feed
Planet.splice

# output feed
puts open(File.join(work, 'output', 'atom.xml')).read

# cleanup
FileUtils.rmtree work
FileUtils.remove_dir File.dirname(work)
