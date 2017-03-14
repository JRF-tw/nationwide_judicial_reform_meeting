#!/usr/bin/env ruby
# encoding: UTF-8
#
# This script is use to parse akoma ntosos url(.an) and count the word that speaker speech,
# then save it into a csv file.
# Please install Nokogiri through `gem install nokogiri` first.
#
# Usage: ./analysis_an.rb #{AKOMA NTOSOS URL}
#
# This script is release under MIT License.
# Copyright (c) 2017 Billy Lin, Judicial Reform Foundation
#

require 'nokogiri'
require 'open-uri'
require 'json'

# Change to the directory which place the script.
Dir.chdir(File.dirname(__FILE__))

def get_html(url)
  # get the page and parse with Nokogiri.
  page = open(url)
  html = Nokogiri::HTML(page.read)
end

def main
  url = ARGV[0]
  html = get_html(url)
  # Use the heading text as title.
  title = html.css('heading').first.text
  speeches = html.css('speech')
  results = {}
  speeches.each do |speech|
    # if <from> exist, use the text; otherwise use the by attr of speech.
    speaker = speech.css('from').first ? speech.css('from').first.text : speech.attr("by").gsub('#', '')
    if results[speaker]
      results[speaker] += speech.css('p').text.length
    else
      results[speaker] = speech.css('p').text.length
    end
  end
  # Save it into the csv file named by title.
  File.open("#{title}發言字數統計.csv", 'w') do |f|
    f.write("name, count\n")
    results.each do |name, count|
      puts "#{name}, #{count}"
      f.write("#{name}, #{count}\n")
    end
  end
end

main()