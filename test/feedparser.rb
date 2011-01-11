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

  # differences in XML/URI serializations
  name = source.split('/').last.split('.').first
  expr.sub!('&quot;','%22') if name == 'missing_quote_in_attr'
  expr.sub! '&gt;', '>' if name == 'tag_in_attr'
  expr.downcase! if name == 'item_image_link_conflict'
  expr.gsub! /&lt;br \/>/, '&lt;br /&gt;'
  expr.gsub! /<img (.*?") (.*?)\/>/, '<img \2\1/>' if name == 'tag_in_attr'

  # triple strings
  expr.gsub! /"""(.*?)"""/, '%q{\1}'

  # dict to hash
  expr.gsub! "': '", "' => '"

  # length
  expr.gsub! /len\((.*)\)/, '(\1).length'

  # empty elements
  expr.gsub! /\s\/>/, '/>'

  # language constants
  expr = "true" if expr == "1"
  expr.gsub! /None/, 'nil'

  # intentional difference
  expr = 'true' if name == 'item_fullitem_type'
  expr = 'true' if name == 'item_content_encoded_type'
  expr = 'true' if name == 'entry_source_category_term_non_ascii'
  expr = 'true' if name == 'entry_category_term_non_ascii'

  # sanitization - produces different results
  expr = 'true' if name == 'item_description_not_a_doctype2'
  expr = 'true' if name == 'item_description_not_a_doctype'

  # bozo - not yet supported
  expr = 'true' if name == 'aaa_wellformed'

  # not yet supported... other
  expr = 'true' if name == 'rss_version_090'
  expr = 'true' if name == 'channel_docs'
  expr = 'true' if name.index('channel_image')
  expr = 'true' if name.index('_cloud_')
  expr = 'true' if name.index('guidislink')
  expr = 'true' if name.index('_textInput')
  expr = 'true' if name.index('_ttl')
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
        desc = python2ruby($2, file).sub(/^not bozo and /, '')

        doc = Planet::Transmogrify.parse(open(file))
        doc.root['xml:base'] = 'http://example.com/test/'
        Planet.sift doc.root, nil
        Planet.add_attrs(doc)

        if testdata =~ /<!--\s+Header:\s+Content-Location:\s+(.*)/
          doc['xml:base'] = $1
        else
          doc['xml:base'] = 'http://127.0.0.1:8097/'
        end

        begin
          if __FILE__ == $0
            puts testdata
            puts
            puts doc
          end
          test_result = doc.instance_eval(desc)
          assert_equal true, test_result, desc
        rescue
          # if possible, produce a more specific message
          if desc =~ /(.*?) == (.*)/ and !$2.index(' and ')
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
