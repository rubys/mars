require 'planet/config'
require 'planet/style'
require 'planet/xmlparser'
require 'fileutils'
require 'time'

module Planet

  def Planet.splice
    config = Planet.config['Planet']

    # ensure that the output directory exists
    output_dir = config['output_dir'] || '.'
    FileUtils.mkdir_p(output_dir)

    # produce a minimal feed header (TODO: complete)
    feed = REXML::Document.new('<feed xmlns="http://www.w3.org/2005/Atom"/>')
    feed.root.add_namespace('planet', 'http://planet.intertwingly.net/')
    id = feed.root.add_element('id')
    id.text = URI.join(config['link'],'atom.xml').to_s
    link = feed.root.add_element('link', {'rel'=>'self', 'href'=>id.text})
    link.attributes['type'] = 'application/atom+xml'
    title = feed.root.add_element('title')
    title.text = config['name'].to_s
    updated = feed.root.add_element('updated')
    updated.text = Time.now.iso8601

    # add the latest 'items_per_page' entries to the feed
    entry_cache = File.join(config['cache_directory'],'entry')
    feed.root.add_text "\n\n"
    Dir.chdir(entry_cache) do
      files = Dir['*'].map {|name| [File.stat(name).mtime.to_i, name]}

      files.sort!.reverse!

      items = config['items_per_page'].to_i rescue 30
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
      feed.root.add_text "\n\n"
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

      feed.root.add source.root
      feed.root.add_text "\n"
    end

    # output the Atom feed
    File.open(File.join(output_dir,'atom.xml'),'w') do |file|
      Planet.log.info 'Producing atom.xml'
      feed.write(file)
    end

    # apply templates
    config['template_files'].split.each do |template|
      next unless template =~ /^ .* \/ (.*) \. (\w+)/x

      if $2 != 'xslt'
        Planet.log.warn "#{$2}: not yet supported"
      else
        File.open(File.join(output_dir,$1),'w') do |file|
          Planet.log.info "Processing template #{template}"
          file.write Planet::Xslt.process(template, feed)
        end
      end
    end
  end
end
