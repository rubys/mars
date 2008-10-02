require 'addressable/uri'
require 'digest/md5'
require 'net/https'
require 'thread'
require 'timeout'
require 'yaml'
require 'zlib'

require 'planet/log'

module Planet

  # map a URI to a readable and (relatively) unique filename
  def Planet.filename uri
    name = uri_norm(uri)
    name.sub!(/^\w+:\/*(\w+:|www\.)?/,'') # remove scheme and www.
    name.gsub! /[?\/:|]+/, ','            # replace separator characters
    name.sub! /^[,.]*/, ''                # remove initial junk
    name.sub! /[,.]*$/, ''                # remove final junk

    if name.length > 250
      parts, excess = name.split(','), []
      excess << parts.pop while parts.join(',').length > 220
      parts << Digest::MD5.hexdigest(excess.join(','))
      name = parts.join(',')
    end

    name
  end

  class Fido
    attr_accessor :cache, :redirect_limit, :threads, :timeout

    def initialize cache
      @cache = cache
      @timeout = 30
      @threads = 6
      @redirect_limit = 10
    end

    # invoke fetch on a list of uris in parallel
    def each(uris)
      lock = Mutex.new
      queue = uris.clone

      threads = []
      @threads.times do |i|
        threads[i] = Thread.new {
          while uri = lock.synchronize {queue.pop}
            begin
              response = fetch(Planet::uri_norm(uri), redirect_limit)
              yield uri, response
              write_to_cache uri, response
            rescue Exception => e
              Planet.log.error e.inspect
              Planet.log.error uri
              e.backtrace.each {|line| Planet.log.error line}
            end
          end
        }
      end

      # wait for each to complete
      threads.each {|thread| thread.join}
    end

    # fetch a uri, processing up to redirect_limit number of redirects
    def fetch uri, redirect_limit=10
      cachefile = File.join(@cache, Planet.filename(uri))

      # handle permanent redirects and gone
      if File.exist? cachefile
        cache = File.open(cachefile) {|file| YAML::load file.read}
        return cache if cache.code == '410'
        if cache.code == '301' and redirect_limit > 0
          location = cache['location']
          if location
            return fetch(Planet::uri_norm(uri,location), redirect_limit-1)
          end
        end
      else
        cache = {}
      end

      # issue the request, handling timeout, ssl, etc.
      response = begin
        uri = URI.parse(uri)
        Timeout::timeout(@timeout, Timeout::Error) {
          http = Net::HTTP::new(uri.host, uri.port)

          if uri.scheme == 'https'
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end

          http.start {
            request = Net::HTTP::Get.new(uri.request_uri)
            request['If-None-Match'] ||=  cache['Etag']
            request['If-Modified-Since'] ||=  cache['Last-Modified']
            request['USER-Agent'] = 'Mars'
            request['Accept-Encoding'] = 'gzip, deflate'
            http.request(request)
          }
        }
      rescue Timeout::Error => error
        Net::HTTPRequestTimeOut.new '1.1', '408', error.to_s
      rescue SocketError, Errno::ECONNRESET => error
        Net::HTTPInternalServerError.new '1.1', '500', error.to_s
      end

      # expand gzip and deflated responses
      if response.code == '200' and response.body
        case response['content-encoding']
        when 'gzip', 'x-gzip'
          gz = Zlib::GzipReader.new(StringIO.new(response.body))
          response.instance_eval {@body = gz.read}
          gz.close
          response.delete('content-encoding')
        when 'deflate'
          response.instance_eval {@body = Zlib::Inflate.inflate(response.body)}
          response.delete('content-encoding')
        end
      end

      # not all servers handle conditional gets, so while not much can be
      # done about the bandwidth, but if the response body is identical
      # the downstream processing (parsing, caching, ...) can be avoided.
      if response.code == '200' and cache.respond_to? :body
        if response.body == cache.body
          response = Net::HTTPNotModified.new('1.0', '304', 'Not Modified')
        end
      end

      # handle redirects
      if %w[301 302 307].include? response.code and redirect_limit > 0
        location = response['location']
        if location
          return fetch(Planet::uri_norm(uri.to_s,location), redirect_limit - 1)
        end
      end

      # log the response and save the actual content location used
      level = (response.code<'400' ? :info : :warn)
      Planet.log.send level, "#{response.code} #{uri}"
      response.header['Content-Location'] ||= uri.to_s

      response
    rescue Timeout::Error
      raise
    rescue Exception => e
      response = Net::HTTPInternalServerError.new('1.0', '500', e.to_s)
      response.header['Content-Location'] ||= uri.to_s

      Planet.log.error "#{response.code} #{uri}"
      Planet.log.error e.inspect
      e.backtrace.each {|line| Planet.log.error line}

      response
    end

    # update cache with successful and permanent responses
    def write_to_cache uri, response
      if %w[200 301 410].include? response.code
        cachefile = File.join(@cache, Planet.filename(uri))
        File.open(cachefile,'w') {|file| file.write(response.to_yaml)}
      end
    end

    # fetch previous successful response from cache
    def read_from_cache uri
      cachefile = File.join(@cache, Planet.filename(uri))
      File.open(cachefile) {|file| YAML::load file.read}
    end
  end

  # convenience method to normalize a URI
  def Planet.uri_norm *parts
    begin
      Addressable::URI.join(*parts).normalize.to_s
    rescue Exception => e
      Planet.log.warn "#{e} #{parts.inspect}"
      parts.last
    end
  end
end
