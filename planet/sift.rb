require 'planet/fido'
require 'planet/log'
require 'planet/sanitizer'

module Planet
  def Planet.sift node, fido
    unique = {}
    node.elements.each do |child|
      child.namespace ||= node.namespace
      next unless child.namespace.href == 'http://www.w3.org/2005/Atom' or
                  child.namespace.href == 'http://planet.intertwingly.net/'

      # remove duplicate children
      if unique.has_key? child.name
        unless %w(author entry category contributor link).include? child.name
          unique[child.name].remove
        end
      end

      unique[child.name] = child

      # node specific canonicalization
      case child.name
      when 'content', 'rights', 'subtitle', 'summary', 'title'
        make_absolute child, 'src'

        if child['type'] == 'html'
          text = child.text.strip
          child.children.each {|text_node| text_node.remove}
          div = child.add_child(child.document.create_element('div'))
          div.add_namespace_definition nil, 'http://www.w3.org/1999/xhtml'
          Planet::XmlParser.fragment(text).children.each do |frag|
            div.add_child(frag)
          end
          child['type'] = 'xhtml'
        end

        if child['type'] == 'xhtml'
          child.elements.each {|xhtml_element| sanitize xhtml_element, fido}
        end

      when 'category'
        make_absolute child, 'scheme'
      when 'link'
        make_absolute child, 'href'
        child['rel'] = 'alternate' unless child.attribute('rel')
      when 'icon', 'logo', 'uri'
        value = child.text
        if !value.empty? and value != 'http://'
          value = uri_norm(child.base_uri, value)
          child.children {|text_node| text_node.remove}
          child.content = value
        else
          child.remove
        end
      when 'generator'
        make_absolute child, 'uri'
      when 'published', 'updated'
        # convert dates to RFC 3339
        if child.text
          text = child.text
          child.children.each {|text_node| text_node.remove}
          child.content = DateTime.parse(text).to_s
        end

        # at the feed/source level, there is no published element
        if child.name == 'published' and node.name != 'entry'
          node.at('./updated') ? child.remove : child.name = 'updated'
        end
      when 'author', 'contributor', 'email', 'entry', 'feed',
           'id', 'name', 'source'
      else
        if not child.namespace or child.namespace.href !=
          'http://planet.intertwingly.net/'
          child.namespace = nil
          child.add_namespace(nil, 'http://planet.intertwingly.net/unknown')
        end
      end

      sift child, fido
    end

    # ensure required elements are present
    if %w(entry feed source).include? node.name
      if !unique.has_key? 'title'
        node << node.document.create_element('title')
      end

      if !unique.has_key? 'id'
        link = node.at('./link[@rel="alternate"]/@href')
        if link
          id = node.add_child(node.document.create_element('id'))
          id.text = link.value
        end
      end
    end
  end

  # resolve a relative URI attribute
  def Planet.make_absolute node, attr_name
    value = node[attr_name]
    return unless value
    value = uri_norm(node.xmlbase, value) rescue value
    node[attr_name] = value
  end

  # remove suspect markup, styles, uris
  def Planet.sanitize node, fido
    # ensure that non-void elements don't use XML's empty element syntax
    if node.children.length == 0
      node.content = '' unless Sanitizer::VOID_ELEMENTS.include? node.name
    end

    node.elements.each {|child| sanitize child, fido}

    if !Sanitizer::ALLOWED_ELEMENTS.include? node.name

      # inline svg objects
      if node.name=='object' and node['type']=='image/svg+xml'
        begin
          uri = Planet::uri_norm(node['data'])
          response = fido.fetch(uri)
          response = fido.read_from_cache(uri) if response.code == '304'
          svg = Planet::XmlParse.parse(response.body).root
          node.parent.insert_after node, svg
          svg.elements.each {|child| sanitize child, fido}
          fido.write_to_cache node['data'], response
          node.name = 'script' # make sure that children are eaten
        rescue Exception => e
          Planet.log.error e.inspect
          Planet.log.error uri
          e.backtrace.each {|line| Planet.log.error line}
        end
      end

      # retain children from bogus elements, except for truly evil ones 
      if !%w[script applet style].include? node.name
        node.children.reverse.each {|child| node.add_next_sibling(child)}
      end

      node.remove
    else
      node.attributes.each_value do |attribute|
        expanded_name = attribute.name
        if attribute.namespace
          expanded_name = "#{attribute.namespace.prefix}:#{expanded_name}"
        end

        if not Sanitizer::ALLOWED_ATTRIBUTES.include? expanded_name
          if expanded_name == 'style'
            node.add_attribute expanded_name,
              @sanitizer.sanitize_css(attribute.value)
          elsif attribute.name != 'xmlns'
            attribute.remove
          end
        elsif Sanitizer::ATTR_VAL_IS_URI.include? expanded_name
          # begin
            value = Addressable::URI.join(node.base_uri, attribute.value)
            if Sanitizer::ALLOWED_PROTOCOLS.include? value.scheme
              node[expanded_name] = value.normalize.to_s
            else
              attribute.remove
            end
          # rescue
           #  attribute.remove
          # end
        end
      end
    end
  end

end
