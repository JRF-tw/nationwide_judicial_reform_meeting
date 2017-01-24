
require 'nokogiri'
require 'json'
require 'open-uri'
require 'time'

url_list = ["http://www.moi.gov.tw/dca/03caucus_10401.aspx","http://www.moi.gov.tw/dca/03caucus_10301.aspx","http://www.moi.gov.tw/dca/03caucus_10201.aspx","http://www.moi.gov.tw/dca/03caucus_10101.aspx","http://www.moi.gov.tw/dca/03caucus_10001.aspx","http://www.moi.gov.tw/dca/03caucus_9901.aspx","http://www.moi.gov.tw/dca/03caucus_9801.aspx","http://www.moi.gov.tw/dca/03caucus_005.aspx","http://www.moi.gov.tw/dca/03caucus_002.aspx","http://www.moi.gov.tw/dca/03caucus_001.aspx","http://www.moi.gov.tw/dca/03caucus_10402.aspx","http://www.moi.gov.tw/dca/03caucus_10302.aspx","http://www.moi.gov.tw/dca/03caucus_10202.aspx","http://www.moi.gov.tw/dca/03caucus_10102.aspx","http://www.moi.gov.tw/dca/03caucus_10002.aspx","http://www.moi.gov.tw/dca/03caucus_9902.aspx","http://www.moi.gov.tw/dca/03caucus_9802.aspx","http://www.moi.gov.tw/dca/03caucus_006.aspx","http://www.moi.gov.tw/dca/03caucus_004.aspx","http://www.moi.gov.tw/dca/03caucus_003.aspx"]

def get_html(url)
  page = open(url)
  html = Nokogiri::HTML(page.read)
end

def download(url)
  puts "download #{url[:url]}"
  filename = "#{url[:url].split('/')[-2]}/#{url[:url].split('/')[-2]}年#{url[:name]}財務報表.pdf"
  File.open(filename, "wb") do |saved_file|
    # the following "open" is provided by open-uri
    open(url[:url], "rb") do |read_file|
      saved_file.write(read_file.read)
    end
  end
  sleep(1)
end


url_list.each do |url|
  html = get_html(url)
  link_list = html.css('td.main_bg01 table a').map { |link| { name: link.text, url: "http://www.moi.gov.tw/dca/#{link['href']}"} }
  pdf_list = link_list.select { |url| url[:url].split('.').last == 'pdf' }
  puts pdf_list.to_json
  pdf_list.each do |pdf|
    download(pdf)
  end
end


