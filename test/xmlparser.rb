require 'test/unit'
require 'planet/xmlparser'

# p REXML::VERSION, PLATFORM

class XmlParserTestCase < Test::Unit::TestCase
  def test_102
    # http://www.germane-software.com/projects/rexml/ticket/102
    doc = Planet::XmlParser.parse('<doc xmlns="ns"><item name="foo"/></doc>')
    assert doc.root.elements["item[@name='foo']"]
  end

  def test_122
    # http://www.germane-software.com/projects/rexml/ticket/122
    doc = Planet::XmlParser.parse('<e a="&amp;"/>')
    assert_nil doc.to_s.index('&amp;amp;')
  end
end
