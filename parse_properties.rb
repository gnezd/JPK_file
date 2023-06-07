fin = './mock_datafile/shared-data/header.properties'

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

      tags = flag.split('.').map do |node|
        case node
        when /^\d+$/
          node = node.to_i 
        when /^-?\d+\.\d*E?-?\d*$/
          node = node.to_f
        end
        node
      end
      
      sprout = config
      while node = tags.shift
        sprout[node] = {} unless sprout[node]
        sprout = sprout[node]
        if tags.size == 1
          sprout[tags[0]] = value
          break
        end
      end
      sprout = value
    end
  end
  config
end