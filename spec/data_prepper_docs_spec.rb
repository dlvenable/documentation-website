require 'rspec'
require 'json'
require 'fileutils'
require 'tmpdir'

# Property-based tests for Data Prepper documentation system
# **Feature: data-prepper-json-docs, Property 1: Plugin directory organization consistency**
# **Validates: Requirements 1.1, 1.5**

describe 'Data Prepper Documentation System' do
  let(:base_path) { '_data/data-prepper' }
  let(:plugin_types) { %w[processors sources sinks buffers] }
  let(:valid_plugin_types_singular) { %w[processor source sink buffer] }

  describe 'Property 1: Plugin directory organization consistency' do
    it 'stores plugin documentation files in correct directories based on plugin_type' do
      # Property: For any plugin documentation file, the file should be stored 
      # in the correct directory based on its plugin_type (sources/, processors/, sinks/, buffers/)
      
      100.times do |iteration|
        # Generate random plugin data
        plugin_type_index = rand(valid_plugin_types_singular.length)
        plugin_type = valid_plugin_types_singular[plugin_type_index]
        plugin_name = "test_plugin_#{iteration}_#{rand(1000)}"
        
        # Create plugin documentation
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
        
        # Determine expected directory based on plugin type
        expected_directory = case plugin_type
        when 'processor' then 'processors'
        when 'source' then 'sources'  
        when 'sink' then 'sinks'
        when 'buffer' then 'buffers'
        end
        
        expected_path = File.join(base_path, expected_directory)
        
        # Verify directory exists
        expect(Dir.exist?(expected_path)).to be true, 
          "Directory #{expected_path} should exist for plugin_type #{plugin_type}"
        
        # Test file placement validation
        correct_file_path = File.join(expected_path, "#{plugin_name}.json")
        incorrect_file_path = File.join(base_path, plugin_types.sample, "#{plugin_name}.json")
        
        # The validation should pass for correct placement
        expect(validate_plugin_placement(correct_file_path, plugin_doc)).to be true,
          "Plugin #{plugin_name} with type #{plugin_type} should be valid in #{expected_directory}/"
        
        # The validation should fail for incorrect placement (if different directory)
        unless correct_file_path == incorrect_file_path
          expect(validate_plugin_placement(incorrect_file_path, plugin_doc)).to be false,
            "Plugin #{plugin_name} with type #{plugin_type} should be invalid in wrong directory"
        end
      end
    end
    
    it 'validates directory structure exists for all plugin types' do
      plugin_types.each do |plugin_type|
        directory_path = File.join(base_path, plugin_type)
        expect(Dir.exist?(directory_path)).to be true,
          "Directory #{directory_path} should exist for plugin type #{plugin_type}"
      end
    end
    
    it 'rejects plugins with invalid plugin_type values' do
      invalid_types = ['invalid', 'unknown', 'processor_bad', 'source123', '']
      
      invalid_types.each do |invalid_type|
        plugin_doc = {
          "name" => "test_plugin",
          "plugin_type" => invalid_type,
          "properties" => {}
        }
        
        plugin_types.each do |directory|
          file_path = File.join(base_path, directory, "test_plugin.json")
          expect(validate_plugin_placement(file_path, plugin_doc)).to be false,
            "Plugin with invalid type '#{invalid_type}' should be rejected"
        end
      end
    end
  end

  private

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
    valid_plugin_types_singular.include?(actual_type) && actual_type == expected_type
  end
end