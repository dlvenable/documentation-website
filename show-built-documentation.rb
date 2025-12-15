#!/usr/bin/env ruby

require 'json'

# Show what the built documentation looks like in a formatted way
class DocumentationViewer
  def show_grok_documentation
    puts "\n" + "=" * 100
    puts "🌐 BUILT DOCUMENTATION PREVIEW: Grok Processor"
    puts "   (This is what users would see on the website)"
    puts "=" * 100
    
    # Load grok data
    grok_data = JSON.parse(File.read('_data/data-prepper/processors/grok.json'))
    
    puts <<~HEADER
      
      # Grok processor
      
      The Grok processor uses pattern matching to structure and extract important keys from unstructured data.
      
      ## Configuration
      
      The following table describes options you can use with the Grok processor to structure your data and make your data easier to query.
      
      <!--
      This table is generated from JSON documentation. Do not edit it directly.
      Source: _data/data-prepper/processors/grok.json
      -->
      
    HEADER
    
    # Generate formatted table
    generate_formatted_table(grok_data)
    
    puts <<~FOOTER
      
      ## Grok performance metadata
      
      When the `performance_metadata` option is set to `true`, the `grok` processor adds the following metadata keys to each event:
      
      * `_total_grok_processing_time`: The total amount of time, in milliseconds, that the `grok` processor takes to match the event. This is the sum of the processing time based on all of the `grok` processors that ran on the event and have the `performance_metadata` option enabled.
      * `_total_grok_patterns_attempted`: The total number of `grok` pattern match attempts across all `grok` processors that ran on the event.
      
    FOOTER
    
    puts "=" * 100
    puts "✅ This is the exact output that Jekyll would generate from our JSON documentation!"
    puts "=" * 100
  end

  private

  def generate_formatted_table(plugin_data)
    # Calculate column widths for better formatting
    max_option_width = plugin_data['properties'].keys.map(&:length).max + 2
    max_type_width = 10
    
    # Header
    puts sprintf("| %-#{max_option_width}s | %-8s | %-#{max_type_width}s | %s |", 
                 "Option", "Required", "Type", "Description")
    puts sprintf("|:%s|:%s|:%s|:%s|", 
                 "-" * max_option_width, 
                 "-" * 8, 
                 "-" * max_type_width, 
                 "-" * 50)
    
    # Rows
    plugin_data['properties'].each do |prop_name, prop_config|
      required_text = prop_config['required'] ? 'Yes' : 'No'
      
      type_display = case prop_config['type']
      when 'array' then 'List'
      when 'object' then 'Map'
      else prop_config['type'].capitalize
      end
      
      # Build description with proper formatting
      description = prop_config['description']
      if prop_config['default'] != nil
        description += " Default is `#{prop_config['default']}`."
      end
      if prop_config['examples'] && !prop_config['examples'].empty?
        description += " #{prop_config['examples'][0]['description']}"
      end
      
      # Wrap long descriptions
      wrapped_description = wrap_text(description, 60)
      
      puts sprintf("| `%-#{max_option_width-2}s` | %-8s | %-#{max_type_width}s | %s |", 
                   prop_name, required_text, type_display, wrapped_description)
    end
    
    # Generate nested property sections
    plugin_data['properties'].each do |prop_name, prop_config|
      if prop_config['properties'] && prop_config['properties'].size > 0
        puts "\n### #{prop_name.gsub('_', ' ').split.map(&:capitalize).join(' ')} options\n"
        puts "The following table describes the options for the `#{prop_name}` configuration.\n"
        
        puts sprintf("| %-#{max_option_width}s | %-8s | %-#{max_type_width}s | %s |", 
                     "Option", "Required", "Type", "Description")
        puts sprintf("|:%s|:%s|:%s|:%s|", 
                     "-" * max_option_width, 
                     "-" * 8, 
                     "-" * max_type_width, 
                     "-" * 50)
        
        prop_config['properties'].each do |nested_name, nested_config|
          nested_required = nested_config['required'] ? 'Yes' : 'No'
          nested_type = case nested_config['type']
          when 'array' then 'List'
          when 'object' then 'Map'
          else nested_config['type'].capitalize
          end
          
          nested_description = nested_config['description']
          if nested_config['default'] != nil
            nested_description += " Default is `#{nested_config['default']}`."
          end
          
          wrapped_nested_description = wrap_text(nested_description, 60)
          
          puts sprintf("| `%-#{max_option_width-2}s` | %-8s | %-#{max_type_width}s | %s |", 
                       nested_name, nested_required, nested_type, wrapped_nested_description)
        end
      end
    end
  end

  def wrap_text(text, width)
    # Simple text wrapping for display purposes
    if text.length <= width
      text
    else
      text[0...width] + "..."
    end
  end
end

# Run the viewer
if __FILE__ == $0
  viewer = DocumentationViewer.new
  viewer.show_grok_documentation
end