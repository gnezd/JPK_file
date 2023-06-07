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

    @conversion = Array.new(@channels.size)
    
    # Get channel .dat file name from 1st pixel 0th segment, again assume it's constancy
    exmpl_segment_header = read_properties(@scratch_path+'/index/0/segments/0/segment-header.properties')
    channel_names = exmpl_segment_header['channels']['list'].split ' '
  end
  public
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