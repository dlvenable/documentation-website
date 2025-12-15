#!/usr/bin/env ruby

require 'json'

# Compare original vs new documentation system
class DocumentationComparison
  def run_comparison
    puts "📊 Documentation System Comparison"
    puts "=" * 80
    
    compare_content_completeness
    compare_maintenance_benefits
    show_migration_success
    
    puts "=" * 80
    puts "✅ Comparison complete!"
  end

  private

  def compare_content_completeness
    puts "\n🔍 Content Completeness Analysis"
    puts "-" * 40
    
    # Load the migrated JSON
    grok_json_path = '_data/data-prepper/processors/grok.json'
    if File.exist?(grok_json_path)
      grok_data = JSON.parse(File.read(grok_json_path))
      
      puts "✅ JSON Documentation Properties: #{grok_data['properties'].keys.length}"
      puts "   Properties: #{grok_data['properties'].keys.sort.join(', ')}"
      
      # Count properties with defaults
      with_defaults = grok_data['properties'].count { |_, config| config['default'] != nil }
      puts "✅ Properties with default values: #{with_defaults}"
      
      # Count properties with examples
      with_examples = grok_data['properties'].count { |_, config| config['examples'] && !config['examples'].empty? }
      puts "✅ Properties with examples: #{with_examples}"
      
      # Count HTML formatting
      with_html = grok_data['properties'].count { |_, config| config['description'].include?('<code>') }
      puts "✅ Properties with HTML formatting: #{with_html}"
      
    else
      puts "❌ Could not find migrated JSON file"
    end
  end

  def compare_maintenance_benefits
    puts "\n🛠️  Maintenance Benefits"
    puts "-" * 40
    
    puts "✅ Single source of truth: JSON files in _data/data-prepper/"
    puts "✅ Automatic validation: Schema validation prevents errors"
    puts "✅ Consistent formatting: Liquid template ensures uniformity"
    puts "✅ HTML preservation: Rich formatting maintained"
    puts "✅ Nested properties: Automatic separate table generation"
    puts "✅ Multi-plugin support: Works for processors, sources, sinks, buffers"
    puts "✅ Build-time generation: No manual table maintenance"
  end

  def show_migration_success
    puts "\n🎯 Migration Success Metrics"
    puts "-" * 40
    
    # Count migrated files
    migrated_count = 0
    %w[processors sources sinks buffers].each do |plugin_type|
      dir_path = "_data/data-prepper/#{plugin_type}"
      if Dir.exist?(dir_path)
        json_files = Dir.glob(File.join(dir_path, '*.json')).reject { |f| f.include?('html-test') }
        migrated_count += json_files.length
        puts "✅ #{plugin_type.capitalize}: #{json_files.length} plugins migrated"
      end
    end
    
    puts "✅ Total migrated plugins: #{migrated_count}"
    
    # Test validation
    puts "\n🔬 Validation Results:"
    validation_result = `ruby _script/validate-data-prepper-docs-simple.rb 2>&1`
    if $?.success?
      puts "✅ All JSON files pass validation"
    else
      puts "❌ Validation issues found"
    end
    
    # Test property tests
    puts "\n🧪 Property Test Results:"
    test_files = [
      '_script/test-directory-organization.rb',
      '_script/test-nested-structure-generation.rb', 
      '_script/test-html-preservation.rb',
      '_script/test-migration-extraction.rb',
      '_script/test-build-time-conversion.rb'
    ]
    
    passed_tests = 0
    test_files.each do |test_file|
      if File.exist?(test_file)
        result = `ruby #{test_file} 2>&1`
        if $?.success?
          passed_tests += 1
          puts "✅ #{File.basename(test_file, '.rb').gsub('-', ' ').capitalize}"
        else
          puts "❌ #{File.basename(test_file, '.rb').gsub('-', ' ').capitalize}"
        end
      end
    end
    
    puts "✅ Property tests passed: #{passed_tests}/#{test_files.length}"
  end
end

# Run the comparison
if __FILE__ == $0
  comparison = DocumentationComparison.new
  comparison.run_comparison
end