require 'test/unit'
require 'planet/xmlparser'
require 'planet/sift'

class SiftTestCase < Test::Unit::TestCase
  ATOMNS = 'xmlns="http://www.w3.org/2005/Atom"'

  def test_empty_formatting_elements
    # http://github.com/bronson/mars/commit/775bc2a397c7812ae67b9979f288c3c835aab059
    title = "<title type='html' #{ATOMNS}>&lt;i/&gt;</title>"
    doc = Planet::XmlParser.parse(title)
    Planet.sift doc, nil
    div = doc.at('//xhtml:div', 'xhtml' => 'http://www.w3.org/1999/xhtml')
    assert_equal '<i></i>', div.children.to_a.join
  end
end
