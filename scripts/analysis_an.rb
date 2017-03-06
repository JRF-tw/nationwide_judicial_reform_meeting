#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'json'

Dir.chdir(File.dirname(__FILE__))

def get_html(url)
  page = open(url)
  html = Nokogiri::HTML(page.read)
end

def main
  url = ARGV[0]
  html = get_html(url)
  speeches = html.css('speech')
  results = {}
  speeches.each do |speech|
    speacker = speech.css('from').first.text
    if results[speacker]
      results[speacker] += speech.css('p').text.length
    else
      results[speacker] = speech.css('p').text.length
    end
  end
  results.each do |k, v|
    puts "#{k}, #{v}"
  end
end

main()
