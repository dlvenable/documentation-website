#!/usr/bin/env ruby

require 'json'
require 'pathname'

# Simple validation script for Data Prepper plugin documentation JSON files
class SimpleDataPrepperDocValidator
  DOCS_BASE_PATH = '_data/data-prepper'
  PLUGIN_TYPES = %w[processors sources sinks buffers]
  REQUIRED_FIELDS = %w[name plugin_type properties]
  VALID_TYPES = %w[string boolean integer number array object]
  VALID_PLUGIN_TYPES = %w[source processor sink buffer]

  def initialize
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
      
      validate_required_fields(file_path, doc)
      validate_plugin_type_consistency(file_path, doc)
      validate_properties_structure(file_path, doc['properties']) if doc['properties']
      
      @errors.empty?
    rescue JSON::ParserError => e
      @errors << "#{file_path}: Invalid JSON - #{e.message}"
      false
    rescue => e
      @errors << "#{file_path}: Validation error - #{e.message}"
      false
    end
  end

  private

  def validate_plugin_type(plugin_type)
    docs_dir = File.join(DOCS_BASE_PATH, plugin_type)
    return unless Dir.exist?(docs_dir)

    Dir.glob(File.join(docs_dir, '*.json')).each do |file_path|
      validate_file(file_path)
    end
  end

  def validate_required_fields(file_path, doc)
    REQUIRED_FIELDS.each do |field|
      unless doc.key?(field)
        @errors << "#{file_path}: Missing required field '#{field}'"
      end
    end
    
    # Validate plugin_type value
    if doc['plugin_type'] && !VALID_PLUGIN_TYPES.include?(doc['plugin_type'])
      @errors << "#{file_path}: Invalid plugin_type '#{doc['plugin_type']}'. Must be one of: #{VALID_PLUGIN_TYPES.join(', ')}"
    end
  end

  def validate_plugin_type_consistency(file_path, doc)
    # Extract plugin type from file path
    path_parts = Pathname.new(file_path).each_filename.to_a
    expected_type = path_parts[-2] # e.g., 'processors' from '_data/data-prepper/processors/grok.json'
    
    # Convert plural to singular for comparison
    expected_type_singular = case expected_type
    when 'processors' then 'processor'
    when 'sources' then 'source'
    when 'sinks' then 'sink'
    when 'buffers' then 'buffer'
    else expected_type
    end
    
    actual_type = doc['plugin_type']
    
    unless actual_type == expected_type_singular
      @errors << "#{file_path}: plugin_type '#{actual_type}' doesn't match directory '#{expected_type}'"
    end
  end

  def validate_properties_structure(file_path, properties, path = [])
    return unless properties.is_a?(Hash)

    properties.each do |prop_name, prop_config|
      current_path = path + [prop_name]
      
      unless prop_config.is_a?(Hash)
        @errors << "#{file_path} at #{current_path.join('.')}: Property must be an object"
        next
      end
      
      # Validate required property fields
      unless prop_config['type']
        @errors << "#{file_path} at #{current_path.join('.')}: Missing required 'type' field"
      end
      
      unless prop_config['description']
        @errors << "#{file_path} at #{current_path.join('.')}: Missing required 'description' field"
      end
      
      # Validate type value
      if prop_config['type'] && !VALID_TYPES.include?(prop_config['type'])
        @errors << "#{file_path} at #{current_path.join('.')}: Invalid type '#{prop_config['type']}'. Must be one of: #{VALID_TYPES.join(', ')}"
      end
      
      # Validate nested properties
      if prop_config['properties']
        if prop_config['type'] != 'object'
          @warnings << "#{file_path} at #{current_path.join('.')}: 'properties' field should only be used with type 'object'"
        end
        validate_properties_structure(file_path, prop_config['properties'], current_path + ['properties'])
      end
      
      # Validate array items
      if prop_config['items'] && prop_config['type'] != 'array'
        @warnings << "#{file_path} at #{current_path.join('.')}: 'items' field should only be used with type 'array'"
      end
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
  validator = SimpleDataPrepperDocValidator.new
  success = validator.validate_all
  exit(success ? 0 : 1)
end