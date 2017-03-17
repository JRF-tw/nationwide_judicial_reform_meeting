#!/usr/bin/env ruby

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
    gsub('!', '！').
    gsub(';', '；').
    gsub('||', ' ')
  if line[-2] != '：' && line[0] != "（"
    line = "  " + line
  end
  return line
end

contents = []

File.readlines(ARGV[0]).each do |line|
  contents << clean_line(line)
end

File.open('output.txt',"w") do |f|
  f.write(contents.join(""))
end
