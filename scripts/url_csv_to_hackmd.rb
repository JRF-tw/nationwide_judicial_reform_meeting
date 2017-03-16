#!/usr/bin/env ruby

require 'nokogiri'
require 'json'
require 'open-uri'
require 'smarter_csv'

def get_html(url)
  page = open(url)
  html = Nokogiri::HTML(page.read)
end

def write_file(filename, content)
  File.open(filename,"w") do |f|
    f.write(content)
  end
end

def get_keywords(data)
  keywords = "#{data[:"作者"]}、#{data[:backgrounds]}、#{data[:"相關組別"]}、#{data[:"相關主題"]}、#{data[:"日期"]}".split('、').select{ |i| i != "" }.map{ |i| "##{i}" }.join(' ')
end

def add_backgrounds(data)
  data[:backgrounds] = "其他"
  if data[:"身分"]
    if data[:"作者"] == "有網友"
      data[:backgrounds] = "學者"
    elsif data[:"作者"] == "交通大學科技法律學院地院實習課程學生"
      data[:backgrounds] = "其他"
    elsif data[:"身分"].match(/法官|司法院院長|庭長/)
      data[:backgrounds] = "法官"
    elsif data[:"身分"].match(/律師/)
      data[:backgrounds] = "律師"
    elsif data[:"身分"].match(/檢察/)
      data[:backgrounds] = "檢察官"
    elsif data[:"身分"].match(/教授|講師|學者/)
      data[:backgrounds] = "學者"
    end
  end
  return data
end

def output_markdown(data, old_author, old_backgrounds)
  result = ''
  if old_author != data[:"作者"] || old_backgrounds != data[:"backgrounds"]
    result += "# #{data[:"作者"]}\n"
    result += "## backgrounds\n- #{data[:backgrounds]}\n\n"
    # result += "## relations\n- #{data[:"身分"]}\n\n" if data[:"身分"] && data[:"身分"].length > 0
  end
  result += "## articles\n"
  result += "### #{data[:"日期"].gsub("-", "/")} GMT0+8:00 #{data[:"連結"]}\n"
  result += "- "
  result += "<h2>#{data[:"標題"].gsub("#", "")}</h2>" if data[:"標題"]
  data[:contents].each do |content|
    result += "<p>#{content}</p>"
  end
  result += " "
  result += get_keywords(data)
  result += "\n\n"
  return result
end

def clean_string(str)
  str.gsub("\n", "").gsub("\r", "").gsub("\t", "").gsub(" ", " ").gsub("　", " ").strip if str
end

def get_appledaily_contents(data)
  # http://www.appledaily.com.tw/realtimenews/article/forum/20170217/1058081/
  html = get_html(data[:"連結"])
  data[:contents] = html.css('.articulum.trans').children.map{ |i| clean_string(i.text).gsub("《即時論壇》徵稿", "").gsub("你對新聞是否有想法不吐不快？本報特闢《即時論壇》，歡迎讀者投稿，對新聞時事表達意見。來稿請寄onlineopinions@appledaily.com.tw，文長以500字為度，一經錄用，將發布在《蘋果日報》即時新聞區，唯不付稿酬。請勿一稿兩投，本報有刪改權，當天未見報，請另行處理，不另退件或通知。", "").gsub("有話要說 投稿「即時論壇」", "").gsub(/^googletag\..*/, '') }.select{ |i| i != "" }
  data[:"平台"] = "蘋果日報"
  return data
end

def get_pnn_contents(data)
  # http://pnn.pts.org.tw/main/2017/03/06/%E7%B5%A6%E8%80%81%E5%8F%B8%E6%B3%95%E4%BA%BA%E7%9A%84%E4%B8%80%E5%B0%81%E6%83%85%E6%9B%B8%EF%BC%9A%E8%AB%87%E5%8F%B0%E7%81%A3%E5%8F%B8%E6%B3%95%E7%9A%84%E8%BD%89%E5%9E%8B%E5%95%8F%E9%A1%8C/
  html = get_html(data[:"連結"])
  data[:contents] = html.css('.entry').children.map{ |i| clean_string(i.text).gsub("本文內容不代表公共電視立場。", "") }.select{ |i| ! ["", "—"].include? i }
  data[:"平台"] = "公共電視PNN"
  return data
end

def get_storm_contents(data)
  # http://www.storm.mg/article/230530
  html = get_html(data[:"連結"])
  data[:contents] = html.css('.article-wrapper > article > p').map{ |i| clean_string(i.text) }.select{ |i| i != "" }
  data[:"平台"] = "風傳媒"
  return data
end

def get_upmedia_contents(data)
  # http://www.upmedia.mg/news_info.php?SerialNo=12152
  html = get_html(data[:"連結"])
  data[:contents] = html.css('.editor > p').map{|i| clean_string(i.text).gsub("【上報徵稿】", "").gsub("上報歡迎各界投書，來稿請寄至editor@upmedia.mg，並請附上真實姓名、聯絡方式與職業身分簡介。", "").gsub("一起加入Line好友（ID：@upmedia），或點網址https://line.me/ti/p/%40zsq4746x。", "") }.select{ |i| i != "" }
  data[:"平台"] = "上報"
  return data
end

def get_udn_contents(data)
  # https://udn.com/news/story/7340/2308151
  html = get_html(data[:"連結"])
  data[:contents] = html.css('#story_body_content > p').map{ |i| clean_string(i.text) }.select{ |i| i != "" }
  data[:"平台"] = "UDN"
  return data
end

def get_udn_opinion_contents(data)
  # http://opinion.udn.com/opinion/story/9668/2292796
  html = get_html(data[:"連結"])
  data[:contents] = html.css('#container > main > p').map{ |i| clean_string(i.text) }.select{ |i| i != "" }
  data[:"平台"] = "UDN 鳴人堂"
  return data
end

def get_ltn_contents(data)
  # http://talk.ltn.com.tw/article/paper/1083063
  html = get_html(data[:"連結"])
  data[:contents] = html.css('.cont > p').map{ |i| clean_string(i.text).gsub("《自由開講》是一個提供民眾對話的電子論壇，不論是對政治、經濟或社會、文化等新聞議題，有意見想表達、有話不吐不快，都歡迎你熱烈投稿。文長700字內為優，來稿請附真實姓名（必寫。有筆名請另註）、職業、聯絡電話、E-mail帳號。本報有錄取及刪修權，不付稿酬；錄用與否將不另行通知。投稿信箱：LTNTALK@gmail.com", "") }.select{ |i| i != "" }
  data[:"平台"] = "自由時報"
  return data
end

def get_newtalk_contents(data)
  # https://newtalk.tw/news/view/2017-03-10/82760
  html = get_html(data[:"連結"])
  data[:contents] = html.css('.fontsize.news-content > div > p').map{ |i| clean_string(i.text) }.select{ |i| i != "" }
  data[:"平台"] = "新頭殼"
  return data
end

def get_chinatime_contents(data)
  # http://opinion.chinatimes.com/20170307006683-262105
  html = get_html(data[:"連結"])
  data[:contents] = html.css('article.clear-fix > article.clear-fix > p').map{ |i| clean_string(i.text) }.select{ |i| i != "" }
  data[:"平台"] = "中國時報"
  return data
end

def get_theinitium_contents(data)
  # https://theinitium.com/article/20160518-opinion-lin-judicialreform/
  html = get_html(data[:"連結"])
  data[:contents] = html.css('.article-content > p').map{ |i| clean_string(i.text) }.select{ |i| i != "" }
  data[:"平台"] = "端傳媒"
  return data
end

def get_twreporter_contents(data)
  # https://www.twreporter.org/a/oped-judicial-reform
  html = get_html(data[:"連結"])
  data[:contents] = html.css('.Paragraph__paragraph___39oI_.Common__inner-block___2cOrF').map{ |i| clean_string(i.text) }.select{ |i| i != "" }
  data[:"平台"] = "報導者"
  return data
end

def get_jrf_contents(data)
  # https://www.jrf.org.tw/articles/1218
  html = get_html(data[:"連結"])
  data[:contents] = html.css('.text').children.map{ |i| clean_string(i.text) }.select{ |i| i != "" }
  data[:"平台"] = "民間司改會"
  return data
end

csv = SmarterCSV.process(ARGV[0])
result = "總統府司法改革國是會議相關投書彙整\n\n"
author = nil
backgrounds = nil
all_keywords = []
all_authors = {
  procedures: [],
  lawyers: [],
  judges: [],
  theachers: [],
  others: []
}
all_dates = []
csv.each do |data|
  puts data[:"連結"]
  uri = URI.parse(data[:"連結"])
  data[:contents] = []
  data = add_backgrounds(data)
  if uri.host == 'www.appledaily.com.tw'
    data = get_appledaily_contents(data)
  elsif uri.host == 'www.storm.mg'
    data = get_storm_contents(data)
  elsif uri.host == 'pnn.pts.org.tw'
    data = get_pnn_contents(data)
  elsif uri.host == 'www.upmedia.mg'
    data = get_upmedia_contents(data)
  elsif uri.host == 'udn.com'
    data = get_udn_contents(data)
  elsif uri.host == 'opinion.udn.com'
    data = get_udn_opinion_contents(data)
  elsif uri.host == 'talk.ltn.com.tw'
    data = get_ltn_contents(data)
  elsif uri.host == 'theinitium.com'
    data = get_theinitium_contents(data)
  elsif uri.host == 'www.twreporter.org'
    data = get_twreporter_contents(data)
  elsif uri.host == 'newtalk.tw'
    data = get_newtalk_contents(data)
  elsif uri.host == 'www.jrf.org.tw'
    data = get_jrf_contents(data)
  else
    data[:contents] = data[:"內文"].split("\n").map{ |i| clean_string(i) }.select{ |i| i != "" } if data[:"內文"]
    data[:"平台"] = "其他平台"
  end
  keywords = data[:"相關主題"].to_s.split('、').select{ |i| i != "" }.map{ |i| all_keywords << i unless all_keywords.include?(i) }
  result += output_markdown(data, author, backgrounds)
  author = data[:"作者"]
  all_dates << data[:"日期"] unless all_dates.include?(data[:"日期"])
  backgrounds = data[:backgrounds]
  if data[:backgrounds] == "法官"
    all_authors[:judges] << author unless all_authors[:judges].include?(author)
  elsif data[:backgrounds] == "律師"
    all_authors[:lawyers] << author unless all_authors[:lawyers].include?(author)
  elsif data[:backgrounds] == "檢察官"
    all_authors[:procedures] << author unless all_authors[:procedures].include?(author)
  elsif data[:backgrounds] == "學者"
    all_authors[:theachers] << author unless all_authors[:theachers].include?(author)
  else
    all_authors[:others] << author unless all_authors[:others].include?(author)
  end
end

all_keywords = all_keywords - ["第一組", "第二組", "第三組", "第四組", "第五組"]

result += "\n\n\n___
```htmlembedded=
<p>
2017年2月起，總統府召開司法改革國是會議，會議期間，媒體上出現大量司法制度相關投書，此為投書整理。
</p>
```\n\n"

result += "- 作者\n"
result += "  - 法官\n"
all_authors[:judges].each do |author|
  result += "    - #{author}\n"
end
result += "  - 檢察官\n"
all_authors[:procedures].each do |author|
  result += "    - #{author}\n"
end
result += "  - 律師\n"
all_authors[:lawyers].each do |author|
  result += "    - #{author}\n"
end
result += "  - 學者\n"
all_authors[:theachers].each do |author|
  result += "    - #{author}\n"
end
result += "  - 其他\n"
all_authors[:others].each do |author|
  result += "    - #{author}\n"
end
result += "\n"

result += "- 投書平台\n  - 蘋果日報\n  - 公共電視PNN\n  - 上報\n  - 風傳媒\n  - UDN\n  - UDN 鳴人堂\n  - 自由時報\n  - 中國時報\n  - 新頭殼\n  - 端傳媒\n  - 報導者\n  - 民間司改會\n  - 其他平台\n\n"

result += "- 司改國是會議分組\n  - 第一組\n  - 第二組\n  - 第三組\n  - 第四組\n  - 第五組\n\n"
result += "- 相關議題\n"
all_keywords.sort.each do |keyword|
  result += "  - #{keyword}\n"
end
result += "\n"

result += "- 投書日期\n"
all_dates.sort.each do |date|
  result += "  - #{date}\n"
end
result += "\n"
write_file('result.md', result)