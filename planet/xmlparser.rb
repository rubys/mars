require 'rexml/document'
require 'html5/liberalxmlparser'

module Planet
  module XmlParser
    begin
      require 'xml/parser' # http://www.yoshidam.net/xmlparser_en.txt
      @@parser = :expat
    rescue LoadError
      begin
        require 'xml/libxml' # http://libxml.rubyforge.org/
        @@parser = :libxml2
      rescue LoadError
        @@parser = :rexml
      end
    end

    def XmlParser.parse source
      source = source.read if source.respond_to? :read

      begin
        case @@parser
        when :expat
          # fast, compliant, but not always installed
          doc = XmlParser.expat source
        when :libxml2
          # also fast, compliant, but not always installed
          doc = XmlParser.libxml2 source
        else
          # fairly fast, fairly compliant, always available
          doc = REXML::Document.new source
        end
        bozo = false
      rescue Exception => e
        # If everything is being bozo'd, enable this to see why.
        # print "PARSE ERROR: #{$!}\n  #{$!.backtrace.join("\n  ")}\n"

        # last ditch attempt: use a liberal XML parser
        parser = HTML5::XMLParser.new
        doc = REXML::Document.new
        parser.parse_fragment(source).each {|node| doc << node rescue nil}
        bozo = true
      end

      # augment the document with feed parser attributes
      source = nil
      class << doc
        attr_accessor :bozo
      end
      doc.bozo = bozo

      doc
    end

    def XmlParser.expat source
      parser = XML::Parser.new
      class <<parser
        # enable additional events
        attr_accessor :startDoctypeDecl
        attr_accessor :comment
      end

      doc = REXML::Document.new
      node = doc

      parser.parse(source) do |type, name, data|
        case type
        when XML::Parser::START_ELEM
          # name = element name  ; data = hash of attributes
          node = node.add_element(name)
          data.each {|name,value| node.add_attribute(name,value)}

        when XML::Parser::END_ELEM
          # name = element name  ; data = nil
          node = node.parent

        when XML::Parser::CDATA
          # name = nil           ; data = string
          node.add_text(data)

        when XML::Parser::COMMENT
          # name = nil           ; data = string
          REXML::Comment.new(data,node)

        when XML::Parser::START_DOCTYPE_DECL
          # name = notation name ; data = [URL base, system ID, public ID]
          REXML::DocType.new([name, data[2] ? 'SYSTEM' : 'PUBLIC',
            data[1].inspect, data[0].inspect], node)
        end
      end

      parser.done

      doc
    end

    if @@parser==:libxml2
      if !XML::SaxParser.const_defined?(:Callbacks)
        # shim to upgrade libxml 0.3.8.4 to the 0.5.2.0 interface
        class XML::SaxParser
          module Callbacks
          end

          def callbacks= callback
            callback.methods.grep(/^on_/).each do |method|
              send(method) { |*args| callback.send method, *args }
            end
          end
        end
      end

      class Callbacks

        include XML::SaxParser::Callbacks

        def initialize(node)
          @node = node
        end

        def on_start_element(name, attrs)
          @node = @node.add_element(name)
          attrs.each {|key,value| @node.add_attribute(key,value)}
        end

        def on_end_element(name)
          @node = @node.parent
        end

        def on_characters(chars)
          @node.add_text(chars)
        end

        def on_cdata_block(cdata)
          @node.add_text(cdata)
        end

        def on_comment(data)
          REXML::Comment.new(data,@node)
        end

        def on_parser_error(message)
          raise Exception.new(message)
        end

        def on_parser_fatal_error(message)
          raise Exception.new(message)
        end

        def on_external_subset(name, externalId, systemId)
          REXML::DocType.new([name, 'PUBLIC', externalId.inspect,
            systemId.inspect], @node)
        end
      end
    end

    def XmlParser.libxml2 source
      parser = XML::SaxParser.new

      doc = REXML::Document.new

      parser.string = source
      parser.callbacks = XmlParser::Callbacks.new(doc)
      parser.parse

      doc
    end
  end
end
