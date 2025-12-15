#!/usr/bin/env ruby

require 'json'
require 'pathname'

# Property-based test for nested structure table generation
# **Feature: data-prepper-json-docs, Property 4: Nested structure table generation**
# **Validates: Requirements 3.2**

class NestedStructureGenerationTest
  BASE_PATH = '_data/data-prepper'
  PLUGIN_TYPES = %w[processors sources sinks buffers]
  VALID_PLUGIN_TYPES_SINGULAR = %w[processor source sink buffer]

  def initialize
    @test_count = 0
    @passed_tests = 0
    @failed_tests = 0
    @errors = []
  end

  def run_property_tests
    puts "🧪 Running Property Test: Nested structure table generation"
    puts "   Testing 100 random nested property configurations..."
    
    # Property: For any JSON documentation with nested properties, 
    # the build process should generate separate tables for each nesting level
    100.times do |iteration|
      test_nested_property_structure(iteration)
    end
    
    test_existing_nested_structures
    test_liquid_template_logic
    
    report_results
    @failed_tests == 0
  end

  private

  def test_nested_property_structure(iteration)
    @test_count += 1
    
    # Generate random plugin with nested properties
    plugin_type = VALID_PLUGIN_TYPES_SINGULAR.sample
    plugin_name = "test_nested_plugin_#{iteration}"
    
    # Create nested structure
    nested_depth = rand(1..3) # 1-3 levels of nesting
    plugin_doc = generate_nested_plugin_doc(plugin_name, plugin_type, nested_depth)
    
    # Validate that nested properties are properly structured
    nested_properties = find_nested_properties(plugin_doc['properties'])
    
    if nested_properties.empty?
      # If we generated nested properties but none were found, that's an error
      if has_nested_properties_in_generation(plugin_doc['properties'])
        @failed_tests += 1
        @errors << "Generated nested properties but validation didn't find them for #{plugin_name}"
        return
      end
    else
      # Validate each nested property has required structure
      nested_properties.each do |prop_path, nested_props|
        unless validate_nested_property_structure(nested_props, prop_path)
          @failed_tests += 1
          @errors << "Invalid nested property structure at #{prop_path} for #{plugin_name}"
          return
        end
      end
    end
    
    @passed_tests += 1
  end

  def test_existing_nested_structures
    # Test actual JSON files that have nested properties
    PLUGIN_TYPES.each do |plugin_type|
      docs_dir = File.join(BASE_PATH, plugin_type)
      next unless Dir.exist?(docs_dir)

      Dir.glob(File.join(docs_dir, '*.json')).each do |file_path|
        @test_count += 1
        
        begin
          doc = JSON.parse(File.read(file_path))
          nested_properties = find_nested_properties(doc['properties'])
          
          # Each nested property should have valid structure
          nested_properties.each do |prop_path, nested_props|
            unless validate_nested_property_structure(nested_props, prop_path)
              @failed_tests += 1
              @errors << "Invalid nested structure in #{file_path} at #{prop_path}"
              return
            end
          end
          
          @passed_tests += 1
        rescue JSON::ParserError => e
          @failed_tests += 1
          @errors << "JSON parse error in #{file_path}: #{e.message}"
        end
      end
    end
  end

  def test_liquid_template_logic
    @test_count += 1
    
    # Test that the Liquid template file exists and has nested property handling
    template_path = '_includes/data-prepper-config-table.html'
    
    unless File.exist?(template_path)
      @failed_tests += 1
      @errors << "Liquid template not found at #{template_path}"
      return
    end
    
    template_content = File.read(template_path)
    
    # Check for nested property handling patterns
    required_patterns = [
      'for property in plugin_data.properties',  # Main property iteration
      'if prop_config.properties',               # Nested property detection
      'for nested_property in prop_config.properties', # Nested iteration
      'nested_prop_name',                        # Nested property naming
      'nested_prop_config'                       # Nested property config
    ]
    
    missing_patterns = required_patterns.reject { |pattern| template_content.include?(pattern) }
    
    if missing_patterns.empty?
      @passed_tests += 1
    else
      @failed_tests += 1
      @errors << "Liquid template missing nested property handling patterns: #{missing_patterns.join(', ')}"
    end
  end

  def generate_nested_plugin_doc(name, plugin_type, depth)
    doc = {
      "name" => name,
      "plugin_type" => plugin_type,
      "properties" => {}
    }
    
    # Add some regular properties
    (1..rand(2..5)).each do |i|
      doc["properties"]["simple_prop_#{i}"] = {
        "type" => %w[string boolean integer].sample,
        "description" => "Simple property #{i}",
        "required" => [true, false].sample
      }
    end
    
    # Add nested properties based on depth
    if depth > 0
      nested_prop_name = "nested_config_#{rand(1000)}"
      doc["properties"][nested_prop_name] = generate_nested_property(depth - 1)
    end
    
    doc
  end

  def generate_nested_property(remaining_depth)
    prop = {
      "type" => "object",
      "description" => "Nested configuration object",
      "required" => [true, false].sample,
      "properties" => {}
    }
    
    # Add sub-properties
    (1..rand(2..4)).each do |i|
      sub_prop_name = "sub_prop_#{i}_#{rand(1000)}"
      
      if remaining_depth > 0 && rand < 0.3 # 30% chance of deeper nesting
        prop["properties"][sub_prop_name] = generate_nested_property(remaining_depth - 1)
      else
        prop["properties"][sub_prop_name] = {
          "type" => %w[string boolean integer array].sample,
          "description" => "Sub-property #{i}",
          "required" => [true, false].sample
        }
      end
    end
    
    prop
  end

  def find_nested_properties(properties, path = [])
    nested = {}
    return nested unless properties.is_a?(Hash)
    
    properties.each do |prop_name, prop_config|
      current_path = path + [prop_name]
      
      if prop_config.is_a?(Hash) && prop_config['properties']
        nested[current_path.join('.')] = prop_config['properties']
        
        # Recursively find deeper nested properties
        deeper_nested = find_nested_properties(prop_config['properties'], current_path + ['properties'])
        nested.merge!(deeper_nested)
      end
    end
    
    nested
  end

  def has_nested_properties_in_generation(properties)
    return false unless properties.is_a?(Hash)
    
    properties.any? do |_, prop_config|
      prop_config.is_a?(Hash) && prop_config['properties']
    end
  end

  def validate_nested_property_structure(nested_props, path)
    return false unless nested_props.is_a?(Hash)
    
    # Each nested property should have required fields
    nested_props.all? do |prop_name, prop_config|
      prop_config.is_a?(Hash) &&
        prop_config['type'] &&
        prop_config['description']
    end
  end

  def report_results
    puts "\n📊 Property Test Results:"
    puts "   Total tests: #{@test_count}"
    puts "   Passed: #{@passed_tests}"
    puts "   Failed: #{@failed_tests}"
    
    if @failed_tests > 0
      puts "\n❌ Failures:"
      @errors.each { |error| puts "   #{error}" }
    else
      puts "\n✅ All nested structure property tests passed!"
    end
  end
end

# Run the test if script is executed directly
if __FILE__ == $0
  test = NestedStructureGenerationTest.new
  success = test.run_property_tests
  exit(success ? 0 : 1)
end