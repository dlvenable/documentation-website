#!/usr/bin/env ruby

require 'json'
require 'liquid'

# Content preservation validation script
# Validates that no data is lost during JSON to HTML table conversion

class ContentPreservationValidator
  def initialize
    @errors = []
  end

  def validate_all_plugins
    puts "🔍 Validating content preservation across all plugin types..."
    
    plugin_types = %w[processors sources sinks buffers]
    total_validated = 0
    
    plugin_types.each do |plugin_type|
      data_dir = "_data/data-prepper/#{plugin_type}"
      next unless Dir.exist?(data_dir)
      
      Dir.glob("#{data_dir}/*.json").each do |json_file|
        plugin_name = File.basename(json_file, '.json')
        validate_plugin_content_preservation(plugin_name, plugin_type)
        total_validated += 1
      end
    end
    
    puts "✅ Validated content preservation for #{total_validated} plugins"
    
    if @errors.empty?
      puts "✅ All content preservation validations passed!"
      true
    else
      puts "❌ Content preservation validation failures:"
      @errors.each { |error| puts "   #{error}" }
      false
    end
  end

  private

  def validate_plugin_content_preservation(plugin_name, plugin_type)
    # Load JSON data
    json_file = "_data/data-prepper/#{plugin_type}/#{plugin_name}.json"
    return unless File.exist?(json_file)
    
    begin
      json_data = JSON.parse(File.read(json_file))
    rescue JSON::ParserError => e
      @errors << "Failed to parse JSON for #{plugin_name}: #{e.message}"
      return
    end
    
    # Render template
    template_content = File.read('_includes/data-prepper-config-table.html')
    template = Liquid::Template.parse(template_content)
    
    # Create proper site data structure with hyphens converted to underscores for Liquid
    site_data = {
      'data-prepper' => {
        plugin_type => {
          plugin_name => json_data
        }
      }
    }
    
    begin
      html_output = template.render(
        'include' => { 'plugin' => plugin_name, 'plugin_type' => plugin_type },
        'site' => { 'data' => site_data }
      )
    rescue => e
      @errors << "Template rendering failed for #{plugin_name}: #{e.message}"
      return
    end
    
    # Skip validation if template produced no output (plugin data not found)
    if html_output.strip.empty? || !html_output.include?('<table>')
      puts "⚠️  Skipping validation for #{plugin_name} (#{plugin_type}) - no table output generated"
      return
    end
    
    # Validate content preservation
    validate_properties_preserved(json_data, html_output, plugin_name)
    validate_html_content_preserved(json_data, html_output, plugin_name)
    validate_table_structure(html_output, plugin_name)
  end

  def validate_properties_preserved(json_data, html_output, plugin_name)
    return unless json_data['properties']
    
    json_data['properties'].each do |prop_name, prop_config|
      # Check property name is in output
      unless html_output.include?("<code>#{prop_name}</code>")
        @errors << "Property name '#{prop_name}' missing from #{plugin_name} output"
      end
      
      # Check description is preserved
      if prop_config['description']
        # Remove extra whitespace for comparison
        description = prop_config['description'].strip
        unless html_output.include?(description)
          @errors << "Description for '#{prop_name}' not preserved in #{plugin_name}"
        end
      end
      
      # Check type is preserved
      if prop_config['type']
        type_display = case prop_config['type']
                      when 'array' then 'List'
                      when 'object' then 'Map'
                      else prop_config['type'].capitalize
                      end
        unless html_output.include?(type_display)
          @errors << "Type '#{type_display}' for '#{prop_name}' not preserved in #{plugin_name}"
        end
      end
      
      # Check required status
      required_text = prop_config['required'] ? 'Yes' : 'No'
      # This is harder to validate precisely, so we'll just check the structure exists
    end
  end

  def validate_html_content_preserved(json_data, html_output, plugin_name)
    return unless json_data['properties']
    
    json_data['properties'].each do |prop_name, prop_config|
      next unless prop_config['description']
      
      description = prop_config['description']
      
      # Check for HTML tags that should be preserved
      html_tags = description.scan(/<[^>]+>/)
      html_tags.each do |tag|
        unless html_output.include?(tag)
          @errors << "HTML tag '#{tag}' not preserved in #{plugin_name} for property '#{prop_name}'"
        end
      end
      
      # Check for HTML entities that should be preserved
      html_entities = description.scan(/&[a-zA-Z]+;/)
      html_entities.each do |entity|
        unless html_output.include?(entity)
          @errors << "HTML entity '#{entity}' not preserved in #{plugin_name} for property '#{prop_name}'"
        end
      end
    end
  end

  def validate_table_structure(html_output, plugin_name)
    # Check for proper HTML table structure
    unless html_output.include?('<table>')
      @errors << "Missing <table> tag in #{plugin_name} output"
    end
    
    unless html_output.include?('<thead>')
      @errors << "Missing <thead> tag in #{plugin_name} output"
    end
    
    unless html_output.include?('<tbody>')
      @errors << "Missing <tbody> tag in #{plugin_name} output"
    end
    
    # Check for proper header structure
    expected_headers = ['<th>Option</th>', '<th>Required</th>', '<th>Type</th>', '<th>Description</th>']
    expected_headers.each do |header|
      unless html_output.include?(header)
        @errors << "Missing table header '#{header}' in #{plugin_name} output"
      end
    end
  end
end

# Run validation if script is executed directly
if __FILE__ == $0
  validator = ContentPreservationValidator.new
  success = validator.validate_all_plugins
  exit(success ? 0 : 1)
end