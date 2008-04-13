require 'test/unit'
require 'planet/harvest'
require 'planet/config'
require 'planet/hamlformatter'


H_FILES = [ 'haml/*', 'haml/*.ini'] 
H_FILES.map! {|name| name.index('.') ? name : name+".xml"}
H_TESTS = H_FILES.map {|arg| Dir[File.join('test/data/filter',arg)]}

# test cases are in Python syntax, convert to something that eval will accept
class TestCaseConverter
  def self.python2ruby(expr, source)
    # unicode strings
    expr.gsub! " u'", " '"
    expr.gsub! ' u"', ' "'

    # triple strings
    expr.gsub! /"""(.*?)"""/, '%q{\1}'

    # dict to hash
    expr.gsub! "': '", "' => '"

    # const to variable
    expr.gsub! "Items[", "items["
    expr.gsub! "Channels[", "channels["

    # true
    expr = "true" if expr == "1"

    # differences in XML/URI serializations
    name = source.split('/').last.split('.').first
    expr.sub!('&quot;','%22') if name == 'missing_quote_in_attr'
    expr.sub! '&gt;', '>' if name == 'tag_in_attr'
    expr.gsub!('"', "\\\\'").gsub!('&quot;','"') if name == 'quote_in_attr'

    expr
  end
end

require 'planet/formatter'

# Add a method for comparing a UserDict with a Python
module Planet
  class UserDict
    def == dict
      dict == Hash[*dict.keys.map {|key| [key,self[key]]}.flatten]
    end
    def has_key key
      send key rescue false
    end
  end
end

class HamlTestCase < Test::Unit::TestCase
  H_TESTS.flatten.each do |file|
    name = file.split('.').first.split('/')[-3..-1].join('_')
    define_method "test_#{name}" do
      testdata = open(file).read

      case testdata
        # for .xml files
        when /Description:\s*(.*?)\s*Expect:\s*(.*)\s*/
          desc = TestCaseConverter.python2ruby($2, file)
          doc = Planet.harvest(file)
          output = HamlFormatter.new.haml_info(doc)
          channels = output['channels']
          items = output['items'] if output['items']

        # for .ini files... any xml will do
        when /Description:\s*(.*?)\s*; Expect:\s*(.*)\s*/
          desc = TestCaseConverter.python2ruby($2, file)
          Planet.config.read file
          doc = Planet.harvest('test/data/filter/haml/new_channel.xml')
          output = HamlFormatter.new.haml_info(doc)
 
          # copy haml hash to environment
          feed = output['feed']
          feedtype = output['feedtype']
          generator = output['generator_uri']
          link = output['link']
          name = output['name']
          owner_email = output['owner_email']
          owner_name = output['owner_name']
        else
          raise Exception.new('testcase parse error')
        end

      test_result = eval desc 
      assert_equal true, test_result, message=desc
    end
  end
end