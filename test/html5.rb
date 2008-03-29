require 'test/unit'

class Html5TestCase < Test::Unit::TestCase
  def test_parse_fragment
    require 'html5'
    assert_equal [], HTML5.parse_fragment('')
  end
end
