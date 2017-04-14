#!/usr/bin/env ruby

require 'nokogiri'
require 'json'
require 'open-uri'
require 'date'
require 'smarter_csv'

Dir.chdir(File.dirname(__FILE__))

def format_issue(issue)
  issue[:"會議討論項目編號"] = issue[:"會議討論項目編號"] ? issue[:"會議討論項目編號"].split('、') : []
  issue[:"討論日期"] = issue[:"討論日期"] ? issue[:"討論日期"].split('、') : []
  issue[:"議題"] = issue[:"議題"].gsub('、', '||')
  return issue
end

$documents = []
$texts = []
$members = JSON.parse(File.read('./members.json'))
$issues = SmarterCSV.process('./issues.csv').map{ |i| format_issue(i) }
$result = "總統府司法改革國是會議資料彙整\n\n"
$all_authors = {
  procedures: [],
  lawyers: [],
  judges: [],
  theachers: [],
  others: [],
  governments: []
}
$all_dates = []
$all_issues = []
$all_issue_no = []
$all_issue_name = []

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

def get_json(url)
  page = open(url)
  result = JSON.parse(page.read)
end

def get_list(url)
  puts url
  begin
    json = get_json(url)
    if json['status'] == 'success'
      return json['data']['rows']
    else
      return false
    end
  rescue
    return false
  end
end

def get_body(url)
  puts url
  begin
    json = get_json(url)
    if json['status'] == 'success'
      return Nokogiri::HTML(json['data']['body']), json['data']['caption'], DateTime.parse(json['data']['time'])
    else
      return false, false, false
    end
  rescue
    return false, false, false
  end
end

def google_drive_anchor?(anchor)
  if anchor.text == ''
    return false
  end
  uri = URI.parse(anchor['href'])
  return uri.host == 'drive.google.com'
end

def parse_anchor(anchor, group, time)
  result = {}
  result[:url] = anchor['href']
  result[:text] = anchor.text
  result[:date] = time.strftime('%Y-%m-%d')
  result[:group] = group
  result = parse_anchor_author(result)
  result = parse_anchor_issue(result)
  return result
end

def parse_anchor_author(anchor)
  anchor[:author_group] = nil
  anchor[:backgrounds] = nil
  anchor[:organizer] = false
  if anchor[:text].match(/司法院/)
    anchor[:author] = '司法院'
    anchor[:law_type] = '法官'
  elsif anchor[:text].match(/法務部/)
    anchor[:author] = '法務部'
    anchor[:law_type] = '檢察官'
  else
    $members.each do |m|
      if anchor[:text].match(/#{m['姓名']}/)
        anchor[:author] = m['姓名']
        anchor[:author_group] = m['小組分組']
        anchor[:law_type] = m['法律人類別']
        anchor[:backgrounds] = m['現職']
        anchor[:organizer] = m['籌備委員']
        break
      end
    end
  end
  return anchor
end

def parse_anchor_issue(anchor)
  issues = anchor[:text].scan(/資料編號-(.*\d)/)
  anchor[:issue_no] = []
  anchor[:issue_name] = []
  if issues
    issue = issues.flatten.first
    if issue && issue.match(/、/)
      issue_num = issue.match(/\d+-\d+-./).to_a.first
      # issue = issue.gsub(issue_num, '').split('、').map{ |i| issue_num + i }.join('、')
      issue = issue.gsub(issue_num, '').split('、').map{ |i| issue_num + i }
      issue.each do |item|
        $issues.each do |i|
          i[:"會議討論項目編號"].each do |j|
            if j == item
              anchor[:issue_no] << i[:"議題清單編號"]
              anchor[:issue_name] << i[:"議題"]
              $all_issue_no << i[:"議題清單編號"] unless $all_issue_no.include?(i[:"議題清單編號"])
              $all_issue_name << i[:"議題"] unless $all_issue_name.include?(i[:"議題"])
            end
          end
        end
      end
      issue = issue.join('、')
    end
    anchor[:issue] = issue
  else
    anchor[:issue] = nil
  end
  return anchor
end

def get_keywords(data)
  keywords = "#{data[:author]}、#{data[:group]}"
  keywords += "、#{data[:author_group]}委員" if data[:author_group]
  keywords += "、籌備委員" if data[:organizer]
  keywords += "、#{data[:law_type]}" if data[:law_type]
  keywords += "、#{data[:issue]}" if data[:issue]
  keywords += "、#{data[:issue_no].join('、')}" if data[:issue_no]
  keywords += "、#{data[:issue_name].join('、')}" if data[:issue_name]
  keywords += "、#{data[:date]}"
  keywords.split('、').select{ |i| i != "" }.map{ |i| "##{i}".gsub('||', '、') }.join(' ')
end

def output_markdown(data)
  result = ''
  result += "# #{data[:author]}\n"
  result += "## backgrounds\n- #{data[:group]}\n\n" if data[:group]
  # result += "## relations\n- #{data[:"身分"]}\n\n" if data[:"身分"] && data[:"身分"].length > 0
  result += "## articles\n"
  result += "### #{data[:date].gsub("-", "/")} GMT0+8:00 #{data[:url]}\n"
  result += "- "
  result += "<h3><a href=\"#{data[:url]}\" target=\"_blank\">#{data[:text].gsub("#", "")}</a></h3>"
  result += " "
  result += get_keywords(data)
  result += "\n\n"
  return result
end

def process_url(url)
  status = false
  body, caption, time = get_body(url)
  if body
    group = caption.match(/第[一二三四五]分?組|籌備/).to_a.first.gsub('分', '')
    if group == '籌備'
      group = '籌備會議'
    end
    anchors = body.css('a').select { |a| google_drive_anchor?(a) }
    anchors.each do |anchor|
      data = parse_anchor(anchor, group, time)
      unless $texts.include? data[:text]
        if status == false
          status = true
        end
        $documents << data
        $texts << data[:text]
        if data[:law_type] == "法官"
          $all_authors[:judges] << data[:author] unless $all_authors[:judges].include?(data[:author])
        elsif data[:law_type] == "律師"
          $all_authors[:lawyers] << data[:author] unless $all_authors[:lawyers].include?(data[:author])
        elsif data[:law_type] == "檢察官"
          $all_authors[:procedures] << data[:author] unless $all_authors[:procedures].include?(data[:author])
        elsif data[:law_type] == "學者"
          $all_authors[:theachers] << data[:author] unless $all_authors[:theachers].include?(data[:author])
        else
          $all_authors[:others] << data[:author] unless $all_authors[:others].include?(data[:author])
        end
        $all_dates << data[:date] unless $all_dates.include?(data[:date])
        if data[:issue]
          data[:issue].split('、').each do |issue|
            $all_issues << issue unless $all_issues.include?(issue)
          end
        end
      end
    end
  end
  return status
end

list_url = 'https://justice.president.gov.tw/apis/portal/meeting?category_seq=2&dir=jump&page_number=1&page_size=50'

list = get_list(list_url)
list.sort_by{ |item| item['id'] }.each do |item|
  url = "https://justice.president.gov.tw/apis/portal/meeting/" + item['id'].to_s
  process_url(url)
end

failed_times = 0
num = 17

while failed_times < 5
  num += 1
  url = "https://justice.president.gov.tw/apis/portal/news/#{num}"
  status = process_url(url)
  unless status
    failed_times += 1
  else
    failed_times = 0
  end
end

$documents = $documents.sort_by { |item| item[:date] }
$documents.each do |data|
  $result += output_markdown(data)
end

#puts $documents.to_json
#puts $texts.to_json

$result += "\n\n\n___
```htmlembedded=
<p>
2017年2月起，總統府召開<a href=\"https://justice.president.gov.tw/\" target=\"_blank\">司法改革國是會議</a>，會議期間，委員提供大量資料供會議參考，此為民間司改會所製作之投書整理。
</p>
<p>本會議資料整理更新時間：#{DateTime.now.strftime('%Y年%m月%d日 %H:%M:%S')}</p>
<ul>
  <li><a href=\"http://bit.ly/pj-links1\" target=\"_blank\">司改國是會議投書彙整</a></li>
  <li><a href=\"https://www.jrf.org.tw/\" target=\"_blank\">民間司改會網站</a></li>
  <li><a href=\"http://fb.com/jrf.tw\" target=\"_blank\">民間司改會粉專</a></li>
  <li><a href=\"http://bit.ly/2m37Aha\" target=\"_blank\">關於Debater辯論家</a></li>
</ul>
```\n\n"

$result += "- 作者\n"
$result += "  - 法官\n"
$all_authors[:judges].each do |author|
  $result += "    - #{author}\n"
end
$result += "  - 檢察官\n"
$all_authors[:procedures].each do |author|
  $result += "    - #{author}\n"
end
$result += "  - 律師\n"
$all_authors[:lawyers].each do |author|
  $result += "    - #{author}\n"
end
$result += "  - 學者\n"
$all_authors[:theachers].each do |author|
  $result += "    - #{author}\n"
end
$result += "  - 其他\n"
$all_authors[:others].each do |author|
  $result += "    - #{author}\n"
end
$result += "\n"

$result += "- 提供委員分組\n  - 第一組委員\n  - 第二組委員\n  - 第三組委員\n  - 第四組委員\n  - 第五組委員\n  - 籌備委員\n\n"
$result += "- 司改國是會議分組\n  - 第一組\n  - 第二組\n  - 第三組\n  - 第四組\n  - 第五組\n  - 籌備會議\n\n"

$result += "- 會議編號分類\n"
$all_issues.sort.each do |issue|
  $result += "  - #{issue}\n"
end

$result += "- 議題編號\n"
$all_issue_no.sort.each do |issue|
  $result += "  - #{issue}\n"
end

$result += "- 議題\n"
$all_issue_name.sort.each do |issue|
  $result += "  - #{issue.gsub('||', '、')}\n"
end

$result += "- 日期\n"
$all_dates.sort.each do |date|
  $result += "  - #{date}\n"
end
$result += "\n"
write_file('result1.md', $result)
write_file('result1.json', $documents.to_json)

# api:
# https://justice.president.gov.tw/apis/portal/news/18
# https://justice.president.gov.tw/apis/portal/meeting?category_seq=2&dir=jump&page_number=1&page_size=10
# https://justice.president.gov.tw/apis/portal/meeting/26

