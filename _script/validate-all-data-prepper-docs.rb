#!/usr/bin/env ruby

require_relative 'validate-data-prepper-docs'
require_relative 'validate-schema-consistency'

# Comprehensive validation script for Data Prepper documentation
class ComprehensiveDataPrepperValidator
  def initialize
    @results = {}
  end

  def validate_all
    puts "🔍 Running Comprehensive Data Prepper Documentation Validation"
    puts "=" * 70
    
    # Run basic documentation validation
    puts "\n1️⃣  Running Basic Documentation Validation..."
    basic_validator = DataPrepperDocValidator.new
    @results[:basic] = basic_validator.validate_all
    
    puts "\n" + "=" * 70
    
    # Run schema consistency validation
    puts "\n2️⃣  Running Schema Consistency Validation..."
    schema_validator = SchemaConsistencyValidator.new
    @results[:schema] = schema_validator.validate_all
    
    # Generate final report
    generate_final_report
    
    # Return overall success
    @results.values.all?
  end

  private

  def generate_final_report
    puts "\n" + "=" * 70
    puts "📋 Final Validation Report"
    puts "=" * 70
    
    basic_status = @results[:basic] ? "✅ PASS" : "❌ FAIL"
    schema_status = @results[:schema] ? "✅ PASS" : "❌ FAIL"
    
    puts "Basic Documentation Validation: #{basic_status}"
    puts "Schema Consistency Validation:  #{schema_status}"
    
    overall_status = @results.values.all? ? "✅ PASS" : "❌ FAIL"
    puts "\nOverall Status: #{overall_status}"
    
    if @results.values.all?
      puts "\n🎉 All Data Prepper documentation validation checks passed!"
      puts "   Your documentation is consistent and well-formed."
    else
      puts "\n⚠️  Some validation checks failed."
      puts "   Please review the errors above and fix the issues."
      
      unless @results[:basic]
        puts "   - Fix basic documentation structure and HTML issues"
      end
      
      unless @results[:schema]
        puts "   - Fix schema consistency issues between documentation and schemas"
      end
    end
    
    puts "\n" + "=" * 70
  end
end

# Run comprehensive validation if script is executed directly
if __FILE__ == $0
  validator = ComprehensiveDataPrepperValidator.new
  success = validator.validate_all
  exit(success ? 0 : 1)
end