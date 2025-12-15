#!/usr/bin/env ruby

require 'json'

# HTML content validation for Data Prepper documentation
class HTMLContentValidator
  ALLOWED_TAGS = %w[code em strong a ul ol li pre br].freeze
  SELF_CLOSING_TAGS = %w[br].freeze

  def initialize
    @errors = []
    @warnings = []
  end

  def validate_json_file(file_path)
    return false unless File.exist?(file_path)
    
    begin
      doc = JSON.parse(File.read(file_path))
      validate_html_in_properties(file_path, doc['properties'], [])
      @errors.empty?
    rescue JSON::ParserError => e
      @errors << "#{file_path}: Invalid JSON - #{e.message}"
      false
    rescue => e
      @errors << "#{file_path}: Validation error - #{e.message}"
      false
    end
  end

  def validate_all_files
    puts "🔍 Validating HTML content in Data Prepper documentation..."
    
    base_path = '_data/data-prepper'
    plugin_types = %w[processors sources sinks buffers]
    
    plugin_types.each do |plugin_type|
      docs_dir = File.join(base_path, plugin_type)
      next unless Dir.exist?(docs_dir)

      Dir.glob(File.join(docs_dir, '*.json')).each do |file_path|
        validate_json_file(file_path)
      end
    end

    report_results
    @errors.empty?
  end

  private

  def validate_html_in_properties(file_path, properties, path)
    return unless properties.is_a?(Hash)

    properties.each do |prop_name, prop_config|
      current_path = path + [prop_name]
      
      if prop_config['description']
        validate_html_string(file_path, prop_config['description'], current_path + ['description'])
      end
      
      # Validate examples
      if prop_config['examples'].is_a?(Array)
        prop_config['examples'].each_with_index do |example, idx|
          if example['description']
            validate_html_string(file_path, example['description'], current_path + ['examples', idx, 'description'])
          end
        end
      end
      
      # Recursively validate nested properties
      if prop_config['properties']
        validate_html_in_properties(file_path, prop_config['properties'], current_path + ['properties'])
      end
    end
  end

  def validate_html_string(file_path, html_string, path)
    # Extract HTML tags
    tags = html_string.scan(/<\/?([a-zA-Z][a-zA-Z0-9]*)[^>]*>/i)
    
    # Check for disallowed tags
    tags.each do |tag_match|
      tag = tag_match[0].downcase
      unless ALLOWED_TAGS.include?(tag)
        @warnings << "#{file_path} at #{path.join('.')}: Potentially unsafe HTML tag '#{tag}'"
      end
    end
    
    # Basic HTML structure validation
    validate_html_structure(file_path, html_string, path)
    
    # Check for common HTML issues
    validate_html_entities(file_path, html_string, path)
  end

  def validate_html_structure(file_path, html_string, path)
    tag_stack = []
    
    # Find all HTML tags
    html_string.scan(/<(\/?[a-zA-Z][a-zA-Z0-9]*)[^>]*>/i) do |match|
      tag_with_slash = match[0].downcase
      
      if tag_with_slash.start_with?('/')
        # Closing tag
        tag = tag_with_slash[1..-1]
        if tag_stack.last == tag
          tag_stack.pop
        else
          @errors << "#{file_path} at #{path.join('.')}: Mismatched closing tag '</#{tag}>'"
        end
      elsif SELF_CLOSING_TAGS.include?(tag_with_slash)
        # Self-closing tag, no need to track
        next
      else
        # Opening tag
        tag_stack.push(tag_with_slash)
      end
    end
    
    unless tag_stack.empty?
      @errors << "#{file_path} at #{path.join('.')}: Unclosed HTML tags: #{tag_stack.join(', ')}"
    end
  end

  def validate_html_entities(file_path, html_string, path)
    # Check for unescaped characters that should be entities
    if html_string.include?('<') && !html_string.match?(/<[a-zA-Z]/)
      @warnings << "#{file_path} at #{path.join('.')}: Possible unescaped '<' character"
    end
    
    # Check for malformed entities (ampersand followed by word characters but not properly terminated)
    # Look for & followed by letters/numbers that don't end with ;
    if html_string.match?(/&[a-zA-Z0-9]+(?![a-zA-Z0-9;])/)
      @warnings << "#{file_path} at #{path.join('.')}: Possible malformed HTML entity (missing semicolon)"
    end
  end

  def report_results
    if @errors.empty? && @warnings.empty?
      puts "✅ All HTML content is valid!"
    else
      unless @errors.empty?
        puts "\n❌ HTML Validation Errors:"
        @errors.each { |error| puts "  #{error}" }
      end
      
      unless @warnings.empty?
        puts "\n⚠️  HTML Validation Warnings:"
        @warnings.each { |warning| puts "  #{warning}" }
      end
      
      puts "\nSummary: #{@errors.length} errors, #{@warnings.length} warnings"
    end
  end
end

# Run validation if script is executed directly
if __FILE__ == $0
  validator = HTMLContentValidator.new
  success = validator.validate_all_files
  exit(success ? 0 : 1)
end