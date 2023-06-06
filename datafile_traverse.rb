require 'zip'
require 'pry'
require '~/spect_toolkit/lib'

def unzip(datafile)
  t0 = Time.now
  puts "Starting to unzip at #{t0}"
  target_dir = '~/scratch/'+Time.now.strftime('%d%h-%H%M%S')
  `unzip -q '#{datafile}' -d '#{target_dir}'`
  puts "Finished unzipping at #{Time.now}, took #{Time.now-t0} seconds"
  target_dir
end

class AFMPixel
  attr_accessor :segments, :no
  def initialize(path, no, options = {}) # Unzipped path, pixel number
    @no = no
    pixel_path = path+'/index/'+no.to_s
    raise "Pixel number should be integer!" unless no.is_a? Integer
    raise "Pixel #{no} of datafile at #{path} wasn't found" unless Dir.exist? pixel_path

    segment_ids = Dir.glob("#{pixel_path}/segments/*").map {|dirname| File.basename(dirname).to_i}
    @segments = Array.new(segment_ids.size)
    segment_ids.each do |segment_id|
      # Take only height + vDef for now

      heights_a = File.open("#{pixel_path}/segments/#{segment_id.to_s}/channels/height.dat", 'rb').read.unpack("N*").map {|num| num -= 4294967296 if num >= 2147483648
        # Encoder scaling multiplier and offset
        num = num * 8.889562452419094E-9 + 19.08322000444478
        # Conversion-set scaling multiplier and offset
        num = num * -1.3095731367786284E-7 + 4.999087227523665E-6
        # μm looks better
        num = num * 1E6
    }
      vDef_a = File.open("#{pixel_path}/segments/#{segment_id.to_s}/channels/vDeflection.dat", 'rb').read.unpack("N*").map {|num| num -= 4294967296 if num >= 2147483648
      # Encoder scaling. Conversion set absent. mV is mV.
      num = num*5.571976795178424E-9+4.3918941083355846E-4}
      puts "doing segment #{segment_id} got #{heights_a.size} - #{vDef_a.size}"
      @segments[segment_id] = (GSL::Matrix[heights_a, vDef_a]).transpose
    end

    def plot(outdir = nil)
      outdir = Time.now.strftime('%d%h-%H%M%S') unless outdir
      Dir.mkdir outdir unless Dir.exist? outdir
      gpout = File.new(outdir+'/gplot', 'w')
      gpdata = ""
      plots = []

      segments.each_index do |s|
        gpdata += gplot_datablock("seg#{s.to_s}", @segments[s])
        plots.push "$seg#{s.to_s} w lines t '#{s.to_s}'"
      end

gplot_content = <<EOGPL
set title 'pixel #{@no.to_s}'
set terminal svg standalone mouse
set output '#{outdir}/#{@no.to_s}.svg'
plot #{plots.join(", \\\n")}
#set xrange [GPVAL_X_MAX:GPVAL_X_MIN]
set ylabel 'vDeflection'
set xlabel 'height'
set output '#{outdir}/#{@no.to_s}.svg'
replot

EOGPL

      gpout.puts gpdata
      gpout.puts gplot_content
      gpout.close
      `gnuplot #{outdir}/gplot`
    end
  end
end

unzipped = "~/scratch/jpkscr".gsub "~", ENV['HOME']
puts "Finding pixels"
pxes = Dir.glob unzipped+'/index/*'
puts "Found #{pxes.size} pixels"
px = AFMPixel.new(unzipped, 0)
px.plot('outputs/px0')

px = AFMPixel.new(unzipped, 1)
px.plot('outputs/px1')