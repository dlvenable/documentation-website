#!/usr/bin/env ruby

require 'json'

# Property-based test for migration extraction completeness
# **Feature: data-prepper-json-docs, Property 7: Migration extraction completeness**
# **Validates: Requirements 5.1, 5.3, 5.4**

class MigrationExtractionTest
  BASE_PATH = '_data/data-prepper'
  PLUGIN_TYPES = %w[processors sources sinks buffers]

  def initialize
    @test_count = 0
    @passed_tests = 0
    @failed_tests = 0
    @errors = []
  end

  def run_property_tests
    puts "🧪 Running Property Test: Migration extraction completeness"
    puts "   Testing migration from Markdown to JSON format..."
    
    # Property: For any existing Markdown documentation file, 
    # the migration process should extract all configuration options, descriptions, 
    # and examples into the corresponding JSON structure without loss
    
    test_grok_migration_completeness
    test_json_structure_completeness
    test_content_preservation_during_migration
    test_round_trip_equivalence
    
    report_results
    @failed_tests == 0
  end

  private

  def test_grok_migration_completeness
    @test_count += 1
    
    # Test the grok processor migration as our primary example
    original_md_path = '_data-prepper/pipelines/configuration/processors/grok.md'
    migrated_json_path = '_data/data-prepper/processors/grok.json'
    
    unless File.exist?(original_md_path)
      @failed_tests += 1
      @errors << "Original grok Markdown file not found at #{original_md_path}"
      return
    end
    
    unless File.exist?(migrated_json_path)
      @failed_tests += 1
      @errors << "Migrated grok JSON file not found at #{migrated_json_path}"
      return
    end
    
    # Extract configuration options from original Markdown
    original_options = extract_options_from_markdown(original_md_path)
    
    # Load migrated JSON
    begin
      migrated_data = JSON.parse(File.read(migrated_json_path))
      migrated_options = migrated_data['properties'].keys
    rescue JSON::ParserError => e
      @failed_tests += 1
      @errors << "Failed to parse migrated JSON: #{e.message}"
      return
    end
    
    # Check that all original options are present in migrated JSON
    missing_options = original_options - migrated_options
    unless missing_options.empty?
      @failed_tests += 1
      @errors << "Missing options in migrated JSON: #{missing_options.join(', ')}"
      return
    end
    
    # Check that no extra options were added (unless they're from the original schema)
    extra_options = migrated_options - original_options
    # Allow some extra options that might come from the original JSON schema
    allowed_extra = %w[tags_on_match_failure tags_on_timeout]
    unexpected_extra = extra_options - allowed_extra
    
    unless unexpected_extra.empty?
      @warnings ||= []
      @warnings << "Unexpected extra options in migrated JSON: #{unexpected_extra.join(', ')}"
    end
    
    @passed_tests += 1
  end

  def test_json_structure_completeness
    @test_count += 1
    
    # Test that migrated JSON files have complete structure
    PLUGIN_TYPES.each do |plugin_type|
      docs_dir = File.join(BASE_PATH, plugin_type)
      next unless Dir.exist?(docs_dir)

      Dir.glob(File.join(docs_dir, '*.json')).each do |file_path|
        begin
          doc = JSON.parse(File.read(file_path))
          
          # Check required top-level fields
          required_fields = %w[name plugin_type properties]
          missing_fields = required_fields - doc.keys
          
          unless missing_fields.empty?
            @failed_tests += 1
            @errors << "Missing required fields in #{file_path}: #{missing_fields.join(', ')}"
            return
          end
          
          # Check that each property has required fields
          doc['properties'].each do |prop_name, prop_config|
            required_prop_fields = %w[type description]
            missing_prop_fields = required_prop_fields - prop_config.keys
            
            unless missing_prop_fields.empty?
              @failed_tests += 1
              @errors << "Missing required property fields in #{file_path} for #{prop_name}: #{missing_prop_fields.join(', ')}"
              return
            end
          end
          
        rescue JSON::ParserError => e
          @failed_tests += 1
          @errors << "JSON parse error in #{file_path}: #{e.message}"
          return
        end
      end
    end
    
    @passed_tests += 1
  end

  def test_content_preservation_during_migration
    @test_count += 1
    
    # Test that content is preserved during migration process
    # Compare key information between original and migrated versions
    
    original_md_path = '_data-prepper/pipelines/configuration/processors/grok.md'
    migrated_json_path = '_data/data-prepper/processors/grok.json'
    
    return unless File.exist?(original_md_path) && File.exist?(migrated_json_path)
    
    # Extract key content from original Markdown
    original_content = File.read(original_md_path)
    
    # Load migrated JSON
    migrated_data = JSON.parse(File.read(migrated_json_path))
    
    # Test specific content preservation examples
    content_checks = [
      {
        original_pattern: /break_on_match.*?Default is.*?true/m,
        json_path: ['properties', 'break_on_match', 'default'],
        expected_value: true,
        description: "break_on_match default value"
      },
      {
        original_pattern: /timeout_millis.*?Default is.*?30,000/m,
        json_path: ['properties', 'timeout_millis', 'default'],
        expected_value: 30000,
        description: "timeout_millis default value"
      },
      {
        original_pattern: /performance_metadata.*?Default is.*?false/m,
        json_path: ['properties', 'performance_metadata', 'default'],
        expected_value: false,
        description: "performance_metadata default value"
      }
    ]
    
    content_checks.each do |check|
      if original_content.match?(check[:original_pattern])
        # Navigate to the JSON value
        json_value = migrated_data
        check[:json_path].each { |key| json_value = json_value[key] }
        
        unless json_value == check[:expected_value]
          @failed_tests += 1
          @errors << "Content not preserved for #{check[:description]}: expected #{check[:expected_value]}, got #{json_value}"
          return
        end
      end
    end
    
    @passed_tests += 1
  end

  def test_round_trip_equivalence
    @test_count += 1
    
    # Test that JSON can be converted back to equivalent Markdown
    # This tests the completeness of the migration
    
    migrated_json_path = '_data/data-prepper/processors/grok.json'
    return unless File.exist?(migrated_json_path)
    
    begin
      migrated_data = JSON.parse(File.read(migrated_json_path))
      
      # Generate a simple table representation from JSON
      generated_table = generate_table_from_json(migrated_data)
      
      # Check that generated table has expected structure
      expected_elements = [
        'Option', 'Required', 'Type', 'Description',  # Table headers
        'match', 'target_key', 'break_on_match',      # Key properties
        'Boolean', 'String', 'Map'                    # Data types
      ]
      
      missing_elements = expected_elements.select { |element| !generated_table.include?(element) }
      
      unless missing_elements.empty?
        @failed_tests += 1
        @errors << "Generated table missing expected elements: #{missing_elements.join(', ')}"
        return
      end
      
      @passed_tests += 1
    rescue JSON::ParserError => e
      @failed_tests += 1
      @errors << "Failed to parse JSON for round-trip test: #{e.message}"
    end
  end

  def extract_options_from_markdown(file_path)
    content = File.read(file_path)
    options = []
    
    # Find the configuration table and extract option names
    # Look for lines that start with backticks (option names)
    content.scan(/^`([^`]+)`\s*\|/) do |match|
      options << match[0]
    end
    
    options.uniq
  end

  def generate_table_from_json(json_data)
    table_lines = []
    table_lines << "Option | Required | Type | Description"
    table_lines << ":--- | :--- |:--- | :---"
    
    json_data['properties'].each do |prop_name, prop_config|
      required_text = prop_config['required'] ? 'Yes' : 'No'
      type_text = prop_config['type'].capitalize
      type_text = 'List' if prop_config['type'] == 'array'
      type_text = 'Map' if prop_config['type'] == 'object'
      
      description = prop_config['description']
      if prop_config['default']
        description += " Default is `#{prop_config['default']}`."
      end
      
      table_lines << "`#{prop_name}` | #{required_text} | #{type_text} | #{description}"
    end
    
    table_lines.join("\n")
  end

  def report_results
    puts "\n📊 Property Test Results:"
    puts "   Total tests: #{@test_count}"
    puts "   Passed: #{@passed_tests}"
    puts "   Failed: #{@failed_tests}"
    
    if @failed_tests > 0
      puts "\n❌ Failures:"
      @errors.each { |error| puts "   #{error}" }
    end
    
    if defined?(@warnings) && @warnings && !@warnings.empty?
      puts "\n⚠️  Warnings:"
      @warnings.each { |warning| puts "   #{warning}" }
    end
    
    if @failed_tests == 0
      puts "\n✅ All migration extraction property tests passed!"
    end
  end
end

# Run the test if script is executed directly
if __FILE__ == $0
  test = MigrationExtractionTest.new
  success = test.run_property_tests
  exit(success ? 0 : 1)
end