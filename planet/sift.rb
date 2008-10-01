require 'planet/fido'
require 'planet/log'
require 'html5'
require 'html5/sanitizer'

module Planet
  def Planet.sift node, fido
    unique = {}

    node.elements.each do |child|
      next unless child.namespace == 'http://www.w3.org/2005/Atom'
      child.attributes.delete("xmlns:#{child.prefix}")
      child.name = child.name # remove prefix

      # remove, merge, or allow through duplicate children
      if unique.has_key? child.name
        case child.name
        when 'author'
          unique['author'].elements.each {|prevnode|
            next unless prevnode.text
            curnode = child.elements[prevnode.name]
            if not curnode
              child.add prevnode
            elsif not curnode.text
              curnode.text = prevnode.texts.map {|t| t.value}.join
            end
          }
          unique[child.name].remove
        when 'entry', 'category', 'contributor', 'link'
        else
          unique[child.name].remove
        end
      end

      unique[child.name] = child

      # node specific canonicalization
      case child.name
      when 'content', 'rights', 'subtitle', 'summary', 'title'
        make_absolute child, 'src'

        if child.attributes['type'] == 'html'
          text = child.texts.map {|t| t.value}.join.strip
          child.children.each {|text_node| text_node.remove}
          div = child.add_element('div')
          div.add_namespace 'http://www.w3.org/1999/xhtml'
          HTML5.parse_fragment(text, :encoding => 'UTF-8').each do |frag|
            div.add(frag)
          end
          child.attributes['type'] = 'xhtml'
        end

        if child.attributes['type'] == 'xhtml'
          child.elements.each {|xhtml_element| sanitize xhtml_element, fido}
        end

      when 'category'
        make_absolute child, 'scheme'
      when 'link'
        make_absolute child, 'href'
        child.attributes['rel'] = 'alternate' unless child.attribute('rel')
      when 'icon', 'logo', 'uri'
        value = child.texts.map {|t| t.value}.join
        if !value.empty? and value != 'http://'
          value = uri_norm(child.xmlbase, value)
          child.children {|text_node| text_node.remove}
          child.text = value
        else
          child.remove
        end
      when 'generator'
        make_absolute child, 'uri'
      when 'published', 'updated'
        # convert dates to RFC 3339
        if child.text
          text = child.texts.map {|t| t.value}.join
          child.children.each {|text_node| text_node.remove}
          child.text = DateTime.parse(text).to_s
        end

        # at the feed/source level, there is no published element
        if child.name == 'published' and node.name != 'entry'
          node.elements['updated'] ? child.remove : child.name = 'updated'
        end
      when 'author', 'email', 'entry', 'feed', 'id', 'name', 'source'
      else
        child.add_namespace('http://planet.intertwingly.net/unknown')
      end

      sift child, fido

    end

    # ensure required elements are present
    if %w(entry feed source).include? node.name
      if !unique.has_key? 'title'
        node << REXML::Element.new('title')
      end

      if !unique.has_key? 'id'
        link = node.elements['link[@rel="alternate"]/@href']
        if link
          id = node.add_element('id')
          id.text = link.value
        end
      end
    end
  end

  # resolve a relative URI attribute
  def Planet.make_absolute node, attr_name
    value = node.attributes[attr_name]
    return unless value
    value = uri_norm(node.xmlbase, value) rescue value
    node.attributes[attr_name] = value
  end

  # remove suspect markup, styles, uris
  include HTML5::HTMLSanitizeModule
  @sanitizer = HTML5::HTMLSanitizer.new ''
  def Planet.sanitize node, fido
    # ensure that non-void elements don't use XML's empty element syntax
    if node.elements.size == 0 && node.text == nil
      node.text = '' unless HTML5::VOID_ELEMENTS.include? node.name
    end

    node.elements.each {|child| sanitize child, fido}

    if node.namespace == 'http://www.w3.org/1999/xhtml'
      elist = ACCEPTABLE_ELEMENTS
      alist = ACCEPTABLE_ATTRIBUTES
    elsif node.namespace == 'http://www.w3.org/2000/svg'
      elist = SVG_ELEMENTS
      alist = SVG_ATTRIBUTES
    elsif node.namespace == 'http://www.w3.org/1998/Math/MathML'
      elist = MATHML_ELEMENTS
      alist = MATHML_ATTRIBUTES
    else
      elist = []
      alist = []
    end

    if !elist.include? node.name

      # inline svg objects
      if node.name=='object' and node.attributes['type']=='image/svg+xml'
        begin
          uri = Planet::uri_norm(node.attributes['data'])
          response = fido.fetch(uri)
          response = fido.read_from_cache(uri) if response.code == '304'
          svg = REXML::Document.new(response.body).root
          node.parent.insert_after node, svg
          svg.elements.each {|child| sanitize child, fido}
          fido.write_to_cache node.attributes['data'], response
          node.name = 'script' # make sure that children are eaten
        rescue Exception => e
          Planet.log.error e.inspect
          Planet.log.error uri
          e.backtrace.each {|line| Planet.log.error line}
        end
      end

      # retain children from bogus elements, except for truly evil ones 
      if !%w[script applet style].include? node.name
        node.children.reverse.each {|child| node.next_sibling=child}
      end

      node.remove
    else
      node.attributes.each_value do |attribute|
        if !alist.include? attribute.expanded_name
          if attribute.expanded_name == 'style'
            node.add_attribute attribute.expanded_name,
              @sanitizer.sanitize_css(attribute.value)
          elsif attribute.name != 'xmlns'
            attribute.remove
          end
        elsif ATTR_VAL_IS_URI.include? attribute.expanded_name
          begin
            value = Addressable::URI.join(node.xmlbase, attribute.value)
            if ACCEPTABLE_PROTOCOLS.include? value.scheme
              node.add_attribute attribute.expanded_name, value.normalize.to_s
            else
              attribute.remove
            end
          rescue
            attribute.remove
          end
        end
      end
    end
  end

  # add a convenience method for computing the xml:base for any given Element
  if not REXML::Element.public_instance_methods.include? "xmlbase"
    class REXML::Element
      def xmlbase
        if not attribute('xml:base')
          parent.xmlbase
        elsif parent
          Planet::uri_norm(parent.xmlbase, attribute('xml:base').value)
        else
          attribute('xml:base').value || ''
        end
      end
    end
  end

end
