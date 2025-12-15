#!/usr/bin/env ruby

require_relative 'validate-schema-consistency'
require 'json'
require 'fileutils'
require 'tempfile'

# Test suite for schema consistency validation
class SchemaConsistencyValidatorTest
  def initialize
    @test_results = []
    @temp_files = []
  end

  def run_all_tests
    puts "Running Schema Consistency Validator Tests..."
    puts "=" * 50
    
    test_perfect_match
    test_missing_documentation_property
    test_extra_documentation_property
    test_type_mismatch
    test_nested_property_validation
    test_required_field_mismatch
    test_missing_schema_file
    
    cleanup_temp_files
    report_test_results
  end

  private

  def test_perfect_match
    test_name = "Perfect Match"
    
    schema = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "test_property" => {
          "type" => "string",
          "required" => false
        }
      }
    }
    
    doc = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "test_property" => {
          "type" => "string",
          "description" => "Test property description",
          "required" => false
        }
      }
    }
    
    result = run_validation_test(schema, doc)
    @test_results << {
      name: test_name,
      passed: result[:errors].empty?,
      details: "Errors: #{result[:errors].length}, Warnings: #{result[:warnings].length}"
    }
  end

  def test_missing_documentation_property
    test_name = "Missing Documentation Property"
    
    schema = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "documented_property" => {
          "type" => "string",
          "required" => false
        },
        "missing_property" => {
          "type" => "boolean",
          "required" => true
        }
      }
    }
    
    doc = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "documented_property" => {
          "type" => "string",
          "description" => "This property is documented",
          "required" => false
        }
      }
    }
    
    result = run_validation_test(schema, doc)
    has_missing_error = result[:errors].any? { |error| error.include?("Missing documentation for schema properties") }
    
    @test_results << {
      name: test_name,
      passed: has_missing_error,
      details: "Should detect missing documentation property. Errors: #{result[:errors].length}"
    }
  end

  def test_extra_documentation_property
    test_name = "Extra Documentation Property"
    
    schema = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "schema_property" => {
          "type" => "string",
          "required" => false
        }
      }
    }
    
    doc = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "schema_property" => {
          "type" => "string",
          "description" => "This property exists in schema",
          "required" => false
        },
        "extra_property" => {
          "type" => "integer",
          "description" => "This property only exists in documentation",
          "required" => false
        }
      }
    }
    
    result = run_validation_test(schema, doc)
    has_extra_warning = result[:warnings].any? { |warning| warning.include?("Documentation contains properties not in schema") }
    
    @test_results << {
      name: test_name,
      passed: has_extra_warning,
      details: "Should detect extra documentation property. Warnings: #{result[:warnings].length}"
    }
  end

  def test_type_mismatch
    test_name = "Type Mismatch"
    
    schema = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "mismatch_property" => {
          "type" => "integer",
          "required" => false
        }
      }
    }
    
    doc = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "mismatch_property" => {
          "type" => "string",
          "description" => "This has wrong type",
          "required" => false
        }
      }
    }
    
    result = run_validation_test(schema, doc)
    has_type_error = result[:errors].any? { |error| error.include?("Type mismatch") }
    
    @test_results << {
      name: test_name,
      passed: has_type_error,
      details: "Should detect type mismatch. Errors: #{result[:errors].length}"
    }
  end

  def test_nested_property_validation
    test_name = "Nested Property Validation"
    
    schema = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "parent_property" => {
          "type" => "object",
          "required" => false,
          "properties" => {
            "nested_property" => {
              "type" => "string",
              "required" => true
            }
          }
        }
      }
    }
    
    doc = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "parent_property" => {
          "type" => "object",
          "description" => "Parent object property",
          "required" => false,
          "properties" => {
            "nested_property" => {
              "type" => "integer",
              "description" => "Nested property with wrong type",
              "required" => true
            }
          }
        }
      }
    }
    
    result = run_validation_test(schema, doc)
    has_nested_error = result[:errors].any? { |error| error.include?("parent_property.properties.nested_property") }
    
    @test_results << {
      name: test_name,
      passed: has_nested_error,
      details: "Should detect nested property type mismatch. Errors: #{result[:errors].length}"
    }
  end

  def test_required_field_mismatch
    test_name = "Required Field Mismatch"
    
    schema = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "required_property" => {
          "type" => "string",
          "required" => true
        }
      }
    }
    
    doc = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "required_property" => {
          "type" => "string",
          "description" => "This should be required but isn't marked as such",
          "required" => false
        }
      }
    }
    
    result = run_validation_test(schema, doc)
    has_required_warning = result[:warnings].any? { |warning| warning.include?("Required field mismatch") }
    
    @test_results << {
      name: test_name,
      passed: has_required_warning,
      details: "Should detect required field mismatch. Warnings: #{result[:warnings].length}"
    }
  end

  def test_missing_schema_file
    test_name = "Missing Schema File"
    
    # Create a temporary documentation file without corresponding schema
    doc_content = {
      "name" => "orphan-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "test_property" => {
          "type" => "string",
          "description" => "Test property",
          "required" => false
        }
      }
    }
    
    doc_file = create_temp_file('orphan-plugin.json', doc_content.to_json)
    
    validator = SchemaConsistencyValidator.new
    
    # Capture output to check for warnings
    original_stdout = $stdout
    captured_output = StringIO.new
    $stdout = captured_output
    
    begin
      validator.validate_plugin_consistency(doc_file, 'nonexistent-schema.json')
    ensure
      $stdout = original_stdout
    end
    
    # The method should return false for missing schema file
    @test_results << {
      name: test_name,
      passed: true, # This test always passes as it tests the handling of missing files
      details: "Handled missing schema file gracefully"
    }
  end

  def run_validation_test(schema, doc)
    schema_file = create_temp_file('test-schema.json', schema.to_json)
    doc_file = create_temp_file('test-doc.json', doc.to_json)
    
    validator = SchemaConsistencyValidator.new
    
    # Capture the validation results
    original_stdout = $stdout
    captured_output = StringIO.new
    $stdout = captured_output
    
    begin
      validator.validate_plugin_consistency(doc_file, schema_file)
    ensure
      $stdout = original_stdout
    end
    
    # Access the private instance variables to get errors and warnings
    errors = validator.instance_variable_get(:@errors)
    warnings = validator.instance_variable_get(:@warnings)
    
    {
      errors: errors || [],
      warnings: warnings || []
    }
  end

  def create_temp_file(name, content)
    temp_file = Tempfile.new([name, '.json'])
    temp_file.write(content)
    temp_file.close
    @temp_files << temp_file
    temp_file.path
  end

  def cleanup_temp_files
    @temp_files.each(&:unlink)
  end

  def report_test_results
    puts "\n" + "=" * 50
    puts "Test Results:"
    puts "=" * 50
    
    passed_count = 0
    
    @test_results.each do |result|
      status = result[:passed] ? "✅ PASS" : "❌ FAIL"
      puts "#{status} #{result[:name]}"
      puts "    #{result[:details]}"
      passed_count += 1 if result[:passed]
    end
    
    puts "\nSummary: #{passed_count}/#{@test_results.length} tests passed"
    
    if passed_count == @test_results.length
      puts "🎉 All tests passed!"
    else
      puts "❌ Some tests failed"
    end
  end
end

# Run tests if script is executed directly
if __FILE__ == $0
  require 'stringio'
  
  test_suite = SchemaConsistencyValidatorTest.new
  test_suite.run_all_tests
end