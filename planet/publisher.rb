require 'planet/config'
require 'planet/hamlformatter'
require 'planet/xsltformatter'

# a TemplatePublisher coordinates processing of the feed with provided templates
class TemplatePublisher

  ALLOWED_TEMPLATES = %w[xslt haml]

  def initialize
    @formatters = { 'haml' => HamlFormatter.new,
                    'xslt' => XsltFormatter.new }
  end
  
  def publish_feed(template_files, feed)
    config = Planet.config['Planet']
    output_dir = config['output_dir'] || '.'
    
      # loop through the listed templates
      template_files.split.each do |template|
        next unless template =~ /([^\/]* \. [^\/]*) \. (\w+)$/x

        # skip templates that aren't supported
        unless ALLOWED_TEMPLATES.include?($2) then
          Planet.log.warn "#{$2}: not yet supported"
          next
        end

        # pick the formatter
        @formatter = @formatters[$2]

        # process the template
        File.open(File.join(output_dir,$1),'w') do |file|
          Planet.log.info "Processing template #{template}"
          file.write @formatter.process(template, feed)
        end
      end
    end
    
  end
