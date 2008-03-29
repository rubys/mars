require 'planet/transmogrify'
require 'planet/sift'

module Planet
  def Planet.harvest source
    doc = Planet::Transmogrify.parse(open(source))
    doc.attributes['xml:base'] = source

    # augment the document with feed parser attributes
    class << doc
      attr_accessor :feed, :entries
    end

    # Anchor the dynamic dictionaries
    doc.feed = Feed.new(doc.root)
    doc.entries = doc.root.elements.to_a('entry').map {|entry| Entry.new(entry)}

    doc
  end

  # A dynamic dictionary that allows attributes to be accessed via indexing
  class UserDict
    attr_accessor :node

    def initialize node
      @node = node || REXML::Element.new('')
    end

    def [](index)
      respond_to?(index) ? send(index) : nil
    end

    # method generator for elements whose value is defined by its text child
    def UserDict.text_element *names
      names.each do |name|
        define_method name do
          element = @node.elements[name.to_s]
          element ? element.texts.map {|t| t.value}.join : nil
        end
      end
    end

    # method generator for element attribute values
    def UserDict.element_attr *names
      names.each do |name|
        define_method name do
          @node.attributes[name.to_s]
        end
      end
    end

    # method generator for relative URI attribute values
    def UserDict.reluri_attr *names
      names.each do |name|
        define_method name do
          value = @node.attributes[name.to_s]
          value = Planet.uri_norm(@node.xmlbase, value) if value
          value
        end
      end
    end

    # method generator for text constructs (plus detail)
    def UserDict.text_construct *names
      names.each do |name|
        define_method name do
          TextConstruct.new(@node.elements[name.to_s]).value
        end

        define_method name.to_s + "_detail" do
          TextConstruct.new(@node.elements[name.to_s])
        end
      end
    end
  end

  class CommonElements < UserDict
    text_element :id
    alias :guid :id

    text_construct :rights
    alias :copyright :rights

    text_construct :title

    def link
      links.select {|link| link.rel=='alternate'}.first.href rescue nil
    end

    def links
      @node.elements.to_a('link').map {|node| Link.new(node)}
    end

    def license
      links.select {|link| link.rel=='license'}.first.href rescue nil
    end

    def tags
      @node.elements.to_a('category').map {|node| Category.new(node)}
    end

    def categories
      tags.map {|tag| [tag.scheme, tag.term]}
    end

    def category
      tags.first.term rescue nil
    end

    def contributors
      @node.elements.to_a('contributor').map {|node| Author.new(node)}
    end

    def categories
      tags.map {|tag| [tag.scheme, tag.term]}
    end

    def category
      tags.first.term rescue nil
    end

    def author
      author_detail.to_s
    end

    def author_detail
      Author.new(@node.elements['author'])
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
      Generator.new(@node.elements['generator'])
    end
  end

  class Entry < CommonElements
    text_construct :summary

    alias :description :summary

    def content
      @node.elements.to_a('content').map {|node| TextConstruct.new(node)}
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
      Feed.new(@node.elements['source'])
    end
  end

  class TextConstruct < UserDict
    require 'html5'
    require 'html5/treewalkers'
    require 'html5/serializer'

    REXML_TREEWALKER = HTML5::TreeWalkers['rexml']

    element_attr :src

    def value
      case @node.attributes['type']
        when 'xhtml'
          serialize(@node.elements[1].to_a).strip
        when 'text', nil, /^text\//i
          (@node.text || '').strip
        when 'html'
          text = @node.text.strip rescue ''
          serialize HTML5.parse_fragment(text, :encoding => 'UTF-8')
        when /\+xml$/i, /\/xml$/i
          @node.to_a.to_s.strip
        else
          # base 64
          @node.text.gsub(/\s/,'').unpack('m').first
      end
    end

    def type
      case @node.attributes['type']
        when 'xhtml'
          'application/xhtml+xml'
        when 'text', nil
          'text/plain'
        when 'html'
          'text/html'
        else
          @node.attributes['type']
      end
    end

    def base
      url_norm(@node.xmlbase)
    end

  private

    # DOM to string
    def serialize nodes
      nodes.map { |node|
        # resolve relative URIs
        if node.respond_to? :attributes
          if !node.parent.parent
            node.parent.attributes['xml:base'] ||= @node.xmlbase
          end
          resolve node if node.respond_to? :attributes
        end

        HTML5::XHTMLSerializer.serialize(REXML_TREEWALKER.new(node))
      }.join
    end

    # resolve relative URIs
    def resolve element
      element.attributes.each do |name,value|
        if %w(href).include? name
          element.attributes[name] =
            Planet.uri_norm(element.xmlbase, value)
        end
      end
      element.each_element { |child| resolve child }
    end
  end

  class Author < UserDict
    text_element :name, :email, :uri

    def uri
      value = @node.elements['uri']
      if value
        value = Planet.uri_norm(value.xmlbase, value.text)
      end
      value
    end

    def to_s
      email ? "#{name} (#{email})" : "#{name}"
    end

    alias :url :uri
    alias :href :uri
  end

  class Link < UserDict
    element_attr :title, :length, :hreflang
    reluri_attr :href

    alias :url :href

    def rel
      @node.attributes['rel'] or 'alternate'
    end

    def type
      @node.attributes['type'] or (rel=='self' ? 'application/atom+xml' : nil)
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
