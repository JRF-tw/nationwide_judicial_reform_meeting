#!/usr/bin/env ruby

require 'nokogiri'
require 'json'
require 'open-uri'
require 'date'
require 'time'

Dir.chdir(File.dirname(__FILE__))

def write_file(filename, content)
  File.open(filename,"w") do |f|
    f.write(content)
  end
end

def scan_content(content, pattern)
  begin
    matches = content.scan(pattern)
  rescue
    matches = []
  end
  return matches
end

def get_html(url)
  page = open(url)
  html = Nokogiri::HTML(page.read)
end

def get_name(name, chairman = nil)
  name = name.gsub('：', '')
  if chairman and name == '主席'
    return chairman
  end
  name = name.gsub('委員', '').gsub('委員兼召集人', '').gsub('處長', '').gsub('律師', '').
    gsub('法官', '').gsub('檢察官', '').gsub('副主席', '').gsub('執行秘書', '').gsub('教授', '').
    gsub('理事長', '').gsub('副院長', '').gsub('院長', '').gsub('先生', '').gsub('副廳長', '').
    gsub('簡任祕書', '').gsub('部長', '')
end

def get_chairman(contents)
  chairman = nil
  contents.each do |content|
    if content.text.match(/主席：(\p{Word}+)/)
      chairman = content.text.gsub('主席：', '').gsub('委員兼召集人', '').gsub('教授', '').
        gsub('理事長', '').gsub('副院長', '').gsub('院長', '').gsub('部長', '')
    end
  end
  chairman
end

def get_conventioneers(content)
  content.gsub('出席人員：', '').gsub('出席：', '').gsub(/（\p{Word}+）/, '').split('、')
end

def get_hearers(content)
  content.gsub('列席人員：', '').gsub(/（\p{Word}+）/, '').split('、')
end

def get_datetime(content)
  content.gsub('時間：', '')
end

def get_recorder(content)
  content.gsub('記錄：', '').split('、')
end

def get_place(content)
  content.gsub('地點：', '')
end

def insert_speech(speech, debateSection, doc)
  speech_node = Nokogiri::XML::Node.new('speech', doc)
  speech_node['by'] = "##{speech[:speaker]}"
  from_node = Nokogiri::XML::Node.new('from', doc)
  from_node.content = speech[:speaker]
  from_node.parent = speech_node
  from_node.add_next_sibling(speech[:content])
  debateSection << speech_node
end

def insert_narrative(narrative, debateSection, doc)
  narrative_node = Nokogiri::XML::Node.new('narrative', doc)
  narrative_node.content = narrative
  debateSection << narrative_node
end

def main
  url = ARGV[0]
  html = get_html(url)
  title = html.css('h1').first.text
  contents = html.css('p')
  starttime, endtime, chairman = nil
  people = []
  chairman = get_chairman(contents)
  speaker = ''
  speeches = []
  speech = {}
  doc = Nokogiri::XML('
    <akomaNtoso>
      <debate name="hansard">
        <meta>
          <references source="#">
          </references>
        </meta>
        <preface>
          <docTitle></docTitle>
        </preface>
        <debateBody>
          <debateSection>
            <heading></heading>
          </debateSection>
        </debateBody>
      </debate>
    </akomaNtoso>')
  doc.encoding = 'UTF-8'
  doc.css('docTitle').first.content = '1999年全國司法改革會議'
  doc.at_css('heading').content = title
  debateSection = doc.at_css "debateSection"
  contents.each do |content|
    if content.text.match(/^\s*$/)
      next
    elsif content.text.match(/^時間：/)
      insert_narrative(content.text, debateSection, doc)
      starttime, endtime = get_datetime(content.text)
    elsif content.text.match(/^出席人員：/)
      insert_narrative(content.text, debateSection, doc)
      people += get_conventioneers(content.text)
    elsif content.text.match(/^列席人員：/)
      insert_narrative(content.text, debateSection, doc)
    elsif content.text.match(/^主席：(\p{Word}+)/)
      insert_narrative(content.text, debateSection, doc)
    elsif content.text.match(/^紀錄：/)
      insert_narrative(content.text, debateSection, doc)
    elsif content.text.match(/^地點：/)
      insert_narrative(content.text, debateSection, doc)
    elsif content.text.match(/^討論事項/)
      insert_narrative(content.text, debateSection, doc)
    elsif content.text.match(/^[^  ](\p{Word}+)：$/)
      # set speaker
      insert_speech(speech, debateSection, doc) unless speech == {} or speech[:content] == ''
      speech = {}
      speech[:speaker] = get_name(content.text, chairman)
      people += [speech[:speaker]] unless people.include? speech[:speaker]
      speech[:content] = ''
    elsif content.text.match(/^[  ]{2}/)
      speech_content = '<p>' + content.text.gsub('  ', '') + '</p>'
      speech[:content] +=  speech_content unless speech == {}
    else
      insert_speech(speech, debateSection, doc) unless speech == {}
      insert_narrative(content.text, debateSection, doc)
      speech[:content] = ''
    end
  end
  insert_speech(speech, debateSection, doc) unless speech == {} or speech[:content] == ''
  # puts speeches.to_json
  # puts people.to_json

  references = doc.at_css "references"
  people.each do |person|
    tlc_person = Nokogiri::XML::Node.new('TLCPerson', doc)
    tlc_person['id'] = person
    tlc_person['showAs'] = person
    tlc_person['href'] = "/ontology/person/#{person}"
    references << tlc_person
  end
  puts doc.to_xml
  write_file("akoma_ntosos/#{title}.an", doc.to_xml(indent: 2))
end

main()
