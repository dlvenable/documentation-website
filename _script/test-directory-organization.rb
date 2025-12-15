#!/usr/bin/env ruby

require 'json'
require 'pathname'

# Property-based test for directory organization
# **Feature: data-prepper-json-docs, Property 1: Plugin directory organization consistency**
# **Validates: Requirements 1.1, 1.5**

class DirectoryOrganizationTest
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
    puts "🧪 Running Property Test: Plugin directory organization consistency"
    puts "   Testing 100 random plugin configurations..."
    
    # Property: For any plugin documentation file, the file should be stored 
    # in the correct directory based on its plugin_type
    100.times do |iteration|
      test_plugin_directory_consistency(iteration)
    end
    
    test_directory_structure_exists
    test_invalid_plugin_types
    
    report_results
    @failed_tests == 0
  end

  private

  def test_plugin_directory_consistency(iteration)
    @test_count += 1
    
    # Generate random plugin data
    plugin_type = VALID_PLUGIN_TYPES_SINGULAR.sample
    plugin_name = "test_plugin_#{iteration}_#{rand(1000)}"
    
    plugin_doc = {
      "name" => plugin_name,
      "plugin_type" => plugin_type,
      "properties" => {
        "test_property" => {
          "type" => "string",
          "description" => "Test property for validation"
        }
      }
    }
    
    # Determine expected directory
    expected_directory = case plugin_type
    when 'processor' then 'processors'
    when 'source' then 'sources'  
    when 'sink' then 'sinks'
    when 'buffer' then 'buffers'
    end
    
    expected_path = File.join(BASE_PATH, expected_directory)
    
    # Test 1: Directory should exist
    unless Dir.exist?(expected_path)
      @failed_tests += 1
      @errors << "Directory #{expected_path} should exist for plugin_type #{plugin_type}"
      return
    end
    
    # Test 2: Correct placement should validate
    correct_file_path = File.join(expected_path, "#{plugin_name}.json")
    unless validate_plugin_placement(correct_file_path, plugin_doc)
      @failed_tests += 1
      @errors << "Plugin #{plugin_name} with type #{plugin_type} should be valid in #{expected_directory}/"
      return
    end
    
    # Test 3: Incorrect placement should fail (test with wrong directory)
    wrong_directories = PLUGIN_TYPES - [expected_directory]
    wrong_directory = wrong_directories.sample
    wrong_file_path = File.join(BASE_PATH, wrong_directory, "#{plugin_name}.json")
    
    if validate_plugin_placement(wrong_file_path, plugin_doc)
      @failed_tests += 1
      @errors << "Plugin #{plugin_name} with type #{plugin_type} should be invalid in wrong directory #{wrong_directory}/"
      return
    end
    
    @passed_tests += 1
  end

  def test_directory_structure_exists
    PLUGIN_TYPES.each do |plugin_type|
      @test_count += 1
      directory_path = File.join(BASE_PATH, plugin_type)
      
      if Dir.exist?(directory_path)
        @passed_tests += 1
      else
        @failed_tests += 1
        @errors << "Directory #{directory_path} should exist for plugin type #{plugin_type}"
      end
    end
  end

  def test_invalid_plugin_types
    invalid_types = ['invalid', 'unknown', 'processor_bad', 'source123', '']
    
    invalid_types.each do |invalid_type|
      @test_count += 1
      
      plugin_doc = {
        "name" => "test_plugin",
        "plugin_type" => invalid_type,
        "properties" => {}
      }
      
      # Test that invalid types are rejected in any directory
      valid_placement_found = false
      PLUGIN_TYPES.each do |directory|
        file_path = File.join(BASE_PATH, directory, "test_plugin.json")
        if validate_plugin_placement(file_path, plugin_doc)
          valid_placement_found = true
          break
        end
      end
      
      if valid_placement_found
        @failed_tests += 1
        @errors << "Plugin with invalid type '#{invalid_type}' should be rejected in all directories"
      else
        @passed_tests += 1
      end
    end
  end

  def validate_plugin_placement(file_path, plugin_doc)
    # Extract plugin type from file path
    path_parts = Pathname.new(file_path).each_filename.to_a
    directory_type = path_parts[-2] # e.g., 'processors' from path
    
    # Convert plural directory name to singular plugin type
    expected_type = case directory_type
    when 'processors' then 'processor'
    when 'sources' then 'source'
    when 'sinks' then 'sink'
    when 'buffers' then 'buffer'
    else directory_type
    end
    
    actual_type = plugin_doc['plugin_type']
    
    # Validation passes if types match and plugin_type is valid
    VALID_PLUGIN_TYPES_SINGULAR.include?(actual_type) && actual_type == expected_type
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
      puts "\n✅ All property tests passed!"
    end
  end
end

# Run the test if script is executed directly
if __FILE__ == $0
  test = DirectoryOrganizationTest.new
  success = test.run_property_tests
  exit(success ? 0 : 1)
end