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
  members = JSON.parse(File.read('./members.json'))
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
    f.write("姓名, 發言字數, 身分類別, 法律人類別, 小組分組, 是否為籌備委員\n")
    results.each do |name, count|
      member = nil
      members.each do |m|
        if m["姓名"] == name
          member = m
          if member["籌備委員"]
            member["籌備委員"] = "是"
          else
            member["籌備委員"] = "否"
          end
          break
        end
      end
      if member
        result = "#{name}, #{count}, #{member["身分類別"]}, #{member["法律人類別"]}, #{member["小組分組"]}, #{member["籌備委員"]}\n"
      else
        result = "#{name}, #{count},,,,\n"
      end
      puts result
      f.write(result)
    end
  end
end

main()