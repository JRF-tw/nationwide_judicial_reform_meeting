#!/usr/bin/env ruby

require 'json'

def clean_line(line)
  line = line.
    gsub(/(\w)\p{Blank}(\w)/, '\1||\2').
    gsub(' ', '').
    gsub(' ', '').
    gsub('　', '').
    gsub('(', '（').
    gsub(')', '）').
    gsub('?', '？').
    gsub(":", "：").
    gsub('︰', '：').
    gsub('!', '！').
    gsub(';', '；').
    gsub('||', ' ').
    gsub('...', '…').
    gsub(/…+/, '…').
    gsub('…', '……').
    gsub(/(\d),(\d)/, '\1||\2').
    gsub(',', '，').
    gsub('||', ',')
  if line[-2] != '：' &&
      line[0] != "（" &&
      # line[1] != "、" &&
      !line.match(/^(時間|出席人員|列席人員|出席者|列席者|主席|紀錄|記錄|地點)：/) &&
      !line.match(/^討論事項/) &&
      line != "\n"
    line = "  " + line
  elsif line[-2] == '：'
    if line.length > 25
      line = "  " + line.gsub("\n", " \n")
    elsif line[1] == "、"
      line = line.gsub("\n", " \n")
    elsif line == "委員：\n"
      line = "不知名" + line
    elsif line == "司儀：\n"
      line = "王孟涵：\n"
    end
  end
  return line
end

contents = []

File.readlines(ARGV[0]).each do |line|
  contents << clean_line(line)
end

contents[0] = contents[0].gsub(' ', '')

# puts contents.to_json

File.open('output.txt',"w") do |f|
  f.write(contents.join(""))
end


# find ^  .*： \n
# ^.{8,}：\n
# ^  .、
# ^（
# ^委員
