#!/usr/bin/env ruby

require_relative 'test-schema-documentation-alignment'
require 'json'
require 'tempfile'

# Validation test for the schema-documentation alignment property test
# This ensures the property test can actually detect misalignments
class SchemaAlignmentValidationTest
  def initialize
    @test_results = []
    @temp_files = []
  end

  def run_validation_tests
    puts "🔍 Validating Schema-Documentation Alignment Property Test"
    puts "=" * 60
    
    test_detects_missing_property
    test_detects_extra_property  
    test_detects_type_mismatch
    test_accepts_perfect_alignment
    
    cleanup_temp_files
    report_results
  end

  private

  def test_detects_missing_property
    test_name = "Detects Missing Property"
    
    schema = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "existing_prop" => { "type" => "string", "required" => false },
        "missing_prop" => { "type" => "boolean", "required" => true }
      }
    }
    
    doc = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "existing_prop" => {
          "type" => "string",
          "description" => "Existing property",
          "required" => false
        }
        # missing_prop is intentionally omitted
      }
    }
    
    alignment_test = SchemaDocumentationAlignmentTest.new
    result = alignment_test.send(:validate_alignment, schema, doc)
    
    @test_results << {
      name: test_name,
      passed: !result, # Should fail validation (return false)
      details: result ? "Failed to detect missing property" : "Correctly detected missing property"
    }
  end

  def test_detects_extra_property
    test_name = "Detects Extra Property"
    
    schema = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "schema_prop" => { "type" => "string", "required" => false }
      }
    }
    
    doc = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "schema_prop" => {
          "type" => "string",
          "description" => "Property from schema",
          "required" => false
        },
        "extra_prop" => {
          "type" => "integer",
          "description" => "Extra property not in schema",
          "required" => false
        }
      }
    }
    
    alignment_test = SchemaDocumentationAlignmentTest.new
    result = alignment_test.send(:validate_alignment, schema, doc)
    
    @test_results << {
      name: test_name,
      passed: !result, # Should fail validation (return false)
      details: result ? "Failed to detect extra property" : "Correctly detected extra property"
    }
  end

  def test_detects_type_mismatch
    test_name = "Detects Type Mismatch"
    
    schema = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "mismatch_prop" => { "type" => "integer", "required" => false }
      }
    }
    
    doc = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "mismatch_prop" => {
          "type" => "string", # Wrong type
          "description" => "Property with wrong type",
          "required" => false
        }
      }
    }
    
    alignment_test = SchemaDocumentationAlignmentTest.new
    result = alignment_test.send(:validate_alignment, schema, doc)
    
    @test_results << {
      name: test_name,
      passed: !result, # Should fail validation (return false)
      details: result ? "Failed to detect type mismatch" : "Correctly detected type mismatch"
    }
  end

  def test_accepts_perfect_alignment
    test_name = "Accepts Perfect Alignment"
    
    schema = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "perfect_prop" => { 
          "type" => "string", 
          "required" => false,
          "default" => "test"
        },
        "nested_prop" => {
          "type" => "object",
          "required" => true,
          "properties" => {
            "inner_prop" => { "type" => "boolean", "required" => false }
          }
        }
      }
    }
    
    doc = {
      "name" => "test-plugin",
      "plugin_type" => "processor",
      "properties" => {
        "perfect_prop" => {
          "type" => "string",
          "description" => "Perfectly aligned property",
          "required" => false,
          "default" => "test"
        },
        "nested_prop" => {
          "type" => "object",
          "description" => "Nested object property",
          "required" => true,
          "properties" => {
            "inner_prop" => {
              "type" => "boolean",
              "description" => "Inner boolean property",
              "required" => false
            }
          }
        }
      }
    }
    
    alignment_test = SchemaDocumentationAlignmentTest.new
    result = alignment_test.send(:validate_alignment, schema, doc)
    
    @test_results << {
      name: test_name,
      passed: result, # Should pass validation (return true)
      details: result ? "Correctly accepted perfect alignment" : "Failed to accept perfect alignment"
    }
  end

  def cleanup_temp_files
    @temp_files.each(&:unlink)
  end

  def report_results
    puts "\n📊 Validation Test Results:"
    puts "=" * 40
    
    passed_count = 0
    
    @test_results.each do |result|
      status = result[:passed] ? "✅ PASS" : "❌ FAIL"
      puts "#{status} #{result[:name]}"
      puts "    #{result[:details]}"
      passed_count += 1 if result[:passed]
    end
    
    puts "\nSummary: #{passed_count}/#{@test_results.length} validation tests passed"
    
    if passed_count == @test_results.length
      puts "🎉 Property test validation is working correctly!"
    else
      puts "❌ Property test validation has issues"
    end
  end
end

# Run validation tests if script is executed directly
if __FILE__ == $0
  test_suite = SchemaAlignmentValidationTest.new
  test_suite.run_validation_tests
end