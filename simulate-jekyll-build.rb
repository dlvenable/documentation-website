#!/usr/bin/env ruby

require 'json'

# Simulate Jekyll build process to show what the grok documentation would look like
class JekyllBuildSimulator
  def initialize
    @data = load_data_files
  end

  def simulate_grok_page
    puts "🏗️  Simulating Jekyll build for grok processor documentation..."
    puts "=" * 80
    
    # Load the grok JSON data
    grok_data = @data['data-prepper']['processors']['grok']
    
    if grok_data.nil?
      puts "❌ Could not load grok data from _data/data-prepper/processors/grok.json"
      return
    end
    
    puts "# Grok processor"
    puts ""
    puts "The Grok processor uses pattern matching to structure and extract important keys from unstructured data."
    puts ""
    puts "## Configuration"
    puts ""
    puts "The following table describes options you can use with the Grok processor to structure your data and make your data easier to query."
    puts ""
    puts "<!--"
    puts "This table is generated from JSON documentation. Do not edit it directly."
    puts "Source: _data/data-prepper/processors/grok.json"
    puts "-->"
    puts ""
    
    # Generate the configuration table (simulating the Liquid template)
    generate_config_table(grok_data)
    
    puts ""
    puts "## Grok performance metadata"
    puts ""
    puts "When the `performance_metadata` option is set to `true`, the `grok` processor adds the following metadata keys to each event:"
    puts ""
    puts "* `_total_grok_processing_time`: The total amount of time, in milliseconds, that the `grok` processor takes to match the event."
    puts "* `_total_grok_patterns_attempted`: The total number of `grok` pattern match attempts across all `grok` processors that ran on the event."
    puts ""
    
    puts "=" * 80
    puts "✅ Simulation complete! This is what the grok processor documentation would look like after Jekyll build."
  end

  private

  def load_data_files
    data = {
      'data-prepper' => {
        'processors' => {},
        'sources' => {},
        'sinks' => {},
        'buffers' => {}
      }
    }
    
    # Load all JSON files from _data/data-prepper/
    %w[processors sources sinks buffers].each do |plugin_type|
      dir_path = "_data/data-prepper/#{plugin_type}"
      next unless Dir.exist?(dir_path)
      
      Dir.glob(File.join(dir_path, '*.json')).each do |file_path|
        begin
          plugin_name = File.basename(file_path, '.json')
          plugin_data = JSON.parse(File.read(file_path))
          data['data-prepper'][plugin_type][plugin_name] = plugin_data
        rescue JSON::ParserError => e
          puts "⚠️  Warning: Could not parse #{file_path}: #{e.message}"
        end
      end
    end
    
    data
  end

  def generate_config_table(plugin_data)
    puts "Option | Required | Type | Description"
    puts ":--- | :--- |:--- | :---"
    
    plugin_data['properties'].each do |prop_name, prop_config|
      required_text = prop_config['required'] ? 'Yes' : 'No'
      
      # Handle type display
      type_display = prop_config['type'].capitalize
      type_display = 'List' if prop_config['type'] == 'array'
      type_display = 'Map' if prop_config['type'] == 'object'
      
      # Build description
      description = prop_config['description'].strip
      if prop_config['default'] != nil
        description += " Default is `#{prop_config['default']}`."
      end
      if prop_config['examples'] && !prop_config['examples'].empty?
        description += " #{prop_config['examples'][0]['description']}"
      end
      
      puts "`#{prop_name}` | #{required_text} | #{type_display} | #{description}"
    end
    
    # Generate nested property tables
    plugin_data['properties'].each do |prop_name, prop_config|
      if prop_config['properties'] && prop_config['properties'].size > 0
        puts ""
        section_name = prop_name.gsub('_', ' ').split.map(&:capitalize).join(' ')
        puts "### #{section_name} options"
        puts ""
        puts "The following table describes the options for the `#{prop_name}` configuration."
        puts ""
        puts "Option | Required | Type | Description"
        puts ":--- | :--- |:--- | :---"
        
        prop_config['properties'].each do |nested_name, nested_config|
          nested_required = nested_config['required'] ? 'Yes' : 'No'
          nested_type = nested_config['type'].capitalize
          nested_type = 'List' if nested_config['type'] == 'array'
          nested_type = 'Map' if nested_config['type'] == 'object'
          
          nested_description = nested_config['description'].strip
          if nested_config['default'] != nil
            nested_description += " Default is `#{nested_config['default']}`."
          end
          
          puts "`#{nested_name}` | #{nested_required} | #{nested_type} | #{nested_description}"
        end
      end
    end
  end
end

# Run the simulation
if __FILE__ == $0
  simulator = JekyllBuildSimulator.new
  simulator.simulate_grok_page
end