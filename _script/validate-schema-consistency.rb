#!/usr/bin/env ruby

require 'json'
require 'pathname'
require 'set'

# Schema consistency validation for Data Prepper plugin documentation
# Compares JSON documentation structure with sample JSON schemas to ensure alignment
class SchemaConsistencyValidator
  DOCS_BASE_PATH = '_data/data-prepper'
  PLUGIN_TYPES = %w[processors sources sinks buffers]
  
  # Sample JSON schemas that would come from data-prepper project
  # These represent the structure that data-prepper generates
  SAMPLE_SCHEMAS_PATH = '_data/data-prepper/sample-schemas'

  def initialize
    @errors = []
    @warnings = []
    @reports = []
  end

  def validate_all
    puts "Validating schema consistency between documentation and sample schemas..."
    
    PLUGIN_TYPES.each do |plugin_type|
      validate_plugin_type_consistency(plugin_type)
    end

    generate_consistency_report
    report_results
    @errors.empty?
  end

  def validate_plugin_consistency(doc_file_path, schema_file_path)
    return false unless File.exist?(doc_file_path) && File.exist?(schema_file_path)
    
    begin
      doc = JSON.parse(File.read(doc_file_path))
      schema = JSON.parse(File.read(schema_file_path))
      
      plugin_name = doc['name']
      
      # Validate that documentation covers all schema properties
      validate_property_coverage(doc_file_path, doc, schema, plugin_name)
      
      # Validate that property types match
      validate_property_types(doc_file_path, doc, schema, plugin_name)
      
      # Validate required field consistency
      validate_required_fields(doc_file_path, doc, schema, plugin_name)
      
      true
    rescue JSON::ParserError => e
      @errors << "#{doc_file_path}: Invalid JSON - #{e.message}"
      false
    rescue => e
      @errors << "#{doc_file_path}: Schema consistency validation error - #{e.message}"
      false
    end
  end

  private

  def validate_plugin_type_consistency(plugin_type)
    docs_dir = File.join(DOCS_BASE_PATH, plugin_type)
    schemas_dir = File.join(SAMPLE_SCHEMAS_PATH, plugin_type)
    
    return unless Dir.exist?(docs_dir)

    Dir.glob(File.join(docs_dir, '*.json')).each do |doc_file|
      plugin_name = File.basename(doc_file, '.json')
      schema_file = File.join(schemas_dir, "#{plugin_name}.json")
      
      if File.exist?(schema_file)
        validate_plugin_consistency(doc_file, schema_file)
      else
        @warnings << "No corresponding schema found for documentation: #{doc_file}"
        create_sample_schema_if_missing(schema_file, doc_file)
      end
    end
  end

  def validate_property_coverage(doc_file_path, doc, schema, plugin_name)
    doc_properties = extract_property_names(doc['properties'] || {})
    schema_properties = extract_property_names(schema['properties'] || {})
    
    # Check for properties in schema but missing from documentation
    missing_in_doc = schema_properties - doc_properties
    unless missing_in_doc.empty?
      @errors << "#{doc_file_path}: Missing documentation for schema properties: #{missing_in_doc.to_a.join(', ')}"
    end
    
    # Check for properties in documentation but not in schema
    extra_in_doc = doc_properties - schema_properties
    unless extra_in_doc.empty?
      @warnings << "#{doc_file_path}: Documentation contains properties not in schema: #{extra_in_doc.to_a.join(', ')}"
    end
    
    @reports << {
      plugin: plugin_name,
      file: doc_file_path,
      schema_properties: schema_properties.size,
      documented_properties: doc_properties.size,
      missing_in_doc: missing_in_doc.size,
      extra_in_doc: extra_in_doc.size
    }
  end

  def validate_property_types(doc_file_path, doc, schema, plugin_name)
    validate_types_recursive(doc_file_path, doc['properties'] || {}, schema['properties'] || {}, [])
  end

  def validate_types_recursive(doc_file_path, doc_props, schema_props, path)
    return unless doc_props.is_a?(Hash) && schema_props.is_a?(Hash)

    doc_props.each do |prop_name, doc_config|
      schema_config = schema_props[prop_name]
      current_path = path + [prop_name]
      
      next unless schema_config
      
      # Validate type consistency
      doc_type = doc_config['type']
      schema_type = schema_config['type']
      
      if doc_type && schema_type && doc_type != schema_type
        @errors << "#{doc_file_path} at #{current_path.join('.')}: Type mismatch - doc: '#{doc_type}', schema: '#{schema_type}'"
      end
      
      # Recursively validate nested properties
      if doc_config['properties'] && schema_config['properties']
        validate_types_recursive(doc_file_path, doc_config['properties'], schema_config['properties'], current_path + ['properties'])
      end
    end
  end

  def validate_required_fields(doc_file_path, doc, schema, plugin_name)
    validate_required_recursive(doc_file_path, doc['properties'] || {}, schema['properties'] || {}, [])
  end

  def validate_required_recursive(doc_file_path, doc_props, schema_props, path)
    return unless doc_props.is_a?(Hash) && schema_props.is_a?(Hash)

    doc_props.each do |prop_name, doc_config|
      schema_config = schema_props[prop_name]
      current_path = path + [prop_name]
      
      next unless schema_config
      
      # Validate required field consistency
      doc_required = doc_config['required']
      schema_required = schema_config['required']
      
      if !doc_required.nil? && !schema_required.nil? && doc_required != schema_required
        @warnings << "#{doc_file_path} at #{current_path.join('.')}: Required field mismatch - doc: #{doc_required}, schema: #{schema_required}"
      end
      
      # Recursively validate nested properties
      if doc_config['properties'] && schema_config['properties']
        validate_required_recursive(doc_file_path, doc_config['properties'], schema_config['properties'], current_path + ['properties'])
      end
    end
  end

  def extract_property_names(properties, prefix = '')
    names = Set.new
    return names unless properties.is_a?(Hash)

    properties.each do |prop_name, prop_config|
      full_name = prefix.empty? ? prop_name : "#{prefix}.#{prop_name}"
      names.add(full_name)
      
      # Recursively extract nested property names
      if prop_config.is_a?(Hash) && prop_config['properties']
        nested_names = extract_property_names(prop_config['properties'], full_name)
        names.merge(nested_names)
      end
    end
    
    names
  end

  def create_sample_schema_if_missing(schema_file_path, doc_file_path)
    # Create sample schema directory if it doesn't exist
    schema_dir = File.dirname(schema_file_path)
    FileUtils.mkdir_p(schema_dir) unless Dir.exist?(schema_dir)
    
    # Generate a sample schema based on the documentation structure
    begin
      doc = JSON.parse(File.read(doc_file_path))
      sample_schema = generate_sample_schema_from_doc(doc)
      
      File.write(schema_file_path, JSON.pretty_generate(sample_schema))
      @warnings << "Created sample schema: #{schema_file_path} (based on documentation structure)"
    rescue => e
      @warnings << "Could not create sample schema for #{schema_file_path}: #{e.message}"
    end
  end

  def generate_sample_schema_from_doc(doc)
    {
      "name" => doc['name'],
      "plugin_type" => doc['plugin_type'],
      "properties" => convert_doc_properties_to_schema(doc['properties'] || {})
    }
  end

  def convert_doc_properties_to_schema(doc_properties)
    schema_properties = {}
    
    doc_properties.each do |prop_name, prop_config|
      schema_prop = {
        "type" => prop_config['type']
      }
      
      schema_prop["required"] = prop_config['required'] if prop_config.key?('required')
      schema_prop["default"] = prop_config['default'] if prop_config.key?('default')
      
      if prop_config['properties']
        schema_prop["properties"] = convert_doc_properties_to_schema(prop_config['properties'])
      end
      
      if prop_config['items']
        schema_prop["items"] = prop_config['items']
      end
      
      schema_properties[prop_name] = schema_prop
    end
    
    schema_properties
  end

  def generate_consistency_report
    return if @reports.empty?
    
    puts "\n📊 Schema Consistency Report:"
    puts "=" * 60
    
    @reports.each do |report|
      puts "Plugin: #{report[:plugin]}"
      puts "  Schema properties: #{report[:schema_properties]}"
      puts "  Documented properties: #{report[:documented_properties]}"
      puts "  Missing in documentation: #{report[:missing_in_doc]}"
      puts "  Extra in documentation: #{report[:extra_in_doc]}"
      
      coverage_percentage = if report[:schema_properties] > 0
        ((report[:schema_properties] - report[:missing_in_doc]).to_f / report[:schema_properties] * 100).round(1)
      else
        100.0
      end
      
      puts "  Coverage: #{coverage_percentage}%"
      puts
    end
  end

  def report_results
    if @errors.empty? && @warnings.empty?
      puts "✅ All schema consistency checks passed!"
    else
      unless @errors.empty?
        puts "\n❌ Schema Consistency Errors:"
        @errors.each { |error| puts "  #{error}" }
      end
      
      unless @warnings.empty?
        puts "\n⚠️  Schema Consistency Warnings:"
        @warnings.each { |warning| puts "  #{warning}" }
      end
      
      puts "\nSummary: #{@errors.length} errors, #{@warnings.length} warnings"
    end
  end
end

# Run validation if script is executed directly
if __FILE__ == $0
  require 'fileutils'
  
  validator = SchemaConsistencyValidator.new
  success = validator.validate_all
  exit(success ? 0 : 1)
end