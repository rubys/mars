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
    feed = REXML::Document.new('<feed xmlns="http://www.w3.org/2005/Atom"/>')
    feed.root.add_namespace('planet', 'http://planet.intertwingly.net/')
    feed.root.add_namespace('indexing', 'urn:atom-extension:indexing')
    feed.root.attributes['indexing:index'] = 'no'
    title = feed.root.add_element('title')
    title.text = config['name'].to_s
    updated = feed.root.add_element('updated')
    updated.text = Time.now.iso8601
    generator = feed.root.add_element('generator', {'uri' => 'http://github.com/rubys/mars/tree/master'})
    generator.text = 'Mars'
    author = feed.root.add_element('author')
    author_name = author.add_element('name')
    author_name.text = config['owner_name']    
    author_email = author.add_element('email')
    author_email.text = config['owner_email']    
    id = feed.root.add_element('id')
    id.text = URI.join(config['link'],'atom.xml').to_s
    link_self = feed.root.add_element('link', {'rel'=>'self', 'href'=>id.text})
    link_self.attributes['type'] = 'application/atom+xml'
    link_alt = feed.root.add_element('link', {'rel' => 'alternate', 'href' => config['link'] })
    link_alt.attributes['type'] = 'application/xhtml+xml'

    # add the latest 'items_per_page' entries to the feed
    entry_cache = File.join(config['cache_directory'],'entry')
    Dir.chdir(entry_cache) do
      files = Dir['*'].map {|name| [File.stat(name).mtime.to_i, name]}

      files.sort!.reverse!

      items = (config['items_per_page'] or 30).to_i rescue 30
      files[0...items].each do |mtime, name|
        entry = Planet::XmlParser.parse(File.open(name))
        if entry.bozo or !entry.root
          Planet.log.error "Parse error - #{File.join(entry_cache, name)}"
        else
          entry.delete_namespace
          feed.root.add entry.root
        end
      end
    end

    # insert formatted versions of updated dates
    format = config['date_format']
    feed.elements.each('//updated') do |updated|
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
        if source.bozo
          Planet.log.warn "Parse error - #{source_file}"
          source = nil
        end
      rescue Errno::ENOENT => e
        Planet.log.warn e.to_s
      rescue Exception => e
        Planet.log.error e.to_s
      end

      # fill in a placeholder information, if necessary
      source = REXML::Element.new('planet:source') unless source
      Planet.source(sub, source) unless source.has_elements?

      # atom:source should not have atom:published as a child. But should
      # have atom:updated. Some feeds spooge this, so we do the best we can.
      if source.elements['child::published']
        if source.updated
         source.delete_element source.published 
        else
          source.published.name = 'updated'
        end
      end

      feed.root.add source.root
    end

    # apply templates
    TemplatePublisher.new.publish_feed(config['template_files'], feed)
  end
end
