require './JPK_QiData'
require 'pry'

qi1 = JPK_QiData.new("./1.jpk-qi-data", 'squares', {unzipped: "#{ENV['HOME']}/jpkscr/07Jun2023-112437"})

# Beautify properties output
level = 0
beautified = []
linebuff = ""
qi1.properties.to_s.each_char do |c|
  case c
  when ','
    if linebuff.size > 0 
      beautified.push ' '*level + linebuff + ','
    else
      beautified.last << ','
    end
    linebuff = ""
  when '{'
    beautified.push ' '*level + linebuff
    linebuff = ""
    beautified.push ' '*level + '{'
    level += 1
  when '}'
    beautified.push ' '*level + linebuff if linebuff.size > 0
    linebuff = ""
    level -= 1
    beautified.push ' '*level + '}'
  else
    linebuff << c
  end
end

File.open("./qidata_file_properties", "w") {|f| f.puts beautified}
binding.pry