require 'planet/formatter'

class XsltFormatter
  def process stylesheet, doc
    Nokogiri::XSLT(File.read(stylesheet)).transform(doc)
  end
end
