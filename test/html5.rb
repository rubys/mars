require 'test/unit'
require 'planet/xmlparser'

class Html5TestCase < Test::Unit::TestCase
  def test_parse_fragment
    assert_equal [], Planet::XmlParser.fragment('').children.to_a
  end
end
