require 'planet/xmlparser'

module Planet
  class Transmogrify
    # ensure that feed elements can't cause arbitrary methods to be called
    instance_methods.each do |name|
      undef_method name unless name =~ /^__/ or name == :object_id or
        name.to_sym == :respond_to?
    end

    NAMESPACES = {
      '' => 'rss',
      'http://www.w3.org/1999/xhtml' => 'xhtml',
      'http://www.w3.org/2005/Atom' => 'atom',
      'http://purl.org/dc/elements/1.1/' => 'dc',
      'http://purl.org/rss/1.0/modules/content/' => 'content',
      'http://web.resource.org/cc/' => 'cc',
      'http://search.yahoo.com/mrss/' => 'media',
      'http://search.yahoo.com/mrss' => 'media',
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
        if root.namespace and root.namespace.href=='http://www.w3.org/2005/Atom'
          doc.version = 'atom10'
        else
          doc.version = 'atom'
        end
      elsif root.name == 'rss'
        case root['version']
        when /^2\./
          doc.version = 'rss20'
        when /^0\.9([234])/
          doc.version = "rss09#{$1}"
        when /^0\.91/
          doctype = doc.children.find {|node| node.respond_to? :system_id}
          if doctype and doctype.system_id.include? 'netscape'
            doc.version = "rss091n"
          else
            doc.version = "rss091u"
          end
        else
          doc.version = 'rss'
        end

        root.remove_attribute('version')
        if root.namespace
          cleanup = proc do |node|
            if node.namespace and node.namespace.href == root.namespace.href
              node.namespace = nil 
            end
            node.elements.each {|child| cleanup.call(child)}
          end
          rss = root.document.create_element('rss')
          root.children.each {|child| rss << child; cleanup.call(child)}
          root.replace(rss)
          root = rss
        end

      end

      process(root, Transmogrify.new)

      if not root.namespace
        root.add_namespace(nil, 'http://www.w3.org/2005/Atom') 
      end

      doc
    end

    def Transmogrify.process(node, catalyst)
      namespace = (node.namespace ? node.namespace.href : '')
      method = "#{NAMESPACES[namespace] || '?'}_#{node.name}".to_sym
      if catalyst.respond_to?(method)
        catalyst.__send__ method, node
      else
        if node.namespace
          if node.namespace.prefix
            node["xmlns:#{node.namespace.prefix}"] = node.namespace.href
          end
        end
      end
      node.elements.each {|child| process(child, catalyst)}
    end

    def rss_rss node
      node.name = 'feed'
      channel = node.at('channel')
      if channel
        node.children.each {|child| node.delete(child)}
        channel.children.each {|child| node.add_child(child)}
        channel.remove
      end
    end
    alias :rss_channel :rss_rss

    def rss_item node
      node.name = 'entry'
    end

    def rss_description node
      node.namespace = node.parent.namespace
      if node.parent.name == 'feed'
        node.name = 'subtitle'
      else
        if node.parent.at('summary')
          node.name = 'content'
        else
          node.name = 'summary'
        end
        node['type'] = 'html'
      end

      if node.elements.to_a != []
        node['type'] = 'xhtml'
        div = node.document.create_element('div')
        div.add_namespace(nil, 'http://www.w3.org/1999/xhtml')
        node.children.each {|child| div << child}
        node << div
      end
    end
    alias :dc_description :rss_description

    def content_encoded node
      node.namespace = node.parent.namespace
      node.name = 'content'
      node['type'] = 'html'
    end

    def rss_fullitem node
      node.name = 'content'
      node['type'] = 'html'
    end

    def rss_guid node
      node.name='id'

      permalink = 'true'
      node.attributes.each do |name,attr|
        permalink = attr.value if name.downcase=='ispermalink'
      end

      if permalink.downcase != 'false'
        if not node.parent.at('link')
          link = node.parent.add_child(node.document.create_element('link'))
          link['href'] = node.text
        end
      end

      node.attributes.delete_if {|name,value| name.downcase == 'ispermalink'}
    end

    def rss_link node
      node.namespace = node.parent.namespace
      node.name = 'link'
      if node.text and not node['href']
        node['href'] = node.text
        node.children.each {|child| child.remove}
      end
    end

    def rss_comments node
      rss_link node
      node['rel'] = 'replies'
      node['type'] = 'text/html'
    end

    def rss_enclosure node
      node.name = 'link'
      node['rel'] = 'enclosure'
      if node['url']
        node['href'] = node['url']
        node.remove_attribute('url')
      end
    end

    def creativeCommons_license node
      rss_link node
      node['rel'] = 'license'
    end

    def cc_license node
      creativeCommons_license node
      if node['resource']
        node['href'] = node.remove_attribute('resource').value
      end
    end

    def rss_category node
      node.namespace = node.parent.namespace
      node.name = 'category'
      node['term'] = node.text
      if node['domain']
        node['scheme'] = node['domain']
        node.remove_attribute('domain')
      end
      node.children.each {|child| child.remove}
    end
    alias :dc_subject :rss_category

    def media_category node
      rss_category node
      node['scheme'] ||= 'http://search.yahoo.com/mrss/category_schema'
    end

    def rss_copyright node
      node.namespace = node.parent.namespace
      node.name = 'rights'
    end
    alias :dc_rights :rss_copyright

    def rss_pubDate node
      node.name = 'published'
    end

    def dc_date node
      node.namespace = node.parent.namespace
      node.name = 'updated'
    end
    alias :rss_lastBuildDate :dc_date

    def dc_title node
      node.namespace = node.parent.namespace
      node.name='title'
    end

    def xhtml_body node
      node.name = 'div'
      content = node.document.create_element('content')
      content['type'] = 'xhtml'
      content.namespace = node.parent.namespace
      node.add_next_sibling content
      content.add_child node
    end

    def rss_author node
      node.namespace = node.parent.namespace
      node.name = 'author'
      name = node.text
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
      node.children.each {|child| child.remove}
      node.add_child(node.document.create_element('name')).content = name.strip
      if email
        node.add_child(node.document.create_element('email')).content = email
      end
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
      if node['type'] == 'html'
        if !node.elements.empty?
          if node.elements.map {|child| child.name} == ['div'] and
            node.elements.first.elements.empty?

            # hoist HTML content outside of div
            node.elements.first.children.each {|child| node.add_child(child)}
            node.elements.first.remove
          else
            node['type'] == 'xhtml'
          end
        end
      end
    end

    def rss_source node
      url = node.remove_attribute('url')
      if node.text
        title = node.document.create_element('title')
        title.content = node.text
        node.content = ''
        node.add_child(title)
      end
      if url
        link = node.add_child(node.document.create_element('link'))
        link['href'] = url
        link['rel'] = 'elf'
      end
    end
  end
end
