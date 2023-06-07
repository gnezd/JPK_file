# qi-data(quantative image) reading class
class JPK_QiData
  attr_accessor :name, :properties
  def initialize(path, name, options = {})
    # Check if file exists
    raise "#{path} cannot be found" unless File.exist? path

    # Create scratch space and unzip
    timestamp = Time.now.strftime "%d%b%Y-%H%M%S"
    @scratch_path = options[:scratch_path] ? options[:scratch_path] : "#{ENV['HOME']}/jpkscr/#{timestamp}"
    FileUtils.mkdir_p @scratch_path

    # Actually unzip it
    t0 = Time.now
    puts "Starting to unpack qi-data file #{path}"
    shell_result = `unzip '#{path}' -d '#{@scratch_path}' 2>&1`
    raise "Error during unzipping: #{shell_result}" if shell_result =~ /cannot|not\sfound/
    t_unzip = Time.now - t0
    puts "Unpacking to #{@scratch_path} completed in #{t_unzip} s."

    # Read .properties

  end
end