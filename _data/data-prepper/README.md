# Data Prepper Plugin Documentation

This directory contains JSON documentation files for Data Prepper plugins. These files are used to generate configuration reference tables in the Jekyll documentation site.

## Directory Structure

```
_data/data-prepper/
├── processors/          # JSON docs for processor plugins
├── sources/            # JSON docs for source plugins  
├── sinks/              # JSON docs for sink plugins
├── buffers/            # JSON docs for buffer plugins
├── plugin-documentation-schema.json  # JSON schema for validation
└── README.md           # This file
```

## JSON Documentation Format

Each plugin documentation file should follow this structure:

```json
{
  "name": "date",
  "plugin_type": "processor|source|sink|buffer",
  "description": "Brief description of the plugin",
  "properties": {
    "property_name": {
      "type": "string|boolean|integer|number|array|object",
      "description": "HTML-formatted description",
      "required": false,
      "default": "default_value",
      "examples": [
        {
          "description": "Example description",
          "example": "example_value"
        }
      ]
    }
  }
}
```

### Required Fields

- `name`: Plugin identifier (must match directory placement)
- `plugin_type`: Must match the directory (processors → processor, sources → source, etc.)
- `properties`: Object containing configuration properties

For each property:
- `type`: Data type (string, boolean, integer, number, array, object)
- `description`: HTML-formatted description of the configuration option

### Optional Fields

- `description`: Brief description of what the plugin does
- `required`: Whether the property is required (defaults to false)
- `default`: Default value for the property
- `examples`: Array of example objects with description and example value
- `properties`: For nested object types, contains sub-properties

### HTML in Descriptions

Descriptions support HTML markup for rich formatting:

```json
{
  "description": "Specifies the <code>timeout</code> value. See <a href=\"/docs/link\">documentation</a> for details."
}
```

## Validation

Validate your JSON files using the validation script:

```bash
bundle exec ruby _script/validate-data-prepper-docs.rb
```

This will check:
- JSON syntax validity
- Schema compliance
- Plugin type consistency with directory structure
- Basic HTML validation in descriptions

## Usage in Markdown Files

To include generated configuration tables in Markdown files, use:

```liquid
{% include data-prepper-config-table.html plugin="date" %}
```

The plugin name should match the JSON filename (without .json extension).

## Migration from Existing Documentation

When migrating from existing Markdown tables:

1. Extract configuration options from the existing table
2. Create a JSON file in the appropriate directory
3. Replace the table section with the Liquid include tag
4. Validate the JSON file
5. Test the build to ensure the generated table matches the original

## Best Practices

- Use consistent naming conventions (snake_case for property names)
- Include examples for complex configuration options
- Keep descriptions concise but informative
- Use HTML markup sparingly and validate it
- Test generated output matches existing documentation format