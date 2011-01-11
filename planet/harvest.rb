require 'planet/transmogrify'
require 'planet/sift'

module Planet
  def Planet.harvest source, fido
    doc = Planet::Transmogrify.parse(open(source))
    doc.root['xml:base'] = source
    Planet.sift doc.root, fido
    Planet.add_attrs(doc)
  end

  # Augment a document with feed parser attributes
  def Planet.add_attrs doc

    class << doc
      attr_accessor :feed, :entries
    end

    # Anchor the dynamic dictionaries
    doc.feed = Feed.new(doc.root)
    doc.entries = doc.root.search('entry').map {|entry| Entry.new(entry)}

    doc
  end

  # A dynamic dictionary that allows attributes to be accessed via indexing
  class UserDict
    attr_accessor :node

    def initialize node
      @node = node || XmlParser.parse('')
    end

    def [](index)
      respond_to?(index) ? send(index) : nil
    end

    # method generator for elements whose value is defined by its text child
    def UserDict.text_element *names
      names.each do |name|
        define_method name do
          element = @node.at(name) if @node
          element ? element.text : nil
        end
      end
    end

    # method generator for element attribute values
    def UserDict.element_attr *names
      names.each do |name|
        define_method name do
          @node[name.to_s]
        end
      end
    end

    # method generator for relative URI attribute values
    def UserDict.reluri_attr *names
      names.each do |name|
        define_method name do
          value = @node[name.to_s]
          value = Planet.uri_norm(@node.base_uri, value) if value
          value
        end
      end
    end

    # method generator for text constructs (plus detail)
    def UserDict.text_construct *names
      names.each do |name|
        define_method name do
          TextConstruct.new(@node.at(name)).value
        end

        define_method name.to_s + "_detail" do
          TextConstruct.new(@node.at(name.to_s))
        end
      end
    end
  end

  class CommonElements < UserDict
    text_element :id, :updated, :published
    alias :guid :id

    text_construct :rights
    alias :copyright :rights

    text_construct :title

    def link
      alternate = links.find {|link| link.rel=='alternate'}
      alternate ? alternate.href : nil
    end

    def links
      @node.search('link').map {|node| Link.new(node)}
    end

    def license
      link = links.first {|link| link.rel=='license'}
      link ? link.href : nil
    end

    def tags
      @node.search('category').map {|node| Category.new(node)}
    end

    def categories
      tags.map {|tag| [tag.scheme, tag.term]}
    end

    def category
      tags.first.term rescue nil
    end

    def authors
      @node.search('author').map {|node| Author.new(node)}
    end

    def contributors
      @node.search('contributor').map {|node| Author.new(node)}
    end

    def author
      author_detail.to_s
    end

    def author_detail
      Author.new(@node.at('author'))
    end

    alias :publisher :author
    alias :publisher_detail :author_detail
  end

  class Feed < CommonElements
    text_element :icon, :logo
    text_construct :subtitle

    alias :description :subtitle
    alias :tagline :subtitle

    def generator
      generator_detail.name
    end

    def generator_detail
      Generator.new(@node.at('generator'))
    end

    def message
      ns = {'planet' => 'http://planet.intertwingly.net/'}
      element = @node.at('//planet:message', ns)
      element ? element.text : nil
    end

    def name
      ns = {'planet' => 'http://planet.intertwingly.net/'}
      element = @node.at('//planet:name', ns)
      element ? element.text : nil
    end
    
    def sources
      ns = {'planet' => 'http://planet.intertwingly.net/'}
      @node.search('//planet:source', ns).map {|node| Feed.new(node)}
    end
    
    def url
      link = links.first {|link| link.rel=='self'}
      link ? link.href : nil
    end
    alias :href :url
  end

  class Entry < CommonElements
    text_construct :summary

    alias :description :summary

    def content
      @node.search('content').map {|node| TextConstruct.new(node)}
    end

    def enclosure_href
      enclosures.first.href rescue nil
    end

    def enclosure_length
      enclosures.first.length rescue nil
    end

    def enclosure_type
      if enclosures.first.is_a?(Planet::Link)
        return enclosures.first.type
      else
        return nil
      end
    end

    def enclosures
      links.select {|link| link.rel == 'enclosure'}
    end

    def comments
      links.select { |link|
        link.rel == 'replies' and link.type == 'text/html'
      }.first.href rescue nil
    end

    def source
      Feed.new(@node.at('source'))
    end
  end

  class TextConstruct < UserDict
    element_attr :src

    def value
      case @node['type']
        when 'xhtml'
          if @node.elements.length == 1 and node.elements.first.name == 'div'
            serialize(@node.elements.first.children).strip
          else
            serialize(@node.children).strip
          end
        when 'text', nil, /^text\//i
          @node.text.to_s.strip
        when 'html'
          text = @node.text.strip
          serialize Planet::XmlParser.fragment(text).children
        when /\+xml$/i, /\/xml$/i
          @node.to_a.to_s.strip
        else
          # base 64
          @node.text.gsub(/\s/,'').unpack('m').first
      end
    end

    def type
      case @node['type']
        when 'xhtml'
          'application/xhtml+xml'
        when 'text', nil
          'text/plain'
        when 'html'
          'text/html'
        else
          @node['type']
      end
    end

    def base
      url_norm(@node.base_uri)
    end

    def language
      @node['lang']
    end

  private

    # DOM to string
    def serialize nodes
      nodes.map { |node| node.to_s }.join
    end
  end

  class Author < UserDict
    text_element :name, :email, :uri

    def uri
      value = @node.at('uri')
      if value
        value = Planet.uri_norm(value.base_uri, value.text)
      end
      value
    end

    def to_s
      if name
        email ? "#{name} (#{email})" : "#{name}"
      else
        "#{email}"
      end
    end

    alias :url :uri
    alias :href :uri
  end

  class Link < UserDict
    element_attr :title, :length, :hreflang
    reluri_attr :href

    alias :url :href

    def rel
      @node['rel'] or 'alternate'
    end

    def type
      @node['type'] or (rel=='self' ? 'application/atom+xml' : nil)
    end
  end

  class Category < UserDict
    element_attr :term, :scheme, :label
  end

  class Generator < UserDict
    element_attr :version
    reluri_attr :uri

    alias :href :uri

    def name
      @node.text
    end
  end
end
