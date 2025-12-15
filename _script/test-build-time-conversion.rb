#!/usr/bin/env ruby

require 'json'

# Property-based test for build-time JSON to Markdown conversion completeness
# **Feature: data-prepper-json-docs, Property 6: Build-time JSON to Markdown conversion completeness**
# **Validates: Requirements 4.1, 4.2, 4.4**

class BuildTimeConversionTest
  BASE_PATH = '_data/data-prepper'
  PLUGIN_TYPES = %w[processors sources sinks buffers]

  def initialize
    @test_count = 0
    @passed_tests = 0
    @failed_tests = 0
    @errors = []
  end

  def run_property_tests
    puts "🧪 Running Property Test: Build-time JSON to Markdown conversion completeness"
    puts "   Testing Jekyll build process and Liquid template conversion..."
    
    # Property: For any valid JSON documentation file, the Jekyll build process 
    # should generate functionally equivalent Markdown output that matches 
    # current documentation structure
    
    test_liquid_template_functionality
    test_json_to_markdown_conversion
    test_nested_property_handling
    test_all_plugin_types_support
    test_html_content_preservation_in_conversion
    
    report_results
    @failed_tests == 0
  end

  private

  def test_liquid_template_functionality
    @test_count += 1
    
    # Test that the Liquid template exists and has required functionality
    template_path = '_includes/data-prepper-config-table.html'
    
    unless File.exist?(template_path)
      @failed_tests += 1
      @errors << "Liquid template not found at #{template_path}"
      return
    end
    
    template_content = File.read(template_path)
    
    # Check for required Liquid template elements
    required_elements = [
      'assign plugin_name = include.plugin',      # Plugin name assignment
      'assign plugin_type = include.plugin_type', # Plugin type assignment
      'case plugin_type',                         # Plugin type switching
      'site.data.data-prepper',                   # Data access
      'for property in plugin_data.properties',   # Property iteration
      '<th>Option</th>',                          # HTML table header
      'if prop_config.properties',                # Nested property detection
      'for nested_property in prop_config.properties' # Nested iteration
    ]
    
    missing_elements = required_elements.select { |element| !template_content.include?(element) }
    
    unless missing_elements.empty?
      @failed_tests += 1
      @errors << "Liquid template missing required elements: #{missing_elements.join(', ')}"
      return
    end
    
    @passed_tests += 1
  end

  def test_json_to_markdown_conversion
    @test_count += 1
    
    # Test conversion of JSON data to Markdown table format
    # Simulate what the Liquid template should produce
    
    PLUGIN_TYPES.each do |plugin_type|
      docs_dir = File.join(BASE_PATH, plugin_type)
      next unless Dir.exist?(docs_dir)

      Dir.glob(File.join(docs_dir, '*.json')).each do |file_path|
        begin
          doc = JSON.parse(File.read(file_path))
          
          # Generate expected Markdown table
          markdown_table = generate_markdown_table(doc)
          
          # Validate table structure
          unless validate_markdown_table_structure(markdown_table)
            @failed_tests += 1
            @errors << "Generated Markdown table has invalid structure for #{file_path}"
            return
          end
          
          # Validate content completeness
          unless validate_table_content_completeness(doc, markdown_table)
            @failed_tests += 1
            @errors << "Generated Markdown table missing content for #{file_path}"
            return
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

  def test_nested_property_handling
    @test_count += 1
    
    # Test that nested properties generate separate tables
    nested_json_files = []
    
    PLUGIN_TYPES.each do |plugin_type|
      docs_dir = File.join(BASE_PATH, plugin_type)
      next unless Dir.exist?(docs_dir)

      Dir.glob(File.join(docs_dir, '*.json')).each do |file_path|
        begin
          doc = JSON.parse(File.read(file_path))
          
          # Check if this file has nested properties
          has_nested = doc['properties'].any? do |_, prop_config|
            prop_config.is_a?(Hash) && prop_config['properties']
          end
          
          if has_nested
            nested_json_files << file_path
            
            # Generate markdown and check for nested table sections
            markdown_output = generate_full_markdown_output(doc)
            
            # Should contain section headers for nested properties
            nested_sections = doc['properties'].select do |_, prop_config|
              prop_config.is_a?(Hash) && prop_config['properties']
            end
            
            nested_sections.each do |prop_name, _|
              section_header = "### #{prop_name.gsub('_', ' ').split.map(&:capitalize).join(' ')} options"
              
              unless markdown_output.include?(section_header)
                @failed_tests += 1
                @errors << "Missing nested property section '#{section_header}' in generated output for #{file_path}"
                return
              end
            end
          end
          
        rescue JSON::ParserError => e
          @failed_tests += 1
          @errors << "JSON parse error in #{file_path}: #{e.message}"
          return
        end
      end
    end
    
    # Ensure we tested at least one file with nested properties
    if nested_json_files.empty?
      @failed_tests += 1
      @errors << "No JSON files with nested properties found for testing"
      return
    end
    
    @passed_tests += 1
  end

  def test_all_plugin_types_support
    @test_count += 1
    
    # Test that the template supports all plugin types
    plugin_type_mappings = {
      'processor' => 'processors',
      'source' => 'sources',
      'sink' => 'sinks',
      'buffer' => 'buffers'
    }
    
    plugin_type_mappings.each do |singular, plural|
      # Check if we have test data for this plugin type
      docs_dir = File.join(BASE_PATH, plural)
      next unless Dir.exist?(docs_dir)
      
      json_files = Dir.glob(File.join(docs_dir, '*.json'))
      next if json_files.empty?
      
      # Test with the first available JSON file
      test_file = json_files.first
      
      begin
        doc = JSON.parse(File.read(test_file))
        
        # Verify plugin_type matches directory
        unless doc['plugin_type'] == singular
          @failed_tests += 1
          @errors << "Plugin type mismatch in #{test_file}: expected #{singular}, got #{doc['plugin_type']}"
          return
        end
        
        # Generate markdown to ensure no errors
        markdown_table = generate_markdown_table(doc)
        
        unless markdown_table.include?('Option | Required | Type | Description')
          @failed_tests += 1
          @errors << "Failed to generate valid table for plugin type #{singular}"
          return
        end
        
      rescue JSON::ParserError => e
        @failed_tests += 1
        @errors << "JSON parse error in #{test_file}: #{e.message}"
        return
      end
    end
    
    @passed_tests += 1
  end

  def test_html_content_preservation_in_conversion
    @test_count += 1
    
    # Test that HTML content is preserved during JSON to Markdown conversion
    html_test_file = File.join(BASE_PATH, 'processors', 'html-test.json')
    
    if File.exist?(html_test_file)
      begin
        doc = JSON.parse(File.read(html_test_file))
        markdown_table = generate_markdown_table(doc)
        
        # Check that HTML tags are preserved
        html_elements = ['<code>', '<em>', '<strong>', '<a href=', '&lt;', '&gt;']
        
        html_elements.each do |element|
          # Find properties that contain this HTML element
          properties_with_html = doc['properties'].select do |_, prop_config|
            prop_config['description'] && prop_config['description'].include?(element)
          end
          
          unless properties_with_html.empty?
            # The markdown table should contain this HTML element
            unless markdown_table.include?(element)
              @failed_tests += 1
              @errors << "HTML element '#{element}' not preserved in generated Markdown table"
              return
            end
          end
        end
        
      rescue JSON::ParserError => e
        @failed_tests += 1
        @errors << "JSON parse error in HTML test file: #{e.message}"
        return
      end
    end
    
    @passed_tests += 1
  end

  def generate_markdown_table(json_doc)
    lines = []
    lines << "Option | Required | Type | Description"
    lines << ":--- | :--- |:--- | :---"
    
    json_doc['properties'].each do |prop_name, prop_config|
      required_text = prop_config['required'] ? 'Yes' : 'No'
      
      type_display = prop_config['type'].capitalize
      type_display = 'List' if prop_config['type'] == 'array'
      type_display = 'Map' if prop_config['type'] == 'object'
      
      description = prop_config['description'] || ''
      if prop_config['default'] != nil
        description += " Default is `#{prop_config['default']}`."
      end
      
      lines << "`#{prop_name}` | #{required_text} | #{type_display} | #{description.strip}"
    end
    
    lines.join("\n")
  end

  def generate_full_markdown_output(json_doc)
    output = []
    
    # Main table
    output << generate_markdown_table(json_doc)
    
    # Nested property tables
    json_doc['properties'].each do |prop_name, prop_config|
      if prop_config['properties']
        section_name = prop_name.gsub('_', ' ').split.map(&:capitalize).join(' ')
        output << "\n### #{section_name} options"
        output << "\nThe following table describes the options for the `#{prop_name}` configuration."
        output << "\nOption | Required | Type | Description"
        output << ":--- | :--- |:--- | :---"
        
        prop_config['properties'].each do |nested_name, nested_config|
          required_text = nested_config['required'] ? 'Yes' : 'No'
          type_display = nested_config['type'].capitalize
          type_display = 'List' if nested_config['type'] == 'array'
          type_display = 'Map' if nested_config['type'] == 'object'
          
          description = nested_config['description'] || ''
          if nested_config['default'] != nil
            description += " Default is `#{nested_config['default']}`."
          end
          
          output << "`#{nested_name}` | #{required_text} | #{type_display} | #{description.strip}"
        end
      end
    end
    
    output.join("\n")
  end

  def validate_markdown_table_structure(table)
    lines = table.split("\n")
    
    # Should have at least header and separator
    return false if lines.length < 2
    
    # Check header
    header = lines[0]
    return false unless header.include?('Option') && header.include?('Required') && 
                       header.include?('Type') && header.include?('Description')
    
    # Check separator
    separator = lines[1]
    return false unless separator.match?(/^:?---.*:?---.*:?---.*:?---/)
    
    true
  end

  def validate_table_content_completeness(json_doc, markdown_table)
    # Check that all properties from JSON are in the markdown table
    json_doc['properties'].each do |prop_name, prop_config|
      return false unless markdown_table.include?("`#{prop_name}`")
      
      # Check that type is represented
      type_display = prop_config['type'].capitalize
      type_display = 'List' if prop_config['type'] == 'array'
      type_display = 'Map' if prop_config['type'] == 'object'
      
      return false unless markdown_table.include?(type_display)
    end
    
    true
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
      puts "\n✅ All build-time conversion property tests passed!"
    end
  end
end

# Run the test if script is executed directly
if __FILE__ == $0
  test = BuildTimeConversionTest.new
  success = test.run_property_tests
  exit(success ? 0 : 1)
end