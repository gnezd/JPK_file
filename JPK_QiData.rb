# qi-data(quantative image) reading class
require 'time'
class JPK_QiData
  attr_accessor :name, :properties, :channels, :conversions, :time_period, :size, :force_settings, :mode, :channels
  def initialize(path, name, options = {})
    # Check if file exists
    @name = name
    @properties = {}
    @path = path
    raise "#{@path} cannot be found" unless File.exist? @path


    if options[:unzipped]
      @scratch_path = options[:unzipped]
    else
      # Create scratch space
      timestamp = Time.now.strftime "%d%b%Y-%H%M%S"
      @scratch_path = options[:scratch_path] ? options[:scratch_path] : "#{ENV['HOME']}/jpkscr/#{timestamp}"
      FileUtils.mkdir_p @scratch_path

      # Actually unzip it
      t0 = Time.now
      puts "Starting to unpack qi-data file #{@path}"
      shell_result = `unzip '#{@path}' -d '#{@scratch_path}' 2>&1`
      raise "Error during unzipping: #{shell_result}" if shell_result =~ /cannot|not\sfound/
      t_unzip = Time.now - t0
      puts "Unpacking to #{@scratch_path} completed in #{t_unzip} s."
    end

    # Read .properties
    @properties.merge! read_properties(@scratch_path+'/header.properties')
    @properties.merge! read_properties(@scratch_path+'/shared-data/header.properties')

    @size = @properties['quantitative-imaging-map']['indexes']['max'] - (@properties['quantitative-imaging-map']['indexes']['min']-1)
    @time_period = [
      Time.parse(@properties['quantitative-imaging-map']['start-time']), 
      Time.parse(@properties['quantitative-imaging-map']['end-time'])
    ]
    @force_settings = @properties['quantitative-imaging-map']['settings']['force-settings']
    @mode = @properties['quantitative-imaging-map']['feedback-mode']['name']

    # Assume that we always have two segments [approach, retraction]
    raise "Segment number != 2" if @properties['force-segment-header-info'].size != 2
    # Get the channels (let's assume this doesn't change across different pixels)
    raise "lcd-infos(#{@properties['lcd-infos']['count']}) != lcd-info.size (#{@properties['lcd-info'].size})" unless @properties['lcd-infos']['count'] == @properties['lcd-info'].size
    @channels = (0..@properties['lcd-info'].size-1).map {|ch| @properties['lcd-info'][ch]}

    # Get channel .dat file name from 1st pixel 0th segment, again assume it's constancy
    exmpl_segment_header = read_properties(@scratch_path+'/index/0/segments/0/segment-header.properties')
    channel_names = exmpl_segment_header['channels']['list'].split ' '
    raise "Channel names mismatch" unless channel_names == @channels.map{|ch| ch['channel']['name']}
    
    # Inject the .dat paths and get conversion "passes" for each channel
    @decoders = Array.new(@channels.size)
    @conversions = Array.new(@channels.size) {[]}
    (0..@channels.size-1).each do |ch|
      # Path to .dat
      @channels[ch]['channel']['dat_path'] = exmpl_segment_header['channel'][channel_names[ch]]['data']['file']['name']
      # Conversion pass raw to V
      # Convention: ax + b, stored as [a, b]
      @decoders[ch] = [
        @properties['lcd-info'][ch]['encoder']['scaling']['multiplier'],
        @properties['lcd-info'][ch]['encoder']['scaling']['offset']
      ]
      # V to m if exists
      defined_conversions = (@properties['lcd-info'][ch]['conversion-set']['conversion'].filter {|k,v| v['defined']=='true'}).keys
      defined_conversions.each do |conversion|
        # In form of [name, a, b]
        @conversions[ch].push [
          conversion,
          @properties['lcd-info'][0]['conversion-set']['conversion'][conversion]['scaling']['multiplier'],
          @properties['lcd-info'][0]['conversion-set']['conversion'][conversion]['scaling']['offset']
        ]
      end
    end
  end

  # Extract pixel i, segment s
  def at(i, s, options={})
    raise "i (#{i}}) out of bound (#{@size})" if i > @size
    raise "s (#{s}) out of bound" if s > 1
    segment_path = "#{@scratch_path}/index/#{i.to_s}/segments/#{s.to_s}"
    properties = read_properties "#{segment_path}/segment-header.properties"

    data = Array.new(@channels.size) {Array.new(properties['force-segment-header']['num-points']) {0.0}}
    @channels.each do |ch|
      raw = File.open("#{segment_path}/channels/#{ch['channel'['dat_path']]}", "r") {|f| f.read.unpack("N*").map{|n| num >= 2147483648 ? num -= 4294967296 : num}}
    end
  end

  def show_conversions
    puts "Decoders: #{@decoders}"
    puts "Conversionss: #{@conversions}"
  end

  def read_properties(fin)
    lines = File.open(fin, 'r') {|f| f.readlines}
    config = {}
    lines.each do |line|
      # Matching for (something not '=')=(value)
      flag, value = line.match(/([^\=]+)\=([^\n]+)\n/)&.[](1..2)
      
      # If it turns out to be a valid a.b=c line
      if flag
        case value
        when /^\d+$/
          value = value.to_i
        when /^-?\d+\.\d*E?-?\d*$/
          value = value.to_f
        end

        tags = flag.split('.').map {|node| node=~/^\d+$/ ? node.to_i : node}
        sprout = config

        while tags.size > 1 # If we have more than one level remaining
          node = tags.shift # Take the top most level node name remaining
          sprout[node] = {} unless sprout[node]
          sprout = sprout[node]
        end
        sprout[tags[0]] = value
      end
    end
    config
  end
end