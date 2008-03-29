require 'logger'

module Planet

  @@log = Logger.new STDERR
  STDERR.sync = true

  def Planet.log
    @@log
  end

  Logger::WARNING = Logger::WARN
  Logger::CRITICAL = Logger::FATAL

  def Planet.log_level level
    @@log.level = Logger.const_get(level)
  rescue NameError => err
    @@log.warn err.to_s
  end

  def Planet.log_format format
    @@log.formatter = PythonFormatter.new(format)
  end

  # http://docs.python.org/lib/node422.html
  class PythonFormatter < Logger::Formatter
    def initialize format
      @format = format + "\n"
      @format.gsub! /%\((\w+)\)(-?\d*\.?\d*)f/, '#{sprintf(\'%\2f\',\1.to_f)}'
      @format.gsub! /%\((\w+)\)(-?\d*\.?\d*)s/, '#{sprintf(\'%\2s\',\1.to_s)}'
      @format.gsub! /%\((\w+)\)(-?\d*\.?\d*)d/, '#{sprintf(\'%\2d\',\1.to_i)}'
    end

    def call severity, time, progname, msg
      name = progname
      levelno = Logger::SEV_LABEL.index(severity)*10+10 rescue 0
      levelname = severity
      classlib = File.dirname(caller.first.split(':').first)
      user = caller.delete_if {|name| name.index(classlib) == 0}
      pathname, lineno = user.first.split(':')[0..1]
      filename = File.basename(pathname)
      created = time
      asctime = time.iso8601
      msecs = time.iso8601
      thread = Thread.current[:id]
      threadName = Thread.current[:name]
      process = $$
      message = msg
  
      eval(@format.inspect.gsub('\\#{','#{'))
    end
  end
end
