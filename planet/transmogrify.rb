require 'planet/xmlparser'

module Planet
  class Transmogrify
    # ensure that feed elements can't cause arbitrary methods to be called
    instance_methods.each do |name|
      undef_method name unless name =~ /^__/ or name == :object_id
    end

    NAMESPACES = {
      '' => 'rss',
      'http://www.w3.org/1999/xhtml' => 'xhtml',
      'http://www.w3.org/2005/Atom' => 'atom',
      'http://purl.org/dc/elements/1.1/' => 'dc',
      'http://purl.org/rss/1.0/modules/content/' => 'content',
      'http://web.resource.org/cc/' => 'cc',
      'http://search.yahoo.com/mrss/' => 'media',
      'http://backend.userland.com/creativeCommonsRssModule' => 'creativeCommons',
    }

    def Transmogrify.parse(source)
      doc = XmlParser.parse(source)

      source = nil
      class << doc
        attr_accessor :version
      end

      # determine the version
      root = doc.root || doc
      doc.version = 'unknown'
      if root.name == 'feed'
        if root.namespace == 'http://www.w3.org/2005/Atom'
          doc.version = 'atom10'
        else
          doc.version = 'atom'
        end
      elsif root.name == 'rss'
        case root.attributes['version']
        when /^2\./
          doc.version = 'rss20'
        when /^0\.9([234])/
          doc.version = "rss09#{$1}"
        when /^0\.91/
          if doc.doctype.to_s.index('netscape')
            doc.version = "rss091n"
          else
            doc.version = "rss091u"
          end
        else
          doc.version = 'rss'
        end

        root.delete_attribute('version')
        root.attributes['xmlns'] = '' if root.attributes['xmlns']
      end

      process(doc, Transmogrify.new)
      root.attributes['xmlns'] = 'http://www.w3.org/2005/Atom'
      doc
    end

    def Transmogrify.process(node, catalyst)
      method = "#{NAMESPACES[node.namespace] || '?'}_#{node.name}".to_sym
      begin
        catalyst.__send__ method, node
      rescue NoMethodError
      end
      node.elements.each {|child| process(child, catalyst)}
    end

    def rss_rss node
      node.name = 'feed'
      channel = node.elements['channel']
      if channel
        node.children.each {|child| node.delete(child)}
        channel.children.each {|child| node.add(child)}
      end
    end
    alias :rss_channel :rss_rss

    def rss_item node
      node.name = 'entry'
    end

    def rss_description node
      if node.parent.name == 'feed'
        node.name = 'subtitle'
      else
        if node.parent.elements['summary']
          node.name = 'content'
        else
          node.name = 'summary'
        end
        node.attributes['type'] = 'html'
      end

      if node.elements.to_a != []
        node.attributes['type'] = 'xhtml'
        div = REXML::Element.new('div')
        div.add_namespace('http://www.w3.org/1999/xhtml')
        node.children.each {|child| div << child}
        node << div
      end
    end
    alias :dc_description :rss_description

    def content_encoded node
      node.name = 'content'
      node.attributes['type'] = 'html'
    end

    def rss_fullitem node
      node.name = 'content'
      node.attributes['type'] = 'html'
    end

    def rss_guid node
      node.name='id'

      permalink = 'true'
      node.attributes.each do |name,value|
        permalink = value if name.downcase=='ispermalink'
      end

      if permalink.downcase != 'false'
        if not node.parent.elements['link']
          link = node.parent.add_element('link')
          link.attributes['href'] = node.texts.map {|t| t.value}.join
        end
      end

      node.attributes.delete_if {|name,value| name.downcase == 'ispermalink'}
    end

    def rss_link node
      node.name = 'link'
      if node.text and not node.attributes['href']
        node.attributes['href'] = node.texts.map {|t| t.value}.join
        node.children.each {|child| node.delete(child)}
      end
    end

    def rss_comments node
      rss_link node
      node.attributes['rel'] = 'replies'
      node.attributes['type'] = 'text/html'
    end

    def rss_enclosure node
      node.name = 'link'
      node.attributes['rel'] = 'enclosure'
      if node.attributes['url']
        node.attributes['href'] = node.attributes['url']
        node.delete_attribute('url')
      end
    end

    def creativeCommons_license node
      rss_link node
      node.attributes['rel'] = 'license'
    end

    def cc_license node
      creativeCommons_license node
      if node.attributes['rdf:resource']
        node.attributes['href'] = node.attributes['rdf:resource']
        node.delete_attribute('rdf:resource')
      end
    end

    def rss_category node
      node.name = 'category'
      node.attributes['term'] = node.texts.map {|t| t.value}.join
      if node.attributes['domain']
        node.attributes['scheme'] = node.attributes['domain']
        node.delete_attribute('domain')
      end
      node.children.each {|child| child.remove}
    end
    alias :dc_subject :rss_category

    def rss_copyright node
      node.name = 'rights'
    end
    alias :dc_rights :rss_copyright

    def rss_pubDate node
      node.name = 'published'
    end

    def dc_date node
      node.name = 'updated'
    end
    alias :rss_lastBuildDate :dc_date

    def dc_title node
      node.name='title'
    end

    def xhtml_body node
      node.name = 'content'
      node.delete_attribute('xmlns') if node.attributes['xmlns']
      node.attributes['type'] = 'xhtml'
      div = REXML::Element.new('div')
      div.add_namespace('http://www.w3.org/1999/xhtml')
      node.children.each {|child| div << child}
      node << div
    end

    def rss_author node
      node.name = 'author'
      name = node.texts.map {|t| t.value}.join.strip
      email = nil
      if /([\w._%+-]+@[A-Za-z][\w.-]+)\s+\((.*)\)/ =~ name
        email, name = $1, $2
      elsif /(.*?)\s+\(([\w._%+-]+@[A-Za-z][\w.-]+)\)/ =~ name
        name, email = $1, $2
      elsif /([\w._%+-]+@[A-Za-z][\w.-]+)\s+<(.*)>/ =~ name
        email, name = $1, $2
      elsif /(.*?)\s+<([\w._%+-]+@[A-Za-z][\w.-]+)>/ =~ name
        name, email = $1, $2
      elsif /([\w._%+-]+@[A-Za-z][\w.-]+)/ =~ name
        email = $1
        name.sub!($1, '')
      end
      node.children.each {|child| node.delete(child)}
      node.add_element('name').add_text(name)
      node.add_element('email').add_text(email) if email
    end
    alias :dc_author :rss_author
    alias :dc_creator :rss_author
    alias :dc_publisher :rss_author
    alias :rss_managingEditor :rss_author
    alias :rss_webMaster :rss_author

    def dc_contributor node
      rss_author node
      node.name = 'contributor'
    end

    def atom_url node
      node.name = 'uri'
    end

    def atom_content node
      # fixup miscoded 'html' text constructs
      if node.attributes['type'] == 'html'
        if !node.elements.empty?
          if node.elements.map {|child| child.name} == ['div'] and
            node.elements[1].elements.empty?

            # hoist HTML content outside of div
            node.elements[1].children.each {|child| node.add(child)}
            node.delete_element 1
          else
            node.attributes['type'] == 'xhtml'
          end
        end
      end
    end
  end
end
