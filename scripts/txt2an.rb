#!/usr/bin/env ruby

require 'nokogiri'
require 'json'
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

def get_name(name, chairman = nil)
  name = name.gsub('：', '')
  if chairman and name == '主席'
    return chairman
  end
  name = name.gsub('委員兼召集人', '').gsub('分組委員', '').gsub('籌備委員', '').gsub('專門委員', '').gsub('委員', '').gsub('副召集人', '').gsub('召集人', '').gsub('處長', '').gsub('律師', '').
    gsub('大法官', '').gsub('法官', '').gsub('檢察官', '').gsub('副主席', '').gsub('副執行秘書', '').gsub('執行秘書', '').gsub('教授', '').gsub('理事長', '').
    gsub('理事', '').gsub('副院長', '').gsub('院長', '').gsub('先生', '').gsub('副廳長', '').gsub('關係機關代表', '').gsub('機關代表', '').
    gsub('簡任祕書', '').gsub('部長', '').gsub('副組長', '').gsub('組長', '').gsub('民事廳', '').gsub('書記處', '').gsub('政務', '').
    gsub('廳長', '').gsub('主任', '').gsub('社長', '').gsub('副祕書長', '').gsub('秘書長', '').gsub('副執行長', '').gsub('執行長', '').gsub('次長', '').gsub('副總隊長', '').gsub('副局長', '').
    gsub('代表', '').gsub('先生', '').gsub('小姐', '').gsub('主席', '').gsub('敎授', '').gsub('庭長', '').gsub('法庭之友', '').
    gsub('立委', '').gsub('議題整理組', '').gsub('新聞組', '').gsub(/（.*）/, '').gsub('執秘', '').gsub('關係機關方訴訟代理人', '').gsub('聲請人代方訴訟人', '').
    gsub('老師', '').gsub('書記官', '').gsub('鑑定人', '').gsub('聲請人', '').gsub('關係機關訴訟代理人', '').gsub('董事長', '').gsub('機關訴訟代理人', '').
    gsub('聲請方訴訟代理人', '').gsub('副研究員', '').gsub('助研究員', '').gsub('研究員', '').gsub('研究助理', '').gsub('審判長', '').gsub('杜銘哲案訴訟代理人', '').gsub('黃國昌案訴訟代理人', '').
    gsub('司法院', '').gsub('法務部', '').gsub('總統府', '').gsub('副司長', '').gsub('司長', '').gsub('秘書', '').gsub('籌委', '').gsub('助理', '').gsub('司儀', '').
    gsub('發言', '').gsub('科長', '').gsub('副署長', '').gsub('署長', '').gsub('提問人', '').gsub('會長', '').gsub('刑事廳', '').gsub('司儀', '').gsub('司法行政廳', '').gsub('檢察司', '')

end

def get_chairman(contents)
  chairman = nil
  contents.each do |content|
    if content.match(/主席：(\p{Word}+)/)
      chairman = content.gsub('主席：', '').gsub('委員兼召集人', '').gsub('教授', '').
        gsub('理事', '').gsub('副院長', '').gsub('院長', '').gsub('部長', '').gsub('委員', '').
        gsub('長長', '長')
    end
  end
  chairman
end

def get_conventioneers(content)
  content.gsub('出席人員：', '').gsub('出席：', '').gsub('（依簽名先後為序）', '').gsub('（詳簽到單）', '').split('、')
end

def get_hearers(content)
  content.gsub('列席人員：', '').gsub('（依簽名先後為序）', '').gsub('（詳簽到單）', '').split('、')
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
  unless speech[:content] == ''
    speech_node = Nokogiri::XML::Node.new('speech', doc)
    speech_node['by'] = "##{speech[:speaker]}"
    from_node = Nokogiri::XML::Node.new('from', doc)
    from_node.content = speech[:speaker]
    from_node.parent = speech_node
    from_node.add_next_sibling(speech[:content])
    debateSection << speech_node
  end
end

def insert_narrative(narrative, debateSection, doc)
  narrative_node = Nokogiri::XML::Node.new('narrative', doc)
  narrative_node.content = narrative.strip
  debateSection << narrative_node
end

def main
  file = ARGV[0]
  txt = File.readlines(file).map{ |i| i.to_s.gsub("\n", '').gsub("\r", '').gsub(' ', ' ').gsub('︰', '：') }
  title = txt.shift
  contents = txt
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
  # doc.css('docTitle').first.content = '1999年全國司法改革會議'
  doc.css('docTitle').first.content = '測試區'
  doc.at_css('heading').content = title
  debateSection = doc.at_css "debateSection"
  contents.each do |content|
    text = content
    if text.match(/^\s*$/)
      next
    elsif text.match(/^時間：/)
      insert_narrative(text, debateSection, doc)
      starttime, endtime = get_datetime(text)
    elsif text.match(/^出席人員：/)
      insert_narrative(text, debateSection, doc)
      # people += get_conventioneers(text)
    elsif text.match(/^列席人員：/)
      insert_narrative(text, debateSection, doc)
    elsif text.match(/^主席：(\p{Word}+)/)
      insert_narrative(text, debateSection, doc)
    elsif text.match(/^紀錄：/)
      insert_narrative(text, debateSection, doc)
    elsif text.match(/^地點：/)
      insert_narrative(text, debateSection, doc)
    elsif text.match(/^討論事項/)
      insert_narrative(text, debateSection, doc)
    elsif text.match(/^[^  ].*：$/)
      # set speaker
      insert_speech(speech, debateSection, doc) unless speech == {} or speech[:content] == ''
      speech = {}
      speech[:speaker] = get_name(text, chairman)
      people += [speech[:speaker]] unless people.include? speech[:speaker]
      speech[:content] = ''
    elsif text.match(/^[  ]{2}/)
      speech_content = text.gsub(/^[  ]{2}/, '').strip
      unless speech_content == ''
        speech_content = '<p>' + text.gsub(/^[  ]{2}/, '').strip + '</p>'
        speech[:content] +=  speech_content unless speech == {}
      end
    else
      text = text.strip
      unless text == ''
        insert_speech(speech, debateSection, doc) unless speech == {}
        insert_narrative(text, debateSection, doc)
        speech[:content] = ''
      end
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
    tlc_person['href'] = "/ontology/person/#{person.gsub(' ', '-')}"
    references << tlc_person
  end
  puts doc.to_xml
  write_file("akoma_ntosos/#{title}.an", doc.to_xml(indent: 2))
end

main()
