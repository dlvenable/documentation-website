# frozen_string_literal: true

require 'json'
require 'yaml'

module DataPrepperValidator
  class Generator < Jekyll::Generator
    priority :high

    def generate(site)
      @site = site
      @errors = []
      @warnings = []

      validate_data_prepper_files
      report_validation_results
    end

    private

    def validate_data_prepper_files
      validate_json_files
      validate_template_references
    end

    def validate_json_files
      data_prepper_path = File.join(@site.source, '_data', 'data-prepper')
      return unless Dir.exist?(data_prepper_path)

      %w[processors sources sinks buffers].each do |plugin_type|
        type_path = File.join(data_prepper_path, plugin_type)
        next unless Dir.exist?(type_path)

        Dir.glob(File.join(type_path, '*.json')).each do |json_file|
          validate_json_file(json_file, plugin_type)
        end
      end
    end

    def validate_json_file(file_path, plugin_type)
      relative_path = file_path.sub(@site.source + '/', '')
      
      begin
        content = File.read(file_path)
        data = JSON.parse(content)
        
        validate_json_structure(data, relative_path)
        
      rescue JSON::ParserError => e
        @errors << "Invalid JSON in #{relative_path}: #{e.message}"
      rescue => e
        @errors << "Error reading #{relative_path}: #{e.message}"
      end
    end

    def validate_json_structure(data, file_path)
      # Check if this is a JSON Schema format (has $schema field)
      if data.key?('$schema')
        validate_json_schema_structure(data, file_path)
      else
        validate_legacy_structure(data, file_path)
      end
    end

    def validate_json_schema_structure(data, file_path)
      # For JSON Schema format, validate required top-level fields
      required_fields = %w[name properties]
      required_fields.each do |field|
        unless data.key?(field)
          @errors << "Missing required field '#{field}' in #{file_path}"
        end
      end

      # For JSON Schema files, we're much more lenient
      # We just validate that properties is a hash if it exists
      if data['properties'] && !data['properties'].is_a?(Hash)
        @errors << "Field 'properties' must be an object in #{file_path}"
      end

      # No detailed property validation for JSON Schema files
      # The schema itself is the validation
    end

    def validate_legacy_structure(data, file_path)
      # Validate required top-level fields for legacy format
      required_fields = %w[name description properties]
      required_fields.each do |field|
        unless data.key?(field)
          @errors << "Missing required field '#{field}' in #{file_path}"
        end
      end

      # Validate properties structure
      if data['properties']
        unless data['properties'].is_a?(Hash)
          @errors << "Field 'properties' must be an object in #{file_path}"
          return
        end

        data['properties'].each do |prop_name, prop_config|
          validate_property_structure(prop_config, prop_name, file_path)
        end
      end
    end



    def validate_property_structure(prop_config, prop_name, file_path)
      unless prop_config.is_a?(Hash)
        @errors << "Property '#{prop_name}' must be an object in #{file_path}"
        return
      end

      # Check if this is a JSON Schema reference
      if prop_config.key?('$ref')
        # For $ref properties, we don't require 'type' field or 'description'
        return
      end

      # Check for anyOf structure (JSON Schema)
      if prop_config.key?('anyOf')
        # anyOf structure - validate that it's an array
        unless prop_config['anyOf'].is_a?(Array)
          @errors << "Property '#{prop_name}' anyOf must be an array in #{file_path}"
        end
        return
      end

      # For legacy format, require type and description
      # For JSON Schema format, these are optional
      unless prop_config.key?('type')
        @errors << "Property '#{prop_name}' missing required 'type' field in #{file_path}"
      end

      unless prop_config.key?('description')
        @errors << "Property '#{prop_name}' missing required 'description' field in #{file_path}"
      end

      # Validate type values
      valid_types = %w[string integer number boolean array object]
      if prop_config['type'] && !valid_types.include?(prop_config['type'])
        @warnings << "Property '#{prop_name}' has unknown type '#{prop_config['type']}' in #{file_path}"
      end

      # Validate nested properties for object types
      if prop_config['type'] == 'object' && prop_config['properties']
        prop_config['properties'].each do |nested_name, nested_config|
          validate_property_structure(nested_config, "#{prop_name}.#{nested_name}", file_path)
        end
      end
    end

    def validate_template_references
      # Find all Markdown files that use the data-prepper-config-table template
      markdown_files = Dir.glob(File.join(@site.source, '**', '*.md'))
      
      markdown_files.each do |md_file|
        validate_template_references_in_file(md_file)
      end
    end

    def validate_template_references_in_file(file_path)
      relative_path = file_path.sub(@site.source + '/', '')
      
      begin
        content = File.read(file_path)
        
        # Find all data-prepper-config-table includes
        includes = content.scan(/\{\%\s*include\s+data-prepper-config-table\.html\s+([^%]+)\s*\%\}/)
        
        includes.each do |include_params|
          validate_template_include(include_params[0], relative_path)
        end
        
      rescue => e
        @warnings << "Error reading #{relative_path}: #{e.message}"
      end
    end

    def validate_template_include(params_string, file_path)
      # Parse include parameters
      params = {}
      params_string.scan(/(\w+)=["']([^"']+)["']/).each do |key, value|
        params[key] = value
      end

      plugin_name = params['plugin']
      plugin_type = params['plugin_type'] || 'processor'

      unless plugin_name
        @errors << "Missing 'plugin' parameter in data-prepper-config-table include in #{file_path}"
        return
      end

      # Check if corresponding JSON file exists
      json_path = File.join(@site.source, '_data', 'data-prepper', "#{plugin_type}s", "#{plugin_name}.json")
      
      unless File.exist?(json_path)
        @errors << "Referenced JSON file not found: _data/data-prepper/#{plugin_type}s/#{plugin_name}.json (referenced in #{file_path})"
      end
    end

    def report_validation_results
      if @errors.any?
        Jekyll.logger.error "Data Prepper Validation", "Found #{@errors.size} error(s):"
        @errors.each { |error| Jekyll.logger.error "", "  - #{error}" }
        
        if Jekyll.env == 'production'
          raise Jekyll::Errors::FatalException, "Data Prepper validation failed with #{@errors.size} error(s)"
        end
      end

      if @warnings.any?
        Jekyll.logger.warn "Data Prepper Validation", "Found #{@warnings.size} warning(s):"
        @warnings.each { |warning| Jekyll.logger.warn "", "  - #{warning}" }
      end

      if @errors.empty? && @warnings.empty?
        Jekyll.logger.info "Data Prepper Validation", "All validation checks passed"
      end
    end
  end
end