require 'delegate'
require 'planet/log'

module Planet

  def Planet.config
    @@config
  end

  # Configuration parser compatible with the data format supported by Python:
  # http://docs.python.org/lib/module-ConfigParser.html
  class PythonConfigParser < DelegateClass(Hash)

    DEFAULTSECT = "DEFAULT"

    SECTRE = /
      \[                    # [
      ([^\]]+)              # very permissive!
      \]                    # ]
    /x

    OPTCRE = /
      ([^:=\s][^:=]*)       # very permissive!
      \s*[:=]\s*            # any number of space chars,
                            # followed by separator
                            # (either : or =), followed
                            # by any # space chars
      (.*)$                 # everything up to eol
    /x

    def initialize
      @sections = {}
      @sections[DEFAULTSECT] = {}
      super(@sections)
    end

    def read filename
      File.open(filename) do |config|
        cursect = nil
        optname = nil
        lineno = 0
        while line = config.gets
          lineno += 1
          next if line.strip.empty? or '#;'.include?(line[0])
          next if line =~ /^rem(\s|$)/i

          if line =~ /^\s/ and cursect and optname:
            # continuation line
            value = line.strip
            cursect[optname] += "\n#{value}" if value

          elsif line =~ SECTRE
            # section header
            sectname = $1
            @sections[sectname] ||= {'__name__' => sectname}
            cursect = @sections[sectname]
            optname = nil

          elsif not cursect
            raise Exception.new('Missing section header')

          elsif line =~ OPTCRE
            # option line
            optname, optval = $1, $2
            optval.sub(/\s;.*/, '')
            optval = '' if optval == '""'
            cursect[optname.downcase.strip] = optval

          else
            raise Exception.new('Invalid syntax on line #{lineno}')
          end
        end
      end
    end
  end

  class ConfigParser < PythonConfigParser
    def initialize
      super
      self['Planet'] = {}
    end

    def read filename
      super(filename)

      planet = self['Planet']

      Planet.log_format planet['log_format'] if planet['log_format']
      Planet.log_level  planet['log_level']  if planet['log_level']
    end
  end

  @@config = ConfigParser.new
end
