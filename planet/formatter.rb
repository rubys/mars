require 'planet/config'

class PlanetFormatter

  def process( stylesheet, feed )
    raise 'Abstract method called'
  end

  def plain(value)
    #TODO add HTML stripper
    return value
  end
  
  def string(value)
    #TODO deal with encoding issues
    return value
  end
  
  def planet_date(value)
      df = Planet.config['Planet']['date_format']
      df = "%B %d, %Y %I:%M %p" unless df
      return value ? Time.parse(value).gmtime.strftime(df): nil
  end
  
  def new_date(value)
      ndf = Planet.config['Planet']['new_date_format']
      ndf = "%B %d, %Y %I:%M %p" unless ndf
      return value ? Time.parse(value).gmtime.strftime(ndf): nil
  end

  def rfc822(value)
      return value ? Time.parse(value).gmtime.strftime("%a, %d %b %Y %H:%M:%S +0000"): nil
  end
  
  def rfc3399(value)
    return value ? Time.parse(value).gmtime.strftime("%Y-%m-%dT%H:%M:%S+00:00"): nil
  end

end
