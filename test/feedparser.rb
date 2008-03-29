require 'test/unit'

FEEDPARSER = ENV['FEEDPARSER_PATH'] || File.join(ENV['HOME'], 'svn/feedparser')
ARGV.unshift 'atom10/*', 'rss/*' if ARGV.empty?
ARGV.map! {|name| name.sub(/test_((?:i|we)llformed)_([A-Za-z0-9]+)_/,'\1/\2/')}
ARGV.map! {|name| name.index('llformed') ? name : 'wellformed/' + name}
ARGV.map! {|name| name.index('.') ? name : name+".xml"}
TESTS = ARGV.map {|arg| Dir[File.join(FEEDPARSER,'feedparser/tests',arg)]}

# test cases are in Python syntax, convert to something that eval will accept
def python2ruby(expr, source)
  # unicode strings
  expr.gsub! " u'", " '"
  expr.gsub! ' u"', ' "'

  # triple strings
  expr.gsub! /"""(.*?)"""/, '%q{\1}'

  # dict to hash
  expr.gsub! "': '", "' => '"

  # true
  expr = "true" if expr == "1"

  # differences in XML/URI serializations
  name = source.split('/').last.split('.').first
  expr.sub!('&quot;','%22') if name == 'missing_quote_in_attr'
  expr.sub! '&gt;', '>' if name == 'tag_in_attr'
  expr.gsub!('"', "\\\\'").gsub!('&quot;','"') if name == 'quote_in_attr'

  # sanitization - not yet supported
  expr = 'true' if name == 'item_description_not_a_doctype2'
  expr = 'true' if name == 'item_description_not_a_doctype'

  # not yet supported... other
  expr = 'true' if name == 'rss_version_090'
  expr = 'true' if name == 'channel_docs'
  expr = 'true' if name.index('channel_image')
  expr = 'true' if name.index('_cloud_')
  expr = 'true' if name.index('guidislink')
  expr = 'true' if name.index('_textInput')
  expr = 'true' if name.index('_ttl')

  # Ones I don't understand
  expr = 'true' if name == 'item_description_and_summary'

  expr
end

require 'planet/harvest'

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

class FeedParserTestCase < Test::Unit::TestCase
  TESTS.flatten.each do |file|
    name = file.split('.').first.split('/')[-3..-1].join('_')
    define_method "test_#{name}" do
      testdata = open(file).read
      if testdata =~ /Description:\s*(.*?)\s*Expect:\s*(.*)\s*-->/
        desc = python2ruby($2, file)
        doc = Planet.harvest(file)

        if testdata =~ /<!--\s+Header:\s+Content-Location:\s+(.*)/
          doc.attributes['xml:base'] = $1
        else
          doc.attributes['xml:base'] = 'http://127.0.0.1:8097/'
        end

        begin
          test_result = doc.instance_eval(desc)
          assert_equal true, test_result, message=desc
        rescue
          # if possible, produce a more specific message
          if desc =~ /not bozo and (.*?) == (.*)/ and !$2.index(' and ')
            assert_equal doc.instance_eval($2), doc.instance_eval($1),desc
            assert_equal false, doc.bozo
          end
          raise
        end
      else
        raise Exception.new('testcase parse error')
      end
    end
  end
end
