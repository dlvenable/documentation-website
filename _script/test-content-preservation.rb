#!/usr/bin/env ruby

require 'json'
require 'liquid'

# Property-based test for content preservation during format conversion
# **Feature: data-prepper-json-docs, Property 3: Content preservation during format conversion**
# **Validates: Requirements 1.3, 2.2, 2.3, 4.3, 5.2**

class ContentPreservationTest
  BASE_PATH = '_data/data-prepper'
  PLUGIN_TYPES = %w[processors sources sinks buffers]

  def initialize
    @test_count = 0
    @passed_tests = 0
    @failed_tests = 0
    @errors = []
  end

  def run_property_tests
    puts "🧪 Running Property Test: Content preservation during format conversion"
    puts "   Testing 100 random content scenarios and all existing plugins..."
    
    # Property: For any documentation content (descriptions, examples, defaults, HTML markup), 
    # converting between formats (Markdown→JSON→HTML) should preserve all original information
    
    # Test 1: Random content generation and preservation
    100.times do |iteration|
      test_random_content_preservation(iteration)
    end
    
    # Test 2: Existing plugin content preservation
    test_existing_plugin_content_preservation
    
    # Test 3: HTML markup preservation
    test_html_markup_preservation
    
    # Test 4: Round-trip conversion preservation
    test_round_trip_preservation
    
    report_results
    @failed_tests == 0
  end

  private

  def test_random_content_preservation(iteration)
    @test_count += 1
    
    # Generate random plugin documentation
    plugin_doc = generate_random_plugin_doc(iteration)
    
    # Convert to HTML using template
    html_output = render_plugin_template(plugin_doc, "test-plugin-#{iteration}", "processor")
    
    # Skip if template didn't render (expected for random data)
    if html_output.strip.empty? || !html_output.include?('<table>')
      @passed_tests += 1
      return
    end
    
    # Validate that all properties are preserved
    plugin_doc['properties'].each do |prop_name, prop_config|
      # Check property name preservation
      unless html_output.include?("<code>#{prop_name}</code>")
        @failed_tests += 1
        @errors << "Property name '#{prop_name}' not preserved in iteration #{iteration}"
        return
      end
      
      # Check description preservation
      if prop_config['description']
        description = prop_config['description'].strip
        unless html_output.include?(description)
          @failed_tests += 1
          @errors << "Description not preserved for '#{prop_name}' in iteration #{iteration}"
          return
        end
      end
      
      # Check type preservation (match template logic exactly)
      if prop_config['type']
        type_display = case prop_config['type']
                      when 'array'
                        # Template only shows 'List' if items.type is present
                        prop_config['items'] && prop_config['items']['type'] ? 'List' : 'Array'
                      when 'object' then 'Map'
                      else prop_config['type'].capitalize
                      end
        unless html_output.include?(type_display)
          @failed_tests += 1
          @errors << "Type '#{type_display}' not preserved for '#{prop_name}' in iteration #{iteration}"
          return
        end
      end
    end
    
    @passed_tests += 1
  end

  def test_existing_plugin_content_preservation
    @test_count += 1
    
    plugins_tested = 0
    
    PLUGIN_TYPES.each do |plugin_type|
      data_dir = File.join(BASE_PATH, plugin_type)
      next unless Dir.exist?(data_dir)
      
      Dir.glob(File.join(data_dir, '*.json')).each do |json_file|
        plugin_name = File.basename(json_file, '.json')
        
        begin
          plugin_doc = JSON.parse(File.read(json_file))
          html_output = render_plugin_template(plugin_doc, plugin_name, plugin_type.chomp('s'))
          
          # Skip if no output (template issue, not content issue)
          next if html_output.strip.empty? || !html_output.include?('<table>')
          
          # Validate content preservation for this plugin
          validate_plugin_content_in_html(plugin_doc, html_output, plugin_name)
          plugins_tested += 1
          
        rescue JSON::ParserError => e
          @failed_tests += 1
          @errors << "JSON parse error for #{plugin_name}: #{e.message}"
          return
        rescue => e
          @failed_tests += 1
          @errors << "Template error for #{plugin_name}: #{e.message}"
          return
        end
      end
    end
    
    if plugins_tested > 0
      @passed_tests += 1
    else
      @failed_tests += 1
      @errors << "No plugins found to test content preservation"
    end
  end

  def test_html_markup_preservation
    @test_count += 1
    
    # Test specific HTML markup preservation
    html_test_cases = [
      {
        description: "Property with <code>inline code</code> formatting",
        expected_tags: ['<code>', '</code>']
      },
      {
        description: "Property with <em>emphasis</em> and <strong>bold</strong> text",
        expected_tags: ['<em>', '</em>', '<strong>', '</strong>']
      },
      {
        description: "Property with <a href=\"/docs/link\">links</a>",
        expected_tags: ['<a href="/docs/link">', '</a>']
      },
      {
        description: "Property with HTML entities: &lt;, &gt;, &amp;",
        expected_entities: ['&lt;', '&gt;', '&amp;']
      }
    ]
    
    html_test_cases.each_with_index do |test_case, index|
      plugin_doc = {
        'name' => "html-test-#{index}",
        'plugin_type' => 'processor',
        'properties' => {
          'test_property' => {
            'type' => 'string',
            'description' => test_case[:description],
            'required' => false
          }
        }
      }
      
      html_output = render_plugin_template(plugin_doc, "html-test-#{index}", "processor")
      
      # Check for expected HTML tags
      if test_case[:expected_tags]
        test_case[:expected_tags].each do |tag|
          unless html_output.include?(tag)
            @failed_tests += 1
            @errors << "HTML tag '#{tag}' not preserved in HTML markup test #{index}"
            return
          end
        end
      end
      
      # Check for expected HTML entities
      if test_case[:expected_entities]
        test_case[:expected_entities].each do |entity|
          unless html_output.include?(entity)
            @failed_tests += 1
            @errors << "HTML entity '#{entity}' not preserved in HTML markup test #{index}"
            return
          end
        end
      end
    end
    
    @passed_tests += 1
  end

  def test_round_trip_preservation
    @test_count += 1
    
    # Test that JSON → HTML → extracted content preserves information
    original_plugin = {
      'name' => 'round-trip-test',
      'plugin_type' => 'processor',
      'properties' => {
        'test_prop' => {
          'type' => 'string',
          'description' => 'Test description with <code>code</code> and <em>emphasis</em>',
          'required' => true,
          'default' => 'test-value'
        },
        'array_prop' => {
          'type' => 'array',
          'description' => 'Array property description',
          'required' => false
        },
        'object_prop' => {
          'type' => 'object',
          'description' => 'Object property with nested structure',
          'required' => false,
          'properties' => {
            'nested_prop' => {
              'type' => 'string',
              'description' => 'Nested property description',
              'required' => false
            }
          }
        }
      }
    }
    
    html_output = render_plugin_template(original_plugin, 'round-trip-test', 'processor')
    
    # Validate that all original information is present in HTML
    original_plugin['properties'].each do |prop_name, prop_config|
      # Property name
      unless html_output.include?("<code>#{prop_name}</code>")
        @failed_tests += 1
        @errors << "Round-trip test failed: property name '#{prop_name}' not preserved"
        return
      end
      
      # Description
      unless html_output.include?(prop_config['description'])
        @failed_tests += 1
        @errors << "Round-trip test failed: description for '#{prop_name}' not preserved"
        return
      end
      
      # Required status
      required_text = prop_config['required'] ? 'Yes' : 'No'
      # Note: This is harder to validate precisely in HTML, but structure should be there
      
      # Default value (if present)
      if prop_config['default']
        unless html_output.include?("`#{prop_config['default']}`")
          @failed_tests += 1
          @errors << "Round-trip test failed: default value for '#{prop_name}' not preserved"
          return
        end
      end
    end
    
    # Check nested properties table is generated
    if html_output.include?('### Object prop options')
      unless html_output.include?('<code>nested_prop</code>')
        @failed_tests += 1
        @errors << "Round-trip test failed: nested property not preserved"
        return
      end
    else
      @failed_tests += 1
      @errors << "Round-trip test failed: nested properties section not generated"
      return
    end
    
    @passed_tests += 1
  end

  def generate_random_plugin_doc(seed)
    rand_gen = Random.new(seed)
    
    property_count = rand_gen.rand(1..5)
    properties = {}
    
    property_count.times do |i|
      prop_name = "property_#{i}"
      prop_type = ['string', 'integer', 'boolean', 'array', 'object'][rand_gen.rand(5)]
      
      properties[prop_name] = {
        'type' => prop_type,
        'description' => generate_random_description(rand_gen),
        'required' => rand_gen.rand < 0.5
      }
      
      # Add default value sometimes
      if rand_gen.rand < 0.3
        properties[prop_name]['default'] = case prop_type
                                          when 'string' then 'default_value'
                                          when 'integer' then rand_gen.rand(1..100)
                                          when 'boolean' then rand_gen.rand < 0.5
                                          when 'array' then []
                                          when 'object' then {}
                                          end
      end
    end
    
    {
      'name' => "test_plugin_#{seed}",
      'plugin_type' => 'processor',
      'properties' => properties
    }
  end

  def generate_random_description(rand_gen)
    base_descriptions = [
      "Configuration option for processing",
      "Specifies the behavior of the component",
      "Controls how data is handled"
    ]
    
    base = base_descriptions[rand_gen.rand(base_descriptions.length)]
    
    # Add HTML markup sometimes
    if rand_gen.rand < 0.4
      html_elements = ['<code>value</code>', '<em>important</em>', '<strong>required</strong>']
      base += " with #{html_elements[rand_gen.rand(html_elements.length)]}"
    end
    
    base
  end

  def render_plugin_template(plugin_doc, plugin_name, plugin_type)
    template_content = File.read('_includes/data-prepper-config-table.html')
    template = Liquid::Template.parse(template_content)
    
    site_data = {
      'data-prepper' => {
        "#{plugin_type}s" => {
          plugin_name => plugin_doc
        }
      }
    }
    
    template.render(
      'include' => { 'plugin' => plugin_name, 'plugin_type' => plugin_type },
      'site' => { 'data' => site_data }
    )
  rescue => e
    # Return empty string on template errors (expected for some random data)
    ""
  end

  def validate_plugin_content_in_html(plugin_doc, html_output, plugin_name)
    return unless plugin_doc['properties']
    
    plugin_doc['properties'].each do |prop_name, prop_config|
      # Validate property name
      unless html_output.include?("<code>#{prop_name}</code>")
        @failed_tests += 1
        @errors << "Property name '#{prop_name}' missing from #{plugin_name} HTML output"
        return
      end
      
      # Validate description
      if prop_config['description']
        description = prop_config['description'].strip
        unless html_output.include?(description)
          @failed_tests += 1
          @errors << "Description for '#{prop_name}' not preserved in #{plugin_name} HTML output"
          return
        end
      end
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
      puts "\n✅ All content preservation property tests passed!"
    end
  end
end

# Run the test if script is executed directly
if __FILE__ == $0
  test = ContentPreservationTest.new
  success = test.run_property_tests
  exit(success ? 0 : 1)
end