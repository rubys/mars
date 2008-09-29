require 'planet/config'
require 'html5/tokenizer'

class PlanetFormatter

  def process( stylesheet, feed )
    raise 'Abstract method called'
  end

  def plain(value)
    #TODO add HTML stripper
    tokenizer = HTML5::HTMLTokenizer.new(value)
    line = ""
    tokenizer.each { |t| 
#      puts "PLAIN: token, type=#{t[:type]}, data=#{t[:data]}, name=#{t[:name]}\n"
 
                    case t[:type]
                    when :StartTag, :EndTag, :EmptyTag, :Comment 
                      next
                    when :SpaceCharacters
                      line << t[:data]
                    when :Characters
                      line << t[:data]
                    when :ParseError
                      puts "PLAIN: parse error, data=#{t[:data]}, name=#{t[:name]}\n"
                      puts "PLAIN: parse error, value=#{value}\n"
                      line << value
                    else
                      puts "PLAIN: uncaught type #{t[:type]}\n"
                    end
                  }
    return line
  end
  
  def string(value)
    #TODO deal with encoding issues
    return value
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
