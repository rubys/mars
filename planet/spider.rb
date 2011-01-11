require 'planet/fido'
require 'planet/transmogrify'
require 'planet/sift'
require 'fileutils'
require 'rexml/formatters/default'

module Planet

  # Fetch a set of feeds, normalize, and write each as a set of entries into a
  # cache directory.
  def Planet.spider
    config = Planet.config['Planet']
    cache = config['cache_directory']
    http_cache = File.join(cache,'http')
    entry_cache = File.join(cache,'entry')
    source_cache = File.join(cache,'source')

    # make output directories
    FileUtils.mkdir_p http_cache, :mode => 0700
    FileUtils.mkdir_p entry_cache, :mode => 0700
    FileUtils.mkdir_p source_cache, :mode => 0700

    # prep fetcher
    fido = Planet::Fido.new(http_cache)
    fido.threads = config['spider_threads'].to_i if config['spider_threads']
    fido.timeout = config['feed_timeout'].to_f if config['feed_timeout']

    # process subscriptions: for each updated feed, updated the cache with
    # the set of canonicalized entries augmented with source information.
    subs = Planet.config.keys.grep(/^https?:\/\//)
    fido.each(subs) do |sub, resp|
      next unless resp.code == '200'
      uri = resp.header['Content-Location'] || sub

      # first set of filters: xml parsing and element names
      doc = Planet::Transmogrify.parse(resp.body)
      feed = doc.root || doc

      # add in self information
      if not feed.at('link[@rel="self"]')
        link = feed.document.create_element('link',{'rel'=>'self', 'href'=>uri})
        feed.children.first.add_previous_sibling(link)
        if doc.version[0..2] == 'rss'
          link.attributes['type'] == 'application/rss+xml'
        elsif doc.version[0..3] == 'atom'
          link.attributes['type'] == 'application/atom+xml'
        else
          Planet.log.error "Not a feed - #{uri}"
          next
        end
      end

      # fix title_type, name_type, summary_type, and content_type
      # per config file
      Planet.config[sub].each do |name,value|
        case value
          when 'text/html', 'html'
            type = 'html'
          when 'text/plain', 'text'
            type = 'text'
          when 'application/xhtml+xml', 'xhtml'
            type = 'xhtml'
          else
            next
        end

        case name
          when 'title_type'
            feed.each_element('//entry/title') do |title|
              title.add_attribute('type') unless title.attributes['type']
              title.attributes['type'] = type
            end
          when 'summary_type'
            feed.each_element('//entry/summary') do |summary|
              summary.add_attribute('type') unless summary.attributes['type']
              summary.attributes['type'] = type
            end
          when 'content_type'
            feed.each_element('//entry/content') do |content|
              content.add_attribute('type') unless content.attributes['type']
              content.attributes['type'] = type
            end
          when 'name_type'
            feed.each_element('//entry/author/name') do |auth_name|
              auth_name.add_attribute('type') unless auth_name.attributes['type']
              auth_name.attributes['type'] = type
            end
          end
        end

      # second set of filters: cardinality, sanitization, dates, and uris
      doc.root['xml:base'] ||= Planet.config[sub]['xml_base'] || uri
      Planet.sift feed, fido

      # process feed attributes: xml* (xml:lang, xml:base, xmlns) will need
      # need to be transplanted to each entry.  The rest will simply be
      # placed on the source element
      root_attrs = {}
      source = feed.document.create_element('source')
      feed.attribute_nodes.each do |attrib|
        if attrib.namespace
          expanded_name = "#{attrib.namespace.prefix}:#{attrib.name}"
        else
          expanded_name = attrib.name
        end

        if expanded_name[0..2] == 'xml'
          root_attrs[expanded_name] = attrib.value
        else
          source.attributes[expanded_name] = attrib.value
        end
      end

      # add in configuration information (names, hackergotchi icons...)
      Planet.source(sub, source)
      source.add_namespace 'planet', 'http://planet.intertwingly.net'

      # process feed elements: entries will be captured for later processing,
      # other elements will be transplanted to the source element.
      entries = []
      feed.elements.each do |element|
        if element.name == 'entry'
          entries << element
        else
          source.add_child(element)
        end
      end

      entries.each do |entry|
        # try to find a unique id (TODO: try harder)
        id = entry.at('id').text rescue nil
        id ||= entry.at('./link[@rel="alternate"]/@href') rescue nil
        next unless id

        unless /^\w+\:/ =~ id
          id = 'urn:feed-entry-id:' + id
          entry.at('id').text = id
        end

        # determine output file name for this entry
        entry_file = File.join(entry_cache, Planet.filename(id))

        # determine updated date
        updated = entry.at('updated')
        if not updated
          updated = entry.add_child(entry.document.create_element('updated'))
          if entry.at('published')
            updated.content = entry.at('published').text
          elsif File.exist? entry_file
            updated.text=File.stat(entry_file).mtime.iso8601
          else
            updated.text=DateTime.now.to_s
          end
        end

        # augment with feed xml* attributes and source information
        root_attrs.each_pair {|name,value| entry.attributes[name]=value}
        entry.add_child(source) if not entry.at('source')

        # output the entry, with a timestamp reflecting the update time
        File.open(entry_file, 'w') { |file| file.write entry.to_s }
        updated = Time.parse(updated.text)
        File.utime updated, updated, entry_file
      end

      # write source information out to the cache
      if feed.name == 'feed'
        source.add_namespace nil, 'http://www.w3.org/2005/Atom'
        source.name = 'planet:source'
        root_attrs.each_pair {|name,value| source.attributes[name]=value}
        source_file = File.join(source_cache, Planet.filename(sub))
        File.open(source_file, 'w') { |file| file.write source.to_s }
      end
    end
  end

  # add configuration information to a source element
  def Planet.source sub, element
    Planet.config[sub].each do |name,value|
      next if name[0..1] == '__'
      child = element.document.create_element("planet:#{name}")
      child.text = value
      element.add_child(child)
    end
  end
end
