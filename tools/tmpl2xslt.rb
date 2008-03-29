#/usr/bin/ruby
#
# tmpl2xslt is a migration aide that will convert a Planet 2.0 or Venus
# htmltmpl file into an XSLT file suitable for use with either Mars or Venus.
#
require 'html5'

def tmpl2xslt tmpl

  names = {
    'author'         => 'atom:author/atom:name',
    'author_email'   => 'atom:author/atom:email',
    'author_name'    => 'atom:author/atom:name',
    'author_uri'     => 'atom:author/atom:uri' ,
    'content_language' => 'atom:content/@xml:lang',
    'date'           => 'atom:updated/@planet:format',
    'date_iso'       => 'atom:updated',
    'enclosure_href' => "atom:link[@rel='enclosure']/@href",
    'enclosure_length' => "atom:link[@rel='enclosure']/@length",
    'enclosure_type' => "atom:link[@rel='enclosure']/@type",
    'feed'           => "atom:link[@rel='self']/@href",
    'feedtype'       => "atom:link[@rel='self']/@type",
    'generator'      => 'atom:generator',
    'id'             => "atom:id",
    'last_updated'   => 'atom:updated/@planet:format',
    'last_updated_iso' => 'atom:updated',
    'link'           => "atom:link[@rel='alternate']/@href",
    'logo'           => "atom:logo",
    'name'           => 'atom:title',
    'owner_name'     => 'atom:author/atom:name',
    'published'      => 'atom:published/@planet:format',
    'published_iso'  => 'atom:published',
    'rights'         => 'atom:rights',
    'subtitle'       => 'atom:subtitle',
    'title'          => 'atom:title',
    'title_language' => 'atom:title/@xml:lang',
    'title_plain'    => 'atom:title/text()',
    'summary_language' => 'atom:summary/@xml:lang',
    'updated'        => 'atom:updated/@planet:format',
    'updated_iso'    => 'atom:updated',
    'url'            => "atom:link[@rel='alternate']/@href",
  }

  # convert variable names to xpath expressions
  xpath = proc do |name|
    case name
    when *names.keys      then names[name]
    when 'Channels'       then 'planet:source'
    when 'Items'          then 'atom:entry'
  
    when /^channel_(.*)$/    then 
      if names.has_key?($1)
        "atom:source/#{names[$1]}"
      else
        "atom:source/planet:#{$1}"
      end
  
    when 'new_date'       then
      "substring-before(atom:updated/@planet:format,', ')}, {" +
      "substring-before(substring-after(atom:updated/@planet:format,', '), ' ')"
  
    else
      STDERR.puts "Unknown variable encountered: #{name}"
      name
    end
  end
  
  # kill the DOCTYPE
  tmpl.sub! /<!DOCTYPE.*?>\s*/, ''
  
  # enclose line comments in XML/HTML comments
  tmpl.gsub! /^((#.*\n)+)/, "<!--\n\\1-->\n"
  
  # special case: feed type already is formatted as a mime type
  tmpl.gsub! 'application/<TMPL_VAR feedtype>+xml', '<TMPL_VAR feedtype>'
  
  # template variables
  tmpl.gsub! /<TMPL_VAR (\w+) ESCAPE="HTML">/, '<TMPL_VAR \1>'
  tmpl.gsub! /<TMPL_VAR (\w+)>/ do
    if $1 == 'content'
      '<choose></choose>'
    else
     "{#{xpath.call($1)}}"
    end
  end
  
  # template if statements temporarily become pseudo-span elements
  tmpl.gsub! /<\/TMPL_IF>/, '</span>'
  tmpl.gsub! /<TMPL_IF (\w+)>/ do
    if $1 == 'new_date'
      '<span test="not(' +
          'substring(preceding-sibling::atom:entry[1]/atom:updated,1,10)=' +
          'substring(atom:updated,1,10))">'
  
    elsif $1 == 'new_channel'
      '<span test="not(' +
          'preceding-sibling::atom:entry[1]/atom:source/atom:id=' +
          'atom:source/atom:id)">'
  
    else
      "<span test=\"#{xpath.call($1)}\">"
    end
  end
  
  # template loop statements temporarily become pseudo-span elements
  tmpl.gsub! /<\/TMPL_LOOP>/, '</span>'
  tmpl.gsub! /<TMPL_LOOP (\w+)>/ do
    "<span select=\"#{xpath.call($1)}\">"
  end
  
  # convert template to DOM
  doc = HTML5.parse(tmpl)
  
  # reparent conditional head elements
  doc.elements.each('html/body/span[meta or link]') {|span|
    doc.elements['html/head'] << span
  }
  
  doc.elements.each('//*') do |node|
    # pseudo span elements become xsl control elements
    if node.name == 'span'
      if node.attributes['select']
        node.name = 'xsl:for-each'
      elsif node.attributes['test']
        node.name = 'xsl:if'
      end
    end
  
    # choose between content and summary
    if node.name == 'choose'
      node.name = 'xsl:choose'
      child = node.add_element('xsl:when', 'test' => 'atom:content')
      child.add_element('xsl:apply-templates', 'select' => 'atom:content')
      child = node.add_element('xsl:when', 'test' => 'atom:summary')
      child.add_element('xsl:apply-templates', 'select' => 'atom:summary')
    end
  
    # convert scripts to CDATA
    if node.name == 'script'
      node.texts.each do |text|
        if text.value =~ /[&<]/
          text.previous_sibling = REXML::CData.new(text.value)
          text.remove
        end
      end
    end
  
    # add namespace to html element
    if node.name == 'html'
      node.add_namespace 'http://www.w3.org/1999/xhtml'
    end
  
    # replace string interpretation in text nodes with xsl:value of elements
    node.texts.each do |text|
      if text.value =~ /\{.*?\}/
        text.value.split(/\{(.*?)\}/).each_with_index do |value, index|
          if index % 2 == 1
            text.previous_sibling = REXML::Element.new('xsl:value-of')
            text.previous_sibling.attributes['select'] = value
          elsif !value.empty?
            text.previous_sibling = REXML::Text.new(value)
          end
        end
        text.remove
      end
    end
  end
  
  # Egregious hack: convert all escaped single quotes in XPath
  # expressions to double quotes.
  tmpl = doc.to_s.gsub /\{.*?\}| (test|select)='.*?'/ do |xpath|
    xpath.gsub('&apos;','"')
  end
  
  # wrapt the template in a stylesheet
  REXML::Document.new <<EOF
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:atom="http://www.w3.org/2005/Atom"
                xmlns:xhtml="http://www.w3.org/1999/xhtml"
                xmlns:planet="http://planet.intertwingly.net/"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="atom planet xhtml">

<xsl:output method="xml" omit-xml-declaration="yes"/>

<!-- main template -->
<xsl:template match="atom:feed">
#{tmpl.gsub(/\n\n\n+/,"\n\n")}
</xsl:template>

<!-- primary template -->
<xsl:template match="atom:content/xhtml:div | atom:summary/xhtml:div">
  <xsl:copy>
    <xsl:if test="../@xml:lang and not(../@xml:lang = ../../@xml:lang)">
      <xsl:attribute name="xml:lang">
        <xsl:value-of select="../@xml:lang"/>
      </xsl:attribute>
    </xsl:if>
    <xsl:attribute name="class">content</xsl:attribute>
    <xsl:apply-templates select="@*|node()"/>
  </xsl:copy>
</xsl:template>

<!-- plain text content -->
<xsl:template match="atom:content/text() | atom:summary/text()">
  <div class="content" xmlns="http://www.w3.org/1999/xhtml">
    <xsl:if test="../@xml:lang and not(../@xml:lang = ../../@xml:lang)">
      <xsl:attribute name="xml:lang">
        <xsl:value-of select="../@xml:lang"/>
      </xsl:attribute>
    </xsl:if>
    <xsl:copy-of select="."/>
  </div>
</xsl:template>

<!-- Remove stray atom elements -->
<xsl:template match="atom:*">
  <xsl:apply-templates/>
</xsl:template>

<!-- pass through everything else -->
<xsl:template match="@*|node()">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>
EOF
  end

if $0 == __FILE__
  if ARGV.first =~ /.tmpl$/ and ARGV.length == 1
    # convert tmpl to stylesheet
    open(ARGV.first.sub(/.tmpl$/,'.xslt'),'w') do |file|
      file.write tmpl2xslt(File.open(ARGV.first).read).to_s.gsub('&quot;','"')
    end
  else
    STDERR.puts "Usage: ruby #{__FILE__} index.html.tmpl"
    exit 86
  end
end
