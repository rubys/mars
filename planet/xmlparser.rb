require 'nokogiri'

module Planet
  module XmlParser
    def self.parse source, encoding='utf-8', uri=nil
      Nokogiri::XML(source, uri, encoding)
    end

    def self.fragment source
      Nokogiri::HTML.fragment(source)
    end
  end

  # add a convenience method for computing the xml:base for any given Element
  if not Nokogiri::XML::Node.public_instance_methods.include? "base_uri"
    class Nokogiri::XML::Node
      def base_uri
        base = attribute_with_ns('base','http://www.w3.org/XML/1998/namespace')
        if not base
          parent.base_uri
        elsif parent != document
          Planet::uri_norm(parent.base_uri, base.value)
        else
          base.value
        end
      end
    end
  end
end
