require 'pry'

dats = Dir.glob './*.dat'
raw = File.open(dats[0], 'rb').read
puts raw.size

decode_scheme = 'N*'
puts dats
ars = dats.map{|file| File.open(file, 'rb').read.unpack(decode_scheme)}
fout = File.open('out', 'w')
(0..ars[0].size-1).each do |i|
  fout.puts ((0..ars.size-1).map {|j| ars[j][i]}).join "\t"
end
fout.close

