require 'planet/formatter'
require 'planet/harvest'
require 'planet/config'

class HamlFormatter < PlanetFormatter
  def initialize
    # http://haml.hamptoncatlin.com/
    require 'haml'
  rescue LoadError
    puts "Haml_interp: haml library not found. Try gem install haml"
  end

  def map_feed(f)
    # map a harvest feed to a hash
    out = {}
    out['author'] = string(f.author) unless f.author.size == 0
    out['author_name'] = string(f.author_detail.name) if f.author_detail.name
    out['icon'] = string(f.icon) if f.icon
    out['id'] = string(f.id) if f.id
    out['last_updated'] = planet_date(f.updated) if f.updated
    out['last_updated_822'] = rfc822(f.updated) if f.updated
    out['last_updated_iso'] = rfc3399(f.updated) if f.updated
    out['link'] = string(f.link) if f.link
    out['logo'] = string(f.logo) if f.logo
    out['message'] = string(f.message) if f.message
    out['name'] = string(f.name) if f.name
    out['rights'] = string(f.rights) unless f.rights.size == 0
    out['subtitle'] = string(f.subtitle) unless f.subtitle.size == 0
    out['title'] = string(f.title) unless f.title.size == 0
    out['title_plain'] = plain(f.title) unless f.title.size == 0
    out['url'] = string(f.url) if f.url
    return out
  end

  def map_entry(e)
    # map a harvest entry to a hash
    out = {}
    out['author'] = string(e.author) unless e.author.size == 0
    out['author_name'] = string(e.author_detail.name) if e.author_detail.name
    out['author_email'] = string(e.author_detail.email) if e.author_detail.email
    out['author_uri'] = string(e.author_detail.uri) if e.author_detail.uri
    out['channel_author'] = string(e.source.author) unless e.source.author.size == 0
    out['channel_author_name'] = string(e.source.author_detail.name) if e.source.author_detail.name
    out['channel_icon'] = string(e.source.icon) if e.source.icon
    out['channel_id'] = string(e.source.id) if e.source.id
    out['channel_last_updated'] = planet_date(e.updated) if e.updated
    out['channel_last_updated_822'] = rfc822(e.updated) if e.updated
    out['channel_last_updated_iso'] = rfc3399(e.updated) if e.updated
    out['channel_link'] = string(e.source.link) if e.source.link
    out['channel_logo'] = string(e.source.logo) if e.source.logo
    out['channel_message'] = string(e.source.message) if e.source.message
    out['channel_name'] = string(e.source.name) if e.source.name
    out['channel_rights'] = string(e.source.rights) unless e.source.rights.size == 0
    out['channel_subtitle'] = string(e.source.subtitle) unless e.source.subtitle.size == 0
    out['channel_title'] = string(e.source.title) unless e.source.title.size == 0
    out['channel_title_plain'] = plain(e.source.title) unless e.source.title.size == 0
    out['content'] = string(e.description) if e.description.size != 0
    out['content'] = string(e.summary[0].value) if e.summary[0].value rescue nil
    out['content'] = string(e.content[0].value) if e.content[0].value rescue nil
    out['content_language'] = string(e.content[0].language) if e.content[0].language rescue nil
    out['date'] = planet_date(e.published) if e.published
    out['date'] = planet_date(e.updated) if e.updated
    out['date_822'] = rfc822(e.published) if e.published
    out['date_822'] = rfc822(e.updated) if e.updated
    out['date_iso'] = rfc3399(e.published) if e.published 
    out['date_iso'] = rfc3399(e.updated) if e.updated
    out['description'] = string(e.description) if e.description.size != 0
    out['enclosure_href'] = string(e.enclosure_href) if e.enclosure_href
    out['enclosure_length'] = string(e.enclosure_length) if e.enclosure_length
    out['enclosure_type'] = string(e.enclosure_type) if e.enclosure_type
    out['id'] = string(e.id) if e.id
    out['link'] = string(e.link) if e.link
    out['new_channel'] = string(e.source.id) if e.source.id
    out['new_date'] = new_date(e.published) if e.published
    out['new_date'] = new_date(e.updated) if e.updated
    out['published'] = planet_date(e.published) if e.published
    out['published_822'] = rfc822(e.published) if e.published
    out['published_iso'] = rfc3399(e.published) if e.published
    out['rights'] = string(e.rights) unless e.rights.size == 0
    out['source'] = string(e.source.name) if e.source.name
    out['summary_language'] = string(e.summary_detail.language) if e.summary_detail.language rescue nil
    out['title'] = string(e.title) unless e.title.size == 0
    out['title_language'] = string(e.title_detail.language) if e.title_detail.language rescue nil
    out['title_plain'] = plain(e.title) unless e.title.size == 0
    out['updated'] = planet_date(e.updated) if e.updated
    out['updated_822'] = rfc822(e.updated) if e.updated
    out['updated_iso'] = rfc3399(e.updated) if e.updated
    return out
  end

  def haml_info(source)
    # Get template information from harvest output

    config = Planet.config['Planet']

    # Add feed and items attributes using harvest
    doc = Planet.add_attrs(source)
    doc.attributes['xml:base'] = 'http://127.0.0.1:8097/'

    # apply mapping rules to convert harvest UserDict to haml input
    output = {'channels' => [], 'items' => []}
    
    doc.feed.sources.each { |f| output['channels'] << map_feed(f) }

    output['channels'].sort! { |a, b|  a['name'] <=> b['name'] rescue 0 }

    doc.entries.each { |e| output['items'] << map_entry(e) }

    # synthesize isPermaLink attribute
    output['items'].each { |item|
        if item['id'] == item['link']
            item['guid_isPermaLink']='true'
        else
            item['guid_isPermaLink']='false'
        end
    }

    # feed level information
    output['generator'] = config['generator_uri']
    output['name'] = config['name']
    output['link'] = config['link']
    output['owner_name'] = config['owner_name']
    output['owner_email'] = config['owner_email']
    if config['feed']
      output['feed'] = config['feed']
      output['feedtype'] = config['feed'].include?('rss') ? 'rss' : 'atom'
    end

    # date/time information
    date = Time.now.getgm.to_s
    output['date'] = planet_date(date)
    output['date_iso'] = rfc3399(date)
    output['date_822'] = rfc822(date)

    # remove new_dates and new_channels that aren't "new"
    date = channel = nil
    output['items'].each { |item|
        if item.has_key? 'new_date'
            if item['new_date'] == date
                item.delete('new_date')
            else
                date = item['new_date']
            end
        end

        if item.has_key? 'new_channel'
            if item['new_channel'] == channel and not item.has_key? 'new_date'
                item.delete('new_channel')
            else
                channel = item['new_channel']
            end
        end
    }
                    
    return output      
  end

  def process stylesheet, feed

    # convert a string stylesheet to a file
    if stylesheet.index('%')
      require 'tempfile'
      file = Tempfile.open("style")
      begin
        file.write(stylesheet)
        file.close
        return process(file.path, feed)
      ensure
        file.unlink
      end
    end

    # process a feed using a haml template
    template = open(stylesheet).read
    haml_engine = Haml::Engine.new(template)
    context = haml_info(feed)
    return haml_engine.to_html(Object.new, context)
  end
    
# Methods for debugging
#
  def print_doc(doc)
    formatter = REXML::Formatters::Pretty.new( 2 )
    xml_file = File.open( "dump.xml", "a" )
    formatter.write( doc, xml_file )
  end

  def dump_feed f
    result = "------------------------------\n"
    result << "Investigating feed, class #{f.class}\n" 
    result << "author: #{f['author']}\n" if f['author']
    result << "author_name: #{f['author_name']}\n" if f['author_name']
    result << "icon: #{f['icon']}\n" if f['icon']
    result << "id: #{f['id']}\n" if f['id']
    result << "last_updated: #{f['last_updated']}\n"   if f['last_updated']
    result << "last_updated_822: #{f['last_updated_822']}\n" if f['last_updated_822']
    result << "last_updated_iso: #{f['last_updated_iso']}\n" if f['last_updated_iso']
    result << "link: #{f['link']}\n" if f['link']
    result << "logo: #{f['logo']}\n" if f['logo']
    result << "message: #{f['message']}\n" if f['message']
    result << "name: #{f['name']}\n" if f['name']
    result << "rights: #{f['rights']}\n" if f['rights']
    result << "subtitle: #{f['subtitle']}\n" if f['subtitle']
    result << "title: #{f['title']}\n" if f['title']
    result << "title_plain: #{f['title']}\n" if f['title']
    result << "................................\n\n"
    return result
  end

  def dump_entry e
    result = "------------------------------\n"
    result << "Investigating entry, class #{e.class}\n" 
    result << "author: #{e['author']}\n" if e['author']
    result << "author_name: #{e['author_name']}\n" if e['author_name']
    result << "author_email: #{e['author_email']}\n" if e['author_email']
    result << "author_uri: #{e['author_uri']}\n" if e['author_uri']
    result << "channel_author: #{e['channel_author']}\n" if e['channel_author']
    result << "channel_author_name: #{e['channel_author_name']}\n" if e['channel_author_name']
    result << "channel_icon: #{e['channel_icon']}\n" if e['channel_icon']
    result << "channel_id: #{e['channel_id']}\n" if e['channel_id']
    result << "channel_last_updated: #{e['channel_last_updated']}\n" if e['channel_last_updated']
    result << "channel_last_updated_822: #{e['channel_last_updated_822']}\n" if e['channel_last_updated_822']
    result << "channel_last_updated_iso: #{e['channel_last_updated_iso']}\n" if e['channel_last_updated_iso']
    result << "channel_link: #{e['channel_link']}\n" if e['channel_link']
    result << "channel_logo: #{e['channel_logo']}\n" if e['channel_logo']
    result << "channel_message: #{e['channel_message']}\n" if e['channel_message']
    result << "channel_name: #{e['channel_name']}\n" if e['channel_name']
    result << "channel_rights: #{e['channel_rights']}\n" if e['channel_rights']
    result << "channel_subtitle: #{e['channel_subtitle']}\n" if e['channel_subtitle']
    result << "channel_title: #{e['channel_title']}\n" if e['channel_title']
    result << "channel_title_plain: #{e['channel_title']}\n" if e['channel_title']
    result << "content: #{e['content']}\n" if e['content']
    result << "content_language: #{e['content_language']}\n" if e['content_language']
    result << "date: #{e['published']}\n" if e['published']
    result << "date: #{e['updated']}\n" if e['updated']
    result << "date_822: #{e['date_822']}\n" if e['date_822']
    result << "date_iso: #{e['date_iso']}\n" if e['date_iso']
    result << "description: #{e['description']}\n" if e['description']
    result << "enclosure_href: #{e['enclosure_href']}\n" if e['enclosure_href']
    result << "enclosure_length: #{e['enclosure_length']}\n" if e['enclosure_length']
    result << "enclosure_type: #{e['enclosure_type']}\n" if e['enclosure_type']
    result << "id: #{e['id']}\n" if e['id']
    result << "link: #{e['link']}\n" if e['link']
    result << "new_channel: #{e['new_channel']}\n" if e['new_channel']
    result << "new_date: #{e['new_date']}\n" if e['new_date']
    result << "published: #{e['published']}\n" if e['published']
    result << "published_822: #{e['published_822']}\n" if e['published_822']
    result << "published_iso: #{e['published_iso']}\n" if e['published_iso']
    result << "rights: #{e['rights']}\n" if e['rights']
    result << "source: #{e['source']}\n" if e['source']
    result << "summary_language: #{e['summary_language']}\n" if e['summary_language']
    result << "title: #{e['title']}\n" if e['title']
    result << "title_language: #{e['title_language']}\n" if e['title_language']
    result << "title_plain: #{e['title']}\n" if e['title']
    result << "updated: #{e['updated']}\n"   if e['updated']
    result << "updated_822: #{e['updated_822']}\n" if e['updated_822']
    result << "updated_iso: #{e['updated_iso']}\n" if e['updated_iso']
    result << "................................\n\n"
    return result
  end
end
