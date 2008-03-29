require 'test/unit'

class AddressableTestCase < Test::Unit::TestCase
  def test_installed
    require 'addressable/uri'
    assert true
  end
end
