#!/usr/bin/env ruby

require 'json'
require 'fileutils'

# Automated migration script for Data Prepper processor documentation
# Converts Markdown configuration tables to JSON format

class ProcessorDocumentationMigrator
  PROCESSORS_DIR = '_data-prepper/pipelines/configuration/processors'
  JSON_OUTPUT_DIR = '_data/data-prepper/processors'
  
  def initialize
    @migrated_count = 0
    @errors = []
    @skipped_count = 0
  end

  def migrate_all_processors
    puts "🔄 Starting migration of processor documentation..."
    puts "   Source: #{PROCESSORS_DIR}"
    puts "   Target: #{JSON_OUTPUT_DIR}"
    
    # Ensure output directory exists
    FileUtils.mkdir_p(JSON_OUTPUT_DIR)
    
    # Get all processor markdown files
    processor_files = Dir.glob(File.join(PROCESSORS_DIR, '*.md'))
    processor_files.reject! { |file| File.basename(file) == 'processors.md' } # Skip index file
    
    puts "   Found #{processor_files.length} processor files to migrate"
    
    processor_files.each do |file_path|
      migrate_processor_file(file_path)
    end
    
    report_results
    @errors.empty?
  end

  def migrate_specific_processors(processor_names)
    puts "🔄 Migrating specific processors: #{processor_names.join(', ')}"
    
    # Ensure output directory exists
    FileUtils.mkdir_p(JSON_OUTPUT_DIR)
    
    processor_names.each do |processor_name|
      file_path = File.join(PROCESSORS_DIR, "#{processor_name}.md")
      
      if File.exist?(file_path)
        migrate_processor_file(file_path)
      else
        @errors << "Processor file not found: #{file_path}"
      end
    end
    
    report_results
    @errors.empty?
  end

  private

  def migrate_processor_file(file_path)
    processor_name = File.basename(file_path, '.md')
    
    begin
      puts "   Processing: #{processor_name}"
      
      content = File.read(file_path)
      
      # Extract configuration table
      config_table = extract_configuration_table(content)
      
      if config_table.nil?
        @skipped_count += 1
        puts "     ⚠️  No configuration table found, skipping"
        return
      end
      
      # Parse table into JSON structure
      json_doc = parse_table_to_json(config_table, processor_name)
      
      # Write JSON file
      json_file_path = File.join(JSON_OUTPUT_DIR, "#{processor_name}.json")
      File.write(json_file_path, JSON.pretty_generate(json_doc))
      
      @migrated_count += 1
      puts "     ✅ Migrated to #{json_file_path}"
      
    rescue => e
      @errors << "Failed to migrate #{processor_name}: #{e.message}"
      puts "     ❌ Error: #{e.message}"
    end
  end

  def extract_configuration_table(content)
    # Look for configuration table section
    # Pattern: "## Configuration" followed by table
    config_section_match = content.match(/## Configuration.*?\n(.*?)(?=\n##|\n---|\z)/m)
    
    return nil unless config_section_match
    
    config_section = config_section_match[1]
    
    # Find the table within the configuration section
    # Look for table header pattern: Option | Required | Type | Description
    # Handle both formats: with and without leading/trailing pipes
    table_patterns = [
      # Format 1: | Option | Required | Type | Description |
      /\|\s*Option\s*\|\s*Required\s*\|\s*Type\s*\|\s*Description\s*\|.*?\n\|\s*:?---.*?\n(.*?)(?=\n\n|\n###|\n##|\z)/m,
      # Format 2: Option | Required | Type | Description
      /Option\s*\|\s*Required\s*\|\s*Type\s*\|\s*Description.*?\n:?---.*?\n(.*?)(?=\n\n|\n###|\n##|\z)/m
    ]
    
    table_match = nil
    table_patterns.each do |pattern|
      table_match = config_section.match(pattern)
      break if table_match
    end
    
    return nil unless table_match
    
    # Find the start of the table header
    header_patterns = [
      /\|\s*Option\s*\|\s*Required\s*\|\s*Type\s*\|\s*Description\s*\|/,
      /Option\s*\|\s*Required\s*\|\s*Type\s*\|\s*Description/
    ]
    
    header_start = nil
    header_patterns.each do |pattern|
      match_pos = config_section.index(pattern)
      if match_pos
        header_start = match_pos
        break
      end
    end
    
    return nil unless header_start
    
    # Extract from header to end of table
    remaining_content = config_section[header_start..-1]
    
    # Find the full table including header and data
    full_table_patterns = [
      /\|\s*Option.*?\n\|\s*:?---.*?\n.*?(?=\n\n|\n###|\n##|\z)/m,
      /Option.*?\n:?---.*?\n.*?(?=\n\n|\n###|\n##|\z)/m
    ]
    
    full_table_patterns.each do |pattern|
      full_table_match = remaining_content.match(pattern)
      return full_table_match[0] if full_table_match
    end
    
    nil
  end

  def parse_table_to_json(table_content, processor_name)
    lines = table_content.split("\n").map(&:strip).reject(&:empty?)
    
    # Skip header and separator lines
    data_lines = lines[2..-1] || []
    
    properties = {}
    
    data_lines.each do |line|
      next if line.match?(/^:?---/) # Skip any separator lines
      next if line.match?(/^\|?\s*:?---/) # Skip separator lines with pipes
      
      # Parse table row: Option | Required | Type | Description
      # Handle both formats: with and without leading/trailing pipes
      columns = line.split('|').map(&:strip)
      
      # Remove empty first/last columns if they exist (from leading/trailing pipes)
      columns = columns[1..-1] if columns.first&.empty?
      columns = columns[0..-2] if columns.last&.empty?
      
      next if columns.length < 4
      
      option = columns[0].gsub(/`/, '').strip # Remove backticks
      required = columns[1].strip
      type = columns[2].strip
      description = columns[3].strip
      
      next if option.empty? || option.downcase == 'option'
      
      # Convert required field
      required_bool = case required.downcase
                     when 'yes', 'true', 'required' then true
                     when 'no', 'false', 'optional' then false
                     when 'conditionally' then false # Treat conditionally as optional for now
                     else false
                     end
      
      # Convert type field
      type_normalized = normalize_type(type)
      
      # Clean up description (remove extra formatting)
      description_clean = clean_description(description)
      
      # Smart type detection based on description
      if type_normalized == 'string' && description_clean.match?(/list of|array of|tags/i)
        type_normalized = 'array'
      end
      
      properties[option] = {
        'type' => type_normalized,
        'description' => description_clean,
        'required' => required_bool
      }
    end
    
    # Create the JSON document structure
    {
      'name' => processor_name,
      'plugin_type' => 'processor',
      'properties' => properties
    }
  end

  def normalize_type(type_str)
    # Normalize type names to match our JSON schema
    normalized = type_str.downcase.gsub(/[^a-z]/, '')
    
    case normalized
    when 'string', 'str' then 'string'
    when 'boolean', 'bool' then 'boolean'
    when 'integer', 'int' then 'integer'
    when 'number', 'double', 'float' then 'number'
    when 'list', 'array' then 'array'
    when 'object', 'map', 'aggregateaction', 'match' then 'object'
    else
      # Check if it's a complex type that should be object
      if type_str.match?(/[A-Z][a-z]+/) # CamelCase suggests object type
        'object'
      else
        'string' # Default to string for unknown types
      end
    end
  end

  def clean_description(description)
    # Clean up description text
    description = description.strip
    
    # Remove leading/trailing pipes if present
    description = description.gsub(/^\||\|$/, '').strip
    
    # Convert markdown code spans to HTML
    description = description.gsub(/`([^`]+)`/, '<code>\1</code>')
    
    # Convert markdown links to HTML (basic conversion)
    description = description.gsub(/\[([^\]]+)\]\(([^)]+)\)/, '<a href="\2">\1</a>')
    
    # Convert markdown emphasis to HTML
    description = description.gsub(/\*\*([^*]+)\*\*/, '<strong>\1</strong>')
    description = description.gsub(/\*([^*]+)\*/, '<em>\1</em>')
    
    # Handle line breaks and clean up whitespace
    description = description.gsub(/\s+/, ' ').strip
    
    description
  end

  def report_results
    puts "\n📊 Migration Results:"
    puts "   Successfully migrated: #{@migrated_count} processors"
    puts "   Skipped (no config table): #{@skipped_count} processors"
    puts "   Errors: #{@errors.length}"
    
    if @errors.any?
      puts "\n❌ Errors encountered:"
      @errors.each { |error| puts "   #{error}" }
    else
      puts "\n✅ Migration completed successfully!"
    end
  end
end

# Command line interface
if __FILE__ == $0
  migrator = ProcessorDocumentationMigrator.new
  
  if ARGV.empty?
    # Migrate all processors
    success = migrator.migrate_all_processors
  else
    # Migrate specific processors
    success = migrator.migrate_specific_processors(ARGV)
  end
  
  exit(success ? 0 : 1)
end