require 'pry'

unzipped = "~/scratch/jpkscr".gsub "~", ENV['HOME']

raw = File.open("#{unzipped}/index/0/segments/0/channels/vDeflection.dat", 'rb').read
max = [-1].pack("")
decoded = raw.unpack("N*")
binding.pry
