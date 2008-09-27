require 'planet/formatter'

  class XsltFormatter < PlanetFormatter
    begin
      # http://greg.rubyfr.net/pub/packages/ruby-xslt/files/README.html
      require 'xml/libxslt'
      @@processor = :libxslt
    rescue LoadError
      @@processor = :xsltproc
    end

    def process stylesheet, doc
      if @@processor == :libxslt

        translate = XML::XSLT.new
        translate.xml = doc
        translate.xsl = stylesheet
        translate.serve

      else

        if stylesheet.index('<')
          require 'tempfile'
          file = Tempfile.open("style")
          begin
            file.write(stylesheet)
            file.close
            return process(file.path, doc)
          ensure
            file.unlink
          end
        end

        require 'open3'
        result = Open3.popen3("xsltproc #{stylesheet} -") do |pin, pout, perr|
          terr = Thread.new {STDERR.puts perr.readline until perr.eof?}
          tout = Thread.new {pout.read}
          doc.write pin
          pin.close
          terr.join
          tout.value
        end

      end
    end

  end
