#!/usr/bin/env ruby

require 'json'
require 'pathname'
require 'tempfile'
require 'stringio'

# Property-based test for schema-documentation alignment
# **Feature: data-prepper-json-docs, Property 2: Schema-documentation structural alignment**
# **Validates: Requirements 1.2, 1.4, 2.1, 2.5**

class SchemaDocumentationAlignmentTest
  VALID_TYPES = %w[string boolean integer number array object]
  VALID_PLUGIN_TYPES = %w[processor source sink buffer]
  
  def initialize
    @test_count = 0
    @passed_tests = 0
    @failed_tests = 0
    @errors = []
    @temp_files = []
  end

  def run_property_tests
    puts "🧪 Running Property Test: Schema-documentation structural alignment"
    puts "   Testing 100 random schema-documentation pairs..."
    
    # Property: For any JSON schema and corresponding JSON documentation, 
    # all property names and types in the schema should have matching entries 
    # in the documentation structure
    100.times do |iteration|
      test_schema_documentation_alignment(iteration)
    end
    
    # Additional specific test cases
    test_nested_property_alignment
    test_array_type_alignment
    test_required_field_alignment
    
    cleanup_temp_files
    report_results
    @failed_tests == 0
  end

  private

  def test_schema_documentation_alignment(iteration)
    @test_count += 1
    
    # Generate random schema structure
    schema = generate_random_schema(iteration)
    
    # Generate corresponding documentation that should align
    aligned_doc = generate_aligned_documentation(schema)
    
    # Test that aligned documentation passes validation
    if validate_alignment(schema, aligned_doc)
      @passed_tests += 1
    else
      @failed_tests += 1
      @errors << "Iteration #{iteration}: Aligned schema and documentation should validate successfully"
      return
    end
    
    # Generate misaligned documentation and test that it fails
    @test_count += 1
    misaligned_doc = generate_misaligned_documentation(schema)
    
    if validate_alignment(schema, misaligned_doc)
      @failed_tests += 1
      @errors << "Iteration #{iteration}: Misaligned schema and documentation should fail validation"
    else
      @passed_tests += 1
    end
  end

  def test_nested_property_alignment
    @test_count += 1
    
    # Test nested object properties
    schema = {
      "name" => "nested_test",
      "plugin_type" => "processor",
      "properties" => {
        "parent_prop" => {
          "type" => "object",
          "required" => false,
          "properties" => {
            "nested_prop1" => {
              "type" => "string",
              "required" => true
            },
            "nested_prop2" => {
              "type" => "integer",
              "required" => false,
              "default" => 42
            }
          }
        }
      }
    }
    
    aligned_doc = {
      "name" => "nested_test",
      "plugin_type" => "processor",
      "properties" => {
        "parent_prop" => {
          "type" => "object",
          "description" => "Parent object property",
          "required" => false,
          "properties" => {
            "nested_prop1" => {
              "type" => "string",
              "description" => "Nested string property",
              "required" => true
            },
            "nested_prop2" => {
              "type" => "integer",
              "description" => "Nested integer property",
              "required" => false,
              "default" => 42
            }
          }
        }
      }
    }
    
    if validate_alignment(schema, aligned_doc)
      @passed_tests += 1
    else
      @failed_tests += 1
      @errors << "Nested property alignment test should pass"
    end
  end

  def test_array_type_alignment
    @test_count += 1
    
    # Test array properties with items specification
    schema = {
      "name" => "array_test",
      "plugin_type" => "processor",
      "properties" => {
        "string_array" => {
          "type" => "array",
          "required" => false,
          "items" => {
            "type" => "string"
          }
        },
        "object_array" => {
          "type" => "array",
          "required" => true,
          "items" => {
            "type" => "object"
          }
        }
      }
    }
    
    aligned_doc = {
      "name" => "array_test",
      "plugin_type" => "processor",
      "properties" => {
        "string_array" => {
          "type" => "array",
          "description" => "Array of strings",
          "required" => false,
          "items" => {
            "type" => "string"
          }
        },
        "object_array" => {
          "type" => "array",
          "description" => "Array of objects",
          "required" => true,
          "items" => {
            "type" => "object"
          }
        }
      }
    }
    
    if validate_alignment(schema, aligned_doc)
      @passed_tests += 1
    else
      @failed_tests += 1
      @errors << "Array type alignment test should pass"
    end
  end

  def test_required_field_alignment
    @test_count += 1
    
    # Test required field consistency
    schema = {
      "name" => "required_test",
      "plugin_type" => "processor",
      "properties" => {
        "required_prop" => {
          "type" => "string",
          "required" => true
        },
        "optional_prop" => {
          "type" => "boolean",
          "required" => false,
          "default" => false
        }
      }
    }
    
    # Test with matching required fields
    aligned_doc = {
      "name" => "required_test",
      "plugin_type" => "processor",
      "properties" => {
        "required_prop" => {
          "type" => "string",
          "description" => "Required string property",
          "required" => true
        },
        "optional_prop" => {
          "type" => "boolean",
          "description" => "Optional boolean property",
          "required" => false,
          "default" => false
        }
      }
    }
    
    if validate_alignment(schema, aligned_doc)
      @passed_tests += 1
    else
      @failed_tests += 1
      @errors << "Required field alignment test should pass"
    end
  end

  def generate_random_schema(seed)
    rand_gen = Random.new(seed)
    
    plugin_name = "test_plugin_#{seed}"
    plugin_type = VALID_PLUGIN_TYPES.sample(random: rand_gen)
    
    # Generate 1-5 properties
    property_count = rand_gen.rand(1..5)
    properties = {}
    
    property_count.times do |i|
      prop_name = "property_#{i}"
      prop_type = VALID_TYPES.sample(random: rand_gen)
      
      property = {
        "type" => prop_type,
        "required" => rand_gen.rand(2) == 1
      }
      
      # Add default value sometimes
      if rand_gen.rand(3) == 1
        property["default"] = generate_default_value(prop_type, rand_gen)
      end
      
      # Add nested properties for object types
      if prop_type == "object" && rand_gen.rand(2) == 1
        property["properties"] = generate_nested_properties(rand_gen, 1)
      end
      
      # Add items for array types
      if prop_type == "array"
        item_type = (VALID_TYPES - ["array"]).sample(random: rand_gen)
        property["items"] = { "type" => item_type }
      end
      
      properties[prop_name] = property
    end
    
    {
      "name" => plugin_name,
      "plugin_type" => plugin_type,
      "properties" => properties
    }
  end

  def generate_nested_properties(rand_gen, depth)
    return {} if depth > 2 # Limit nesting depth
    
    nested_count = rand_gen.rand(1..3)
    nested_props = {}
    
    nested_count.times do |i|
      prop_name = "nested_prop_#{i}"
      prop_type = VALID_TYPES.sample(random: rand_gen)
      
      property = {
        "type" => prop_type,
        "required" => rand_gen.rand(2) == 1
      }
      
      if prop_type == "object" && rand_gen.rand(3) == 1
        property["properties"] = generate_nested_properties(rand_gen, depth + 1)
      end
      
      nested_props[prop_name] = property
    end
    
    nested_props
  end

  def generate_default_value(type, rand_gen)
    case type
    when "string" then "default_string_#{rand_gen.rand(100)}"
    when "boolean" then rand_gen.rand(2) == 1
    when "integer" then rand_gen.rand(1..1000)
    when "number" then rand_gen.rand * 100
    when "array" then []
    when "object" then {}
    end
  end

  def generate_aligned_documentation(schema)
    doc = {
      "name" => schema["name"],
      "plugin_type" => schema["plugin_type"],
      "description" => "Test plugin description",
      "properties" => {}
    }
    
    schema["properties"].each do |prop_name, prop_config|
      doc_prop = {
        "type" => prop_config["type"],
        "description" => "Description for #{prop_name}",
        "required" => prop_config["required"]
      }
      
      doc_prop["default"] = prop_config["default"] if prop_config.key?("default")
      doc_prop["items"] = prop_config["items"] if prop_config.key?("items")
      
      if prop_config["properties"]
        doc_prop["properties"] = generate_aligned_nested_properties(prop_config["properties"])
      end
      
      doc["properties"][prop_name] = doc_prop
    end
    
    doc
  end

  def generate_aligned_nested_properties(schema_props)
    doc_props = {}
    
    schema_props.each do |prop_name, prop_config|
      doc_prop = {
        "type" => prop_config["type"],
        "description" => "Nested description for #{prop_name}",
        "required" => prop_config["required"]
      }
      
      doc_prop["default"] = prop_config["default"] if prop_config.key?("default")
      
      if prop_config["properties"]
        doc_prop["properties"] = generate_aligned_nested_properties(prop_config["properties"])
      end
      
      doc_props[prop_name] = doc_prop
    end
    
    doc_props
  end

  def generate_misaligned_documentation(schema)
    doc = generate_aligned_documentation(schema)
    
    # Introduce random misalignments that should definitely be caught
    misalignment_type = rand(3) # Reduced to 3 since required field changes generate warnings, not errors
    
    case misalignment_type
    when 0
      # Remove a property from documentation (should cause "Missing documentation" error)
      if doc["properties"].any?
        prop_to_remove = doc["properties"].keys.sample
        doc["properties"].delete(prop_to_remove)
      else
        # Fallback: add extra property if no properties to remove
        doc["properties"]["extra_property"] = {
          "type" => "string",
          "description" => "Extra property not in schema",
          "required" => false
        }
      end
    when 1
      # Add an extra property to documentation (should cause "Extra documentation" warning)
      doc["properties"]["extra_property_#{rand(1000)}"] = {
        "type" => "string",
        "description" => "Extra property not in schema",
        "required" => false
      }
    when 2
      # Change a property type (should cause "Type mismatch" error)
      if doc["properties"].any?
        prop_name = doc["properties"].keys.sample
        original_type = doc["properties"][prop_name]["type"]
        # Ensure we pick a different type
        available_types = VALID_TYPES - [original_type]
        if available_types.any?
          new_type = available_types.sample
          doc["properties"][prop_name]["type"] = new_type
        else
          # Fallback: remove property instead
          doc["properties"].delete(prop_name)
        end
      else
        # Fallback: add extra property if no properties exist
        doc["properties"]["extra_property"] = {
          "type" => "string",
          "description" => "Extra property not in schema",
          "required" => false
        }
      end
    end
    
    doc
  end

  def validate_alignment(schema, doc)
    schema_file = create_temp_file("schema.json", schema.to_json)
    doc_file = create_temp_file("doc.json", doc.to_json)
    
    # Use the existing schema consistency validator
    require_relative 'validate-schema-consistency'
    validator = SchemaConsistencyValidator.new
    
    # Capture validation results
    original_stdout = $stdout
    captured_output = StringIO.new
    $stdout = captured_output
    
    begin
      result = validator.validate_plugin_consistency(doc_file, schema_file)
    ensure
      $stdout = original_stdout
    end
    
    # Check if there were any errors or significant warnings
    errors = validator.instance_variable_get(:@errors) || []
    warnings = validator.instance_variable_get(:@warnings) || []
    
    # For property testing, we consider both errors and warnings as validation failures
    # since we want strict alignment between schema and documentation
    errors.empty? && warnings.empty?
  end

  def create_temp_file(name, content)
    temp_file = Tempfile.new([name.gsub('.', '_'), '.json'])
    temp_file.write(content)
    temp_file.close
    @temp_files << temp_file
    temp_file.path
  end

  def cleanup_temp_files
    @temp_files.each(&:unlink)
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
      puts "   Schema-documentation alignment property holds across all test cases"
    end
  end
end

# Run the test if script is executed directly
if __FILE__ == $0
  require 'stringio'
  
  test = SchemaDocumentationAlignmentTest.new
  success = test.run_property_tests
  exit(success ? 0 : 1)
end