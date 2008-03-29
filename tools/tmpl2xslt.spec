require 'test/spec'
require 'tools/tmpl2xslt'
require 'planet/style'
require 'builder'

describe "feed" do
  it "should support author" do
    tmpl('<a><TMPL_VAR author></a>') { |atom|
      atom.author { atom.name "Herman Melville" }
    }.elements['html/body/a'].text.should == 'Herman Melville'
  end

  it "should support author_name" do
    tmpl('<a><TMPL_VAR author_name></a>') { |atom|
      atom.author { atom.name "Herman Melville" }
    }.elements['html/body/a'].text.should == 'Herman Melville'
  end

  it "should support feed" do
    tmpl('<a href="<TMPL_VAR feed>">foo</a>') { |atom|
      atom.link :rel=>'self', :href=>'http://example.com/atom'
    }.elements['html/body/a/@href'].value.should == 'http://example.com/atom'
  end

  it "should support feedtype" do
    tmpl('<link type="application/<TMPL_VAR feedtype>+xml">foo</link>') { |atom|
      atom.link :rel=>'self', :type=>'application/atom+xml'
    }.elements['html/head/link/@type'].value.should == 'application/atom+xml'
  end

  it "should support generator" do
    tmpl('<meta name="generator" content="<TMPL_VAR generator>">') { |atom|
      atom.generator "Mars"
    }.elements['html/head/meta/@content'].value.should == 'Mars'
  end

  it "should support id" do
    tmpl('<a id="<TMPL_VAR id>">') { |atom|
      atom.id "42"
    }.elements['html/body/a/@id'].value.should == '42'
  end

  it "should support last_updated" do
    tmpl('<time><TMPL_VAR last_updated></time>') { |atom|
      atom.feed 'xmlns:planet' => 'http://planet.intertwingly.net/' do
        atom.updated "planet:format" => "May 03, 2008 10:59 PM"
      end
    }.elements['html/body/time'].text.should == 'May 03, 2008 10:59 PM'
  end

  it "should support last_updated_iso" do
    tmpl('<time><TMPL_VAR last_updated_iso></time>') { |atom|
      atom.updated "2008-05-03T22:59:00-05:00"
    }.elements['html/body/time'].text.should == "2008-05-03T22:59:00-05:00"
  end

  it "should support link" do
    tmpl('<a href="<TMPL_VAR link>">foo</a>') { |atom|
      atom.link :rel=>'alternate', :href=>'http://example.com/'
    }.elements['html/body/a/@href'].value.should == 'http://example.com/'
  end

  it "should support logo" do
    tmpl('<img src="<TMPL_VAR logo>">') { |atom|
      atom.logo 'http://example.com/a.png'
    }.elements['html/body/img/@src'].value.should == 'http://example.com/a.png'
  end

  it "should support name" do
    tmpl('<h1><TMPL_VAR name></h1>') { |atom|
      atom.title "foo"
    }.elements['html/body/h1'].text.should == 'foo'
  end

  it "should support owner_name" do
    tmpl('<a><TMPL_VAR owner_name></a>') { |atom|
      atom.author { atom.name "me" }
    }.elements['html/body/a'].text.should == 'me'
  end

  it "should support rights" do
    tmpl('<p><TMPL_VAR rights></p>') { |atom|
      atom.rights "public domain"
    }.elements['html/body/p'].text.should == 'public domain'
  end

  it "should support subtitle" do
    tmpl('<h2><TMPL_VAR subtitle></h2>') { |atom|
      atom.subtitle "foo"
    }.elements['html/body/h2'].text.should == 'foo'
  end

  it "should support title" do
    tmpl('<h1><TMPL_VAR title></h1>') { |atom|
      atom.title "foo"
    }.elements['html/body/h1'].text.should == 'foo'
  end

  it "should support title_plain" do
    tmpl('<h1><TMPL_VAR title_plain></h1>') { |atom|
      atom.title "foo"
    }.elements['html/body/h1'].text.should == 'foo'
  end

  it "should support url" do
    tmpl('<a href="<TMPL_VAR url>">foo</a>') { |atom|
      atom.link :rel=>'alternate', :href=>'http://example.com/'
    }.elements['html/body/a/@href'].value.should == 'http://example.com/'
  end
end

describe "entry" do
  it "should support author" do
    itmpl('<a><TMPL_VAR author></a>') { |atom|
      atom.author { atom.name "Herman Melville" }
    }.elements['html/body/a'].text.should == 'Herman Melville'
  end

  it "should support author_name" do
    itmpl('<a><TMPL_VAR author_name></a>') { |atom|
      atom.author { atom.name "Herman Melville" }
    }.elements['html/body/a'].text.should == 'Herman Melville'
  end

  it "should support author_email" do
    itmpl('<a><TMPL_VAR author_email></a>') { |atom|
      atom.author { atom.email "me@hotmail.com" }
    }.elements['html/body/a'].text.should == 'me@hotmail.com'
  end

  it "should support author_uri" do
    itmpl('<a><TMPL_VAR author_uri></a>') { |atom|
      atom.author { atom.uri "http://example.org/" }
    }.elements['html/body/a'].text.should == 'http://example.org/'
  end

  it "should support content_language" do
    itmpl('<div lang="<TMPL_VAR content_language>">foo</div>') { |atom|
      atom.content "xml:lang" => "de"
    }.elements['html/body/div/@lang'].value.should == 'de'
  end

  it "should support date" do
    itmpl('<time><TMPL_VAR date></time>') { |atom|
      atom.entry 'xmlns:planet' => 'http://planet.intertwingly.net/' do
        atom.updated "planet:format" => "May 03, 2008 10:59 PM"
      end
    }.elements['html/body/time'].text.should == 'May 03, 2008 10:59 PM'
  end

  it "should support date_iso" do
    itmpl('<time><TMPL_VAR date_iso></time>') { |atom|
      atom.updated "2008-05-03T22:59:00-05:00"
    }.elements['html/body/time'].text.should == '2008-05-03T22:59:00-05:00'
  end

  it "should support enclosure_href" do
    itmpl('<a href="<TMPL_VAR enclosure_href>">foo</a>') { |atom|
      atom.link :rel=>'enclosure', :href=>'http://example.com/a.mp3'
    }.elements['html/body/a/@href'].value.should == 'http://example.com/a.mp3'
  end

  it "should support enclosure_length" do
    itmpl('<span><TMPL_VAR enclosure_length> bytes</span>') { |atom|
      atom.link :rel=>'enclosure', :length=>32000
    }.elements['html/body/span'].text.should == '32000 bytes'
  end

  it "should support enclosure_type" do
    itmpl('<span>(<TMPL_VAR enclosure_type>)</span>') { |atom|
      atom.link :rel=>'enclosure', :type=>'audio/mpeg'
    }.elements['html/body/span'].text.should == '(audio/mpeg)'
  end

  it "should support id" do
    itmpl('<a id="<TMPL_VAR id>">') { |atom|
      atom.id "42"
    }.elements['html/body/a/@id'].value.should == '42'
  end

  it "should support link" do
    itmpl('<a href="<TMPL_VAR link>">foo</a>') { |atom|
      atom.link :rel=>'alternate', :href=>'http://example.com/'
    }.elements['html/body/a/@href'].value.should == 'http://example.com/'
  end

  it "should support published" do
    itmpl('<time><TMPL_VAR published></time>') { |atom|
      atom.entry 'xmlns:planet' => 'http://planet.intertwingly.net/' do
        atom.published "planet:format" => "May 03, 2008 10:59 PM"
      end
    }.elements['html/body/time'].text.should == 'May 03, 2008 10:59 PM'
  end

  it "should support published_iso" do
    itmpl('<time><TMPL_VAR published_iso></time>') { |atom|
      atom.published "2008-05-03T22:59:00-05:00"
    }.elements['html/body/time'].text.should == '2008-05-03T22:59:00-05:00'
  end

  it "should support rights" do
    itmpl('<p><TMPL_VAR rights></p>') { |atom|
      atom.rights "public domain"
    }.elements['html/body/p'].text.should == 'public domain'
  end

  it "should support title" do
    itmpl('<h2><TMPL_VAR title></h2>') { |atom|
      atom.title "foo"
    }.elements['html/body/h2'].text.should == 'foo'
  end

  it "should support title_language" do
    itmpl('<div lang="<TMPL_VAR title_language>">foo</div>') { |atom|
      atom.title "xml:lang" => "de"
    }.elements['html/body/div/@lang'].value.should == 'de'
  end

  it "should support title_plain" do
    itmpl('<h2><TMPL_VAR title_plain></h2>') { |atom|
      atom.title "foo"
    }.elements['html/body/h2'].text.should == 'foo'
  end

  it "should support summary_language" do
    itmpl('<div lang="<TMPL_VAR summary_language>">foo</div>') { |atom|
      atom.summary "xml:lang" => "de"
    }.elements['html/body/div/@lang'].value.should == 'de'
  end

  it "should support updated" do
    itmpl('<time><TMPL_VAR updated></time>') { |atom|
      atom.entry 'xmlns:planet' => 'http://planet.intertwingly.net/' do
        atom.updated "planet:format" => "May 03, 2008 10:59 PM"
      end
    }.elements['html/body/time'].text.should == 'May 03, 2008 10:59 PM'
  end

  it "should support updated_iso" do
    itmpl('<time><TMPL_VAR updated_iso></time>') { |atom|
      atom.updated "2008-05-03T22:59:00-05:00"
    }.elements['html/body/time'].text.should == '2008-05-03T22:59:00-05:00'
  end
end

describe "channel" do
  it "should support channel_face" do
    itmpl('<img src="images/<TMPL_VAR channel_face>">') { |atom|
      atom.source 'xmlns:planet' => 'http://planet.intertwingly.net/' do
        atom.planet :face, "jimbo"
      end
    }.elements['html/body/img/@src'].value.should == 'images/jimbo'
  end

  it "should support channel_link" do
    itmpl('<a href="<TMPL_VAR channel_link>">foo</a>') { |atom|
      atom.source { atom.link :rel=>'alternate', :href=>'http://example.com' }
    }.elements['html/body/a/@href'].value.should == 'http://example.com'
  end

  it "should support channel_title" do
    itmpl('<h2><TMPL_VAR channel_title></h2>') { |atom|
      atom.source { atom.title 'something witty' }
    }.elements['html/body/h2'].text.should == 'something witty'
  end

  it "should support channel_title_plain" do
    itmpl('<a title="<TMPL_VAR channel_title_plain>">foo</a>') { |atom|
      atom.source { atom.title 'something witty' }
    }.elements['html/body/a/@title'].value.should == 'something witty'
  end
end

describe "new" do
  it "should support date" do
    itmpl('<TMPL_IF new_date><h2><TMPL_VAR new_date></h2></TMPL_IF>' +
          '<p><TMPL_VAR title></p>') { |atom|
      atom.feed 'xmlns:planet' => 'http://planet.intertwingly.net/' do
        atom.entry do
          atom.title 1
          atom.updated "2008-05-03T10:59-05:00",
            "planet:format" => "May 03, 2008 10:59 PM"
        end
        atom.entry do
          atom.title 2
          atom.updated "2008-05-03T03:59-05:00",
            "planet:format" => "May 03, 2008 03:59 PM"
        end
        atom.entry do
          atom.title 3
          atom.updated "2008-05-02T10:59-05:00",
            "planet:format" => "May 02, 2008 10:59 PM"
        end
        atom.entry do
          atom.title 4
          atom.updated "2008-05-02T03:59-05:00",
            "planet:format" => "May 02, 2008 03:59 PM"
        end
        atom.entry do
          atom.title 5
          atom.updated "2008-05-01T10:59-05:00",
            "planet:format" => "May 01, 2008 10:59 PM"
        end
      end
    }.elements['html/body'].to_s.should == '<body>' +
      '<h2>May 03, 2008</h2><p>1</p><p>2</p>' +
      '<h2>May 02, 2008</h2><p>3</p><p>4</p>' +
      '<h2>May 01, 2008</h2><p>5</p></body>'
  end 

  it "should support channel" do
    itmpl('<TMPL_IF new_channel><h2><TMPL_VAR channel_title></h2></TMPL_IF>' +
          '<p><TMPL_VAR title></p>') { |atom|
      atom.feed 'xmlns:planet' => 'http://planet.intertwingly.net/' do
        atom.entry do
          atom.title 1
          atom.source {atom.id 1; atom.title 'a'}
        end
        atom.entry do
          atom.title 2
          atom.source {atom.id 1; atom.title 'a'}
        end
        atom.entry do
          atom.title 3
          atom.source {atom.id 2; atom.title 'b'}
        end
        atom.entry do
          atom.title 4
          atom.source {atom.id 2; atom.title 'b'}
        end
        atom.entry do
          atom.title 5
          atom.source {atom.id 1; atom.title 'a'}
        end
      end
    }.elements['html/body'].to_s.should == '<body>' +
      '<h2>a</h2><p>1</p><p>2</p>' +
      '<h2>b</h2><p>3</p><p>4</p>' +
      '<h2>a</h2><p>5</p></body>'
  end 
end

# support method: apply a template against a feed
def tmpl(tmpl)
  feed = REXML::Document.new(yield(Builder::XmlMarkup.new))
  if feed.root.name != 'feed'
    feed << REXML::Element.new('feed').add_element(feed.root).parent
  end
  feed.root.add_namespace 'http://www.w3.org/2005/Atom'
  REXML::Document.new(Planet::Xslt.process(tmpl2xslt(tmpl).to_s, feed))
end

# support method: apply a "item" template against an entry
def itmpl(tmpl, &block)
  entry = REXML::Document.new(block.call(Builder::XmlMarkup.new))
  if entry.root.name != 'feed'
    if entry.root.name != 'entry'
      entry << REXML::Element.new('entry').add_element(entry.root).parent
    end
    entry << REXML::Element.new('feed').add_element(entry.root).parent
  end
  entry.root.add_namespace 'http://www.w3.org/2005/Atom'
  tmpl = "<TMPL_LOOP Items>#{tmpl}</TMPL_LOOP>"
  REXML::Document.new(Planet::Xslt.process(tmpl2xslt(tmpl).to_s, entry))
end
