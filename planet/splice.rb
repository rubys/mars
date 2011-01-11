require 'planet/config'
require 'planet/xmlparser'
require 'fileutils'
require 'time'
require 'rexml/formatters/default'
require 'planet/publisher'

module Planet

  def Planet.splice
    config = Planet.config['Planet']

    # ensure that the output directory exists
    output_dir = config['output_dir'] || '.'
    FileUtils.mkdir_p(output_dir)

    # produce a minimal feed header (TODO: complete)
    feed = Planet::XmlParser.parse('<feed xmlns="http://www.w3.org/2005/Atom"/>')
    feed.root.add_namespace('planet', 'http://planet.intertwingly.net/')
    feed.root.add_namespace('indexing', 'urn:atom-extension:indexing')
    feed.root.attributes['indexing:index'] = 'no'
    title = feed.root.add_child(feed.create_element('title'))
    title.content = config['name'].to_s
    updated = feed.root << feed.create_element('updated')
    updated.content = Time.now.iso8601
    generator = feed.root.add_child(feed.create_element('generator', {'uri' => 'http://github.com/rubys/mars/tree/master'}))
    generator.content = 'Mars'
    author = feed.root.add_child(feed.create_element('author'))
    author_name = author.add_child(feed.create_element('name'))
    author_name.content = config['owner_name']    
    author_email = author.add_child(feed.create_element('email'))
    author_email.content = config['owner_email']    
    id = feed.root.add_child(feed.create_element('id'))
    id.content = URI.join(config['link'],'atom.xml').to_s rescue nil
    link_self = feed.root.add_child(feed.create_element('link', {'rel'=>'self', 'href'=>id.text}))
    link_self.attributes['type'] = 'application/atom+xml'
    link_alt = feed.root.add_child(feed.create_element('link', {'rel' => 'alternate', 'href' => config['link'] }))
    link_alt.attributes['type'] = 'application/xhtml+xml'

    # add the latest 'items_per_page' entries to the feed
    entry_cache = File.join(config['cache_directory'],'entry')
    Dir.chdir(entry_cache) do
      files = Dir['*'].map {|name| [File.stat(name).mtime.to_i, name]}

      files.sort!.reverse!

      items = (config['items_per_page'] or 30).to_i rescue 30
      files[0...items].each do |mtime, name|
        entry = Planet::XmlParser.parse(File.open(name))
        entry.remove_attribute('xmlns')
        feed.root.add_child entry.root
      end
    end

    # insert formatted versions of updated dates
    format = config['date_format']
    feed.elements.search('//updated') do |updated|
      next unless updated.namespace == 'http://www.w3.org/2005/Atom'
      begin
        formatted_time = Time.parse(updated.text).strftime(format)
        updated.attributes['planet:format'] = formatted_time
      rescue
      end
    end

    # add source information
    source_cache = File.join(config['cache_directory'],'source')
    Planet.config.keys.grep(/^https?:\/\//).each do |sub|
      source_file = File.join(source_cache, Planet.filename(sub))

      source = nil
      begin
        File.open(source_file) {|file| source = Planet::XmlParser.parse(file)}
      rescue Errno::ENOENT => e
        Planet.log.warn e.to_s
      rescue Exception => e
        Planet.log.error e.to_s
      end

      # fill in a placeholder information, if necessary
      source = feed.document.create_element('planet:source') unless source
      Planet.source(sub, source) if source.elements.empty?

      feed.root.add_child source.root
    end

    # apply templates
    TemplatePublisher.new.publish_feed(config['template_files'], feed)
  end
end
