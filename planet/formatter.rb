require 'planet/config'
require 'cgi'

class PlanetFormatter

  def process( stylesheet, feed )
    raise 'Abstract method called'
  end

  def plain(detail)
    html = Planet::XmlParser.fragment(html(detail)).children
    html.map {|node| node.text}.join
  end
  
  def string(value)
    #TODO deal with encoding issues
    return value
  end
  
  def html(detail)
    if detail.type == 'text/plain'
      return CGI.escapeHTML(detail.value.to_s)
    else
      return detail.value
    end
  end

  def planet_date(value)
      df = Planet.config['Planet']['date_format']
      df ||= "%B %d, %Y %I:%M %p"
      t = value ? Time.parse(value).gmtime.strftime(df): nil
      t.gsub!('"', '')
      return t
  end
  
  def new_date(value)
      ndf = Planet.config['Planet']['new_date_format']
      ndf ||= "%B %d, %Y %I:%M %p"
      t = value ? Time.parse(value).gmtime.strftime(ndf): nil
      t.gsub!('"', '')
      return t
  end

  def rfc822(value)
      return value ? Time.parse(value).gmtime.strftime("%a, %d %b %Y %H:%M:%S +0000"): nil
  end
  
  def rfc3399(value)
    return value ? Time.parse(value).gmtime.strftime("%Y-%m-%dT%H:%M:%S+00:00"): nil
  end

end
