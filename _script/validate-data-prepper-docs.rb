#!/usr/bin/env ruby

require 'json'
require 'json-schema'
require 'pathname'

# Validation script for Data Prepper plugin documentation JSON files
class DataPrepperDocValidator
  SCHEMA_PATH = '_data/data-prepper/plugin-documentation-schema.json'
  DOCS_BASE_PATH = '_data/data-prepper'
  PLUGIN_TYPES = %w[processors sources sinks buffers]

  def initialize
    @schema = load_schema
    @errors = []
    @warnings = []
  end

  def validate_all
    puts "Validating Data Prepper plugin documentation files..."
    
    PLUGIN_TYPES.each do |plugin_type|
      validate_plugin_type(plugin_type)
    end

    report_results
    @errors.empty?
  end

  def validate_file(file_path)
    return false unless File.exist?(file_path)
    
    begin
      doc = JSON.parse(File.read(file_path))
      
      # Perform basic structure validation instead of full JSON schema validation
      validate_basic_structure(file_path, doc)
      validate_plugin_type_consistency(file_path, doc)
      validate_html_content(file_path, doc)
      true
    rescue JSON::ParserError => e
      @errors << "#{file_path}: Invalid JSON - #{e.message}"
      false
    rescue => e
      @errors << "#{file_path}: Validation error - #{e.message}"
      false
    end
  end

  private

  def load_schema
    schema_path = File.join(Dir.pwd, SCHEMA_PATH)
    unless File.exist?(schema_path)
      raise "Schema file not found: #{schema_path}"
    end
    
    JSON.parse(File.read(schema_path))
  end

  def validate_plugin_type(plugin_type)
    docs_dir = File.join(DOCS_BASE_PATH, plugin_type)
    return unless Dir.exist?(docs_dir)

    Dir.glob(File.join(docs_dir, '*.json')).each do |file_path|
      validate_file(file_path)
    end
  end

  def validate_basic_structure(file_path, doc)
    # Check required top-level fields
    required_fields = ['name', 'plugin_type', 'properties']
    required_fields.each do |field|
      unless doc.key?(field)
        @errors << "#{file_path}: Missing required field '#{field}'"
      end
    end
    
    # Validate plugin_type enum
    valid_types = ['source', 'processor', 'sink', 'buffer']
    if doc['plugin_type'] && !valid_types.include?(doc['plugin_type'])
      @errors << "#{file_path}: Invalid plugin_type '#{doc['plugin_type']}'. Must be one of: #{valid_types.join(', ')}"
    end
    
    # Validate properties structure
    if doc['properties'] && !doc['properties'].is_a?(Hash)
      @errors << "#{file_path}: 'properties' must be an object"
    end
  end

  def validate_plugin_type_consistency(file_path, doc)
    # Extract plugin type from file path
    path_parts = Pathname.new(file_path).each_filename.to_a
    expected_type = path_parts[-2] # e.g., 'processors' from '_data/data-prepper/processors/grok.json'
    
    # Convert plural to singular for comparison
    expected_type_singular = expected_type.chomp('s') # processors -> processor
    expected_type_singular = 'source' if expected_type == 'sources'
    
    actual_type = doc['plugin_type']
    
    unless actual_type == expected_type_singular
      @errors << "#{file_path}: plugin_type '#{actual_type}' doesn't match directory '#{expected_type}'"
    end
  end

  def validate_html_content(file_path, doc)
    validate_html_in_properties(file_path, doc['properties'], [])
  end

  def validate_html_in_properties(file_path, properties, path)
    return unless properties.is_a?(Hash)

    properties.each do |prop_name, prop_config|
      current_path = path + [prop_name]
      
      if prop_config['description']
        validate_html_string(file_path, prop_config['description'], current_path + ['description'])
      end
      
      # Recursively validate nested properties
      if prop_config['properties']
        validate_html_in_properties(file_path, prop_config['properties'], current_path + ['properties'])
      end
    end
  end

  def validate_html_string(file_path, html_string, path)
    # Basic HTML validation - check for unclosed tags
    tag_stack = []
    html_string.scan(/<\/?([a-zA-Z][a-zA-Z0-9]*)[^>]*>/) do |match|
      tag = match[0].downcase
      
      if html_string.match(/<#{Regexp.escape(tag)}[^>]*\/>/) # Self-closing tag
        next
      elsif html_string.match(/<\/#{Regexp.escape(tag)}>/) # Closing tag
        if tag_stack.last == tag
          tag_stack.pop
        else
          @warnings << "#{file_path} at #{path.join('.')}: Mismatched HTML tag '#{tag}'"
        end
      else # Opening tag
        tag_stack.push(tag)
      end
    end
    
    unless tag_stack.empty?
      @warnings << "#{file_path} at #{path.join('.')}: Unclosed HTML tags: #{tag_stack.join(', ')}"
    end
  end

  def report_results
    if @errors.empty? && @warnings.empty?
      puts "✅ All Data Prepper documentation files are valid!"
    else
      unless @errors.empty?
        puts "\n❌ Validation Errors:"
        @errors.each { |error| puts "  #{error}" }
      end
      
      unless @warnings.empty?
        puts "\n⚠️  Validation Warnings:"
        @warnings.each { |warning| puts "  #{warning}" }
      end
      
      puts "\nSummary: #{@errors.length} errors, #{@warnings.length} warnings"
    end
  end
end

# Run validation if script is executed directly
if __FILE__ == $0
  validator = DataPrepperDocValidator.new
  success = validator.validate_all
  exit(success ? 0 : 1)
end