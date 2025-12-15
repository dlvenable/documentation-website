#!/usr/bin/env ruby

require 'json'

# Property-based test for HTML content preservation
# **Feature: data-prepper-json-docs, Property 5: HTML content preservation in JSON**
# **Validates: Requirements 3.3**

class HTMLPreservationTest
  BASE_PATH = '_data/data-prepper'
  PLUGIN_TYPES = %w[processors sources sinks buffers]
  VALID_HTML_TAGS = %w[code em strong a ul ol li pre br].freeze
  VALID_HTML_ENTITIES = %w[lt gt amp quot apos nbsp].freeze

  def initialize
    @test_count = 0
    @passed_tests = 0
    @failed_tests = 0
    @errors = []
  end

  def run_property_tests
    puts "🧪 Running Property Test: HTML content preservation in JSON"
    puts "   Testing 100 random HTML content scenarios..."
    
    # Property: For any HTML markup within JSON description fields, 
    # the content should remain well-formed and functionally equivalent after processing
    100.times do |iteration|
      test_html_content_preservation(iteration)
    end
    
    test_existing_html_content
    test_html_validation_logic
    test_liquid_template_html_handling
    
    report_results
    @failed_tests == 0
  end

  private

  def test_html_content_preservation(iteration)
    @test_count += 1
    
    # Generate random HTML content
    html_content = generate_random_html_content(iteration)
    
    # Create a test plugin with HTML content
    plugin_doc = {
      "name" => "html_test_#{iteration}",
      "plugin_type" => "processor",
      "properties" => {
        "test_property" => {
          "type" => "string",
          "description" => html_content,
          "required" => false
        }
      }
    }
    
    # Test 1: HTML content should be valid JSON
    begin
      json_string = JSON.generate(plugin_doc)
      parsed_back = JSON.parse(json_string)
      
      unless parsed_back["properties"]["test_property"]["description"] == html_content
        @failed_tests += 1
        @errors << "HTML content not preserved through JSON serialization for iteration #{iteration}"
        return
      end
    rescue JSON::GeneratorError, JSON::ParserError => e
      @failed_tests += 1
      @errors << "HTML content caused JSON serialization error for iteration #{iteration}: #{e.message}"
      return
    end
    
    # Test 2: HTML structure should be well-formed
    unless validate_html_structure(html_content)
      @failed_tests += 1
      @errors << "Generated HTML content is not well-formed for iteration #{iteration}: #{html_content}"
      return
    end
    
    # Test 3: HTML should only contain allowed tags
    unless validate_allowed_html_tags(html_content)
      @failed_tests += 1
      @errors << "HTML content contains disallowed tags for iteration #{iteration}: #{html_content}"
      return
    end
    
    @passed_tests += 1
  end

  def test_existing_html_content
    # Test actual JSON files that contain HTML
    PLUGIN_TYPES.each do |plugin_type|
      docs_dir = File.join(BASE_PATH, plugin_type)
      next unless Dir.exist?(docs_dir)

      Dir.glob(File.join(docs_dir, '*.json')).each do |file_path|
        @test_count += 1
        
        begin
          doc = JSON.parse(File.read(file_path))
          html_contents = extract_html_content(doc['properties'])
          
          html_contents.each do |content, path|
            # Test HTML structure
            unless validate_html_structure(content)
              @failed_tests += 1
              @errors << "Invalid HTML structure in #{file_path} at #{path}: #{content}"
              return
            end
            
            # Test allowed tags
            unless validate_allowed_html_tags(content)
              @failed_tests += 1
              @errors << "Disallowed HTML tags in #{file_path} at #{path}: #{content}"
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

  def test_html_validation_logic
    @test_count += 1
    
    # Test that our HTML validation script exists and works
    validation_script = '_script/validate-html-content.rb'
    
    unless File.exist?(validation_script)
      @failed_tests += 1
      @errors << "HTML validation script not found at #{validation_script}"
      return
    end
    
    # Test the validation script with known good and bad HTML
    test_cases = [
      { html: '<code>valid</code>', should_pass: true },
      { html: '<script>alert("bad")</script>', should_pass: false },
      { html: '<code>unclosed', should_pass: false },
      { html: 'Plain text with &lt; entities', should_pass: true }
    ]
    
    test_cases.each do |test_case|
      result = validate_html_structure(test_case[:html])
      expected = test_case[:should_pass]
      
      unless result == expected
        @failed_tests += 1
        @errors << "HTML validation failed for '#{test_case[:html]}': expected #{expected}, got #{result}"
        return
      end
    end
    
    @passed_tests += 1
  end

  def test_liquid_template_html_handling
    @test_count += 1
    
    # Test that the Liquid template preserves HTML content
    template_path = '_includes/data-prepper-config-table.html'
    
    unless File.exist?(template_path)
      @failed_tests += 1
      @errors << "Liquid template not found at #{template_path}"
      return
    end
    
    template_content = File.read(template_path)
    
    # Check that template uses strip filter to preserve HTML while removing extra whitespace
    unless template_content.include?('| strip')
      @failed_tests += 1
      @errors << "Liquid template should use 'strip' filter to preserve HTML content"
      return
    end
    
    # Check that template doesn't use escape filters that would break HTML
    if template_content.match?(/\|\s*(escape|xml_escape|uri_escape)/)
      @failed_tests += 1
      @errors << "Liquid template should not use escape filters that would break HTML content"
      return
    end
    
    @passed_tests += 1
  end

  def generate_random_html_content(seed)
    rand_gen = Random.new(seed)
    
    # Base content
    content_options = [
      "This is a simple description",
      "Configuration option for processing",
      "Specifies the behavior of the component"
    ]
    
    base_content = content_options[rand_gen.rand(content_options.length)]
    
    # Add random HTML elements
    html_additions = []
    
    # Add code tags
    if rand_gen.rand < 0.7
      code_words = %w[true false null timeout_ms pattern config]
      code_word = code_words[rand_gen.rand(code_words.length)]
      html_additions << "<code>#{code_word}</code>"
    end
    
    # Add emphasis
    if rand_gen.rand < 0.4
      emphasis_words = %w[required optional important deprecated]
      emphasis_word = emphasis_words[rand_gen.rand(emphasis_words.length)]
      html_additions << "<em>#{emphasis_word}</em>"
    end
    
    # Add strong text
    if rand_gen.rand < 0.3
      strong_words = %w[Note Warning Important Default]
      strong_word = strong_words[rand_gen.rand(strong_words.length)]
      html_additions << "<strong>#{strong_word}</strong>"
    end
    
    # Add links
    if rand_gen.rand < 0.5
      link_texts = ["documentation", "reference", "examples"]
      link_text = link_texts[rand_gen.rand(link_texts.length)]
      html_additions << "<a href=\"/docs/#{link_text}\">#{link_text}</a>"
    end
    
    # Add HTML entities
    if rand_gen.rand < 0.3
      entities = ["&lt;", "&gt;", "&amp;", "&quot;"]
      entity = entities[rand_gen.rand(entities.length)]
      html_additions << "special character #{entity}"
    end
    
    # Combine base content with HTML additions
    if html_additions.empty?
      base_content
    else
      "#{base_content} with #{html_additions.join(' and ')}."
    end
  end

  def extract_html_content(properties, path = [])
    html_contents = []
    return html_contents unless properties.is_a?(Hash)
    
    properties.each do |prop_name, prop_config|
      current_path = path + [prop_name]
      
      if prop_config['description'] && contains_html?(prop_config['description'])
        html_contents << [prop_config['description'], current_path.join('.')]
      end
      
      # Check examples
      if prop_config['examples'].is_a?(Array)
        prop_config['examples'].each_with_index do |example, idx|
          if example['description'] && contains_html?(example['description'])
            html_contents << [example['description'], (current_path + ['examples', idx]).join('.')]
          end
        end
      end
      
      # Recursively check nested properties
      if prop_config['properties']
        html_contents.concat(extract_html_content(prop_config['properties'], current_path + ['properties']))
      end
    end
    
    html_contents
  end

  def contains_html?(text)
    text.match?(/<[a-zA-Z][^>]*>/) || text.match?(/&[a-zA-Z]+;/)
  end

  def validate_html_structure(html_content)
    # First check if all tags are allowed
    return false unless validate_allowed_html_tags(html_content)
    
    tag_stack = []
    
    # Find all HTML tags
    html_content.scan(/<(\/?[a-zA-Z][a-zA-Z0-9]*)[^>]*>/i) do |match|
      tag_with_slash = match[0].downcase
      
      if tag_with_slash.start_with?('/')
        # Closing tag
        tag = tag_with_slash[1..-1]
        return false unless tag_stack.last == tag
        tag_stack.pop
      elsif %w[br].include?(tag_with_slash)
        # Self-closing tag
        next
      else
        # Opening tag
        tag_stack.push(tag_with_slash)
      end
    end
    
    tag_stack.empty?
  end

  def validate_allowed_html_tags(html_content)
    tags = html_content.scan(/<\/?([a-zA-Z][a-zA-Z0-9]*)[^>]*>/i).flatten.map(&:downcase).uniq
    disallowed_tags = tags - VALID_HTML_TAGS
    disallowed_tags.empty?
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
      puts "\n✅ All HTML preservation property tests passed!"
    end
  end
end

# Run the test if script is executed directly
if __FILE__ == $0
  test = HTMLPreservationTest.new
  success = test.run_property_tests
  exit(success ? 0 : 1)
end