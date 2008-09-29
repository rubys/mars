<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:atom="http://www.w3.org/2005/Atom"
                xmlns:indexing="urn:atom-extension:indexing"
                xmlns:planet="http://planet.intertwingly.net/"
                xmlns:unknown="http://planet.intertwingly.net/unknown"
                xmlns:xhtml="http://www.w3.org/1999/xhtml"
		xmlns:thr='http://purl.org/syndication/thread/1.0'
                xmlns:feedburner="http://rssnamespace.org/feedburner/ext/1.0"
		exclude-result-prefixes="planet xhtml feedburner unknown">

  <!-- strip planet elements and attributes -->
  <xsl:template match="planet:*|@planet:*"/>

  <!-- strip unknown elements and attributes -->
  <xsl:template match="unknown:*|@unknown:*"/>

  <!-- strip blank subtitles -->
  <xsl:template match="atom:subtitle">
    <xsl:if test="./text()">
      <xsl:text>&#10;</xsl:text>
      <xsl:text>      </xsl:text>
      <xsl:copy>
        <xsl:apply-templates select="@*|node()"/>
      </xsl:copy>
    </xsl:if>
  </xsl:template>

  <!-- strip obsolete link relationships -->
  <xsl:template match="atom:link[@rel='service.edit']"/>
  <xsl:template match="atom:link[@rel='service.post']"/>
  <xsl:template match="atom:link[@rel='service.feed']"/>

   <!-- Feedburner detritus -->
   <xsl:template match="xhtml:div[@class='feedflare']"/>
   <xsl:template match="feedburner:*|@feedburner:*"/>

  <!-- add Google/LiveJournal-esque noindex directive -->
  <xsl:template match="atom:feed">
    <xsl:copy>
      <xsl:attribute name="indexing:index">no</xsl:attribute>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- indent atom elements -->
  <xsl:template match="atom:*">
    <!-- double space before atom:entries -->
    <xsl:if test="self::atom:entry">
      <xsl:text>&#10;</xsl:text>
    </xsl:if>

    <!-- indent start tag -->
    <xsl:text>&#10;</xsl:text>
    <xsl:for-each select="ancestor::*">
      <xsl:text>  </xsl:text>
    </xsl:for-each>

    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
 
      <!-- indent end tag if there are element children -->
      <xsl:if test="*">
        <xsl:text>&#10;</xsl:text>
        <xsl:for-each select="ancestor::*">
          <xsl:text>  </xsl:text>
        </xsl:for-each>
      </xsl:if>
    </xsl:copy>
  </xsl:template>

  <!-- pass through everything else -->

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
