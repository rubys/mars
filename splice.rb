#!/usr/bin/ruby

require 'planet/config'
require 'planet/spider'
require 'planet/splice'

ARGV.each {|arg| Planet.config.read arg}

#Planet.spider
Planet.splice
