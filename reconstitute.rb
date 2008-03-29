require 'open-uri'

require 'planet/sift'
require 'planet/transmogrify'

ARGV.each do |arg|
  doc = Planet::Transmogrify.parse(open(arg))
  doc.attributes['xml:base'] = arg
  Planet.sift(doc)
  puts doc
end
