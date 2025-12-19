# Design Document

## Overview

This system establishes a streamlined workflow for maintaining Data Prepper plugin documentation through automated schema synchronization. The solution implements a four-step process: (1) developers make changes in data-prepper, (2) a schema generation tool imports structural changes while preserving existing descriptions, (3) documentation writers enhance the imported schemas, and (4) changes are published through the existing Jekyll build process.

The design maintains clear separation of concerns where data-prepper owns configuration structure and documentation-website owns descriptive content, while ensuring both projects stay synchronized through automated tooling.

## Architecture

The system follows a synchronized workflow architecture with clear ownership boundaries:

1. **Data Prepper Project**: Authoritative source for configuration structure, types, property names, and default values
2. **Documentation Website Project**: Authoritative source for descriptions, examples, and documentation enhancements  
3. **Schema Generation Tool**: Automated synchronization that imports structural changes while preserving documentation content
4. **Jekyll Build Process**: Converts enhanced schemas to published documentation

The workflow consists of four main phases:

**Phase 1: Code Changes in Data Prepper**
- Developer modifies plugin configuration classes
- Data prepper's existing schema generation produces updated JSON schemas

**Phase 2: Schema Import Process**  
- Schema Generation Tool detects changes in data-prepper schemas
- Tool imports structural updates (properties, types, defaults) to documentation-website
- Existing descriptions and documentation enhancements are preserved
- New properties receive blank descriptions as signals for missing documentation

**Phase 3: Documentation Enhancement**
- Documentation writers identify properties with blank descriptions
- Writers add descriptions, examples, and additional metadata to schema files
- Enhanced schemas are committed to documentation-website

**Phase 4: Publication**
- Jekyll build process converts enhanced schemas to Markdown documentation
- Published documentation reflects both latest structure and documentation improvements

This creates a clear separation where data-prepper owns structural schema generation, documentation-website owns descriptive content, and they synchronize through automated tooling without tight coupling.

## Components and Interfaces

### Schema Generation Tool

The Schema Generation Tool is a Ruby script that synchronizes schema structure from data-prepper to documentation-website while preserving existing documentation content.

#### Core Functionality

**Schema Import Process:**
```ruby
# Pseudocode for schema import logic
def import_schema(data_prepper_schema, existing_doc_schema)
  merged_schema = {}
  
  # Import structural elements from data-prepper
  merged_schema['$schema'] = data_prepper_schema['$schema']
  merged_schema['$defs'] = import_definitions(data_prepper_schema['$defs'], existing_doc_schema['$defs'])
  merged_schema['properties'] = import_properties(data_prepper_schema['properties'], existing_doc_schema['properties'])
  
  # Preserve metadata from documentation-website
  merged_schema['name'] = data_prepper_schema['name']
  merged_schema['description'] = existing_doc_schema['description'] || ""
  merged_schema['documentation'] = data_prepper_schema['documentation']
  
  return merged_schema
end

def import_properties(source_props, existing_props)
  merged = {}
  
  source_props.each do |key, source_prop|
    merged[key] = {
      'type' => source_prop['type'],
      'default' => source_prop['default'],
      '$ref' => source_prop['$ref']
    }
    
    # Preserve existing description or leave blank
    if existing_props && existing_props[key]
      merged[key]['description'] = existing_props[key]['description']
      merged[key]['examples'] = existing_props[key]['examples']
    else
      merged[key]['description'] = ""  # Signal for missing documentation
    end
  end
  
  return merged
end
```

#### Description Preservation Rules

1. **Existing Property with Description**: Preserve the existing description exactly
2. **Existing Property without Description**: Keep blank description (already identified as needing work)
3. **New Property**: Add with blank description as signal for documentation writers
4. **Removed Property**: Delete from documentation schema (no longer relevant)
5. **Type Change**: Update type while preserving description

#### Change Reporting

The tool generates a report after each import:
```
Schema Import Report for 'date' processor:
- Added properties: 3 (need documentation)
- Updated properties: 2 (types changed, descriptions preserved)
- Removed properties: 1
- Properties needing documentation: 5 total
```

### JSON Schema with References Integration

The system leverages data-prepper's JSON Schema generation with `$defs` and `$ref` support for semantic type information.

#### Schema Structure from Data Prepper
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$defs": {
    "DateMatch": {
      "type": "object",
      "properties": {
        "key": { "type": "string" },
        "patterns": {
          "type": "array",
          "items": { "type": "string" }
        }
      }
    }
  },
  "properties": {
    "match": {
      "type": "array",
      "items": { "$ref": "#/$defs/DateMatch" }
    },
    "destination": {
      "type": "string",
      "default": "@timestamp"
    }
  }
}
```

#### Enhanced Schema in Documentation Website
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$defs": {
    "DateMatch": {
      "type": "object",
      "properties": {
        "key": { 
          "type": "string",
          "description": "The event key to match patterns against. Required if match is configured."
        },
        "patterns": {
          "type": "array",
          "items": { "type": "string" },
          "description": "List of possible timestamp patterns for the key value."
        }
      }
    }
  },
  "properties": {
    "match": {
      "type": "array",
      "items": { "$ref": "#/$defs/DateMatch" },
      "description": "List of key-pattern pairs to match against events."
    },
    "destination": {
      "type": "string",
      "default": "@timestamp",
      "description": "Field where the parsed timestamp will be stored."
    }
  }
}
```

### Jekyll Data Files and Liquid Templates

Jekyll can process JSON files directly using its built-in data file functionality (similar to the existing `_data/versions.json`):

- JSON documentation files will be placed in `_data/data-prepper/` directory structure
- Liquid templates will iterate over JSON data to generate Markdown tables  
- Existing Markdown files will use `{% include %}` tags to insert generated tables
- No custom Jekyll plugins required - uses standard Jekyll functionality alongside existing YAML files

### Directory Structure

JSON documentation files will be stored in Jekyll's `_data` directory to leverage native data file processing:

```
_data/
├── data-prepper/
│   ├── processors/
│   │   ├── grok.json              # JSON documentation for grok processor
│   │   ├── aggregate.json         # JSON documentation for aggregate processor
│   │   └── ...
│   ├── sources/
│   │   ├── http.json              # JSON documentation for http source
│   │   └── ...
│   └── sinks/
│       ├── opensearch.json        # JSON documentation for opensearch sink
│       └── ...
└── versions.json                  # Existing JSON file (shows Jekyll supports JSON)

_data-prepper/pipelines/configuration/
├── processors/
│   ├── grok.md                    # Existing Markdown (examples, metrics, etc.)
│   ├── aggregate.md               # Will include generated tables via Liquid
│   └── ...
```

## Data Models

### Documentation Integration with Schema References

The documentation system processes JSON schemas with references to extract semantic type information:

#### Reference Resolution Process
1. **Schema Parsing**: Parse the generated JSON schema with `$defs` and `$ref` properties
2. **Reference Resolution**: Resolve `$ref` pointers to extract the actual type definitions
3. **Type Name Extraction**: Use the clean type names from `$defs` keys (e.g., "DateMatch")
4. **Array Handling**: Handle arrays of references (`"items": {"$ref": "#/$defs/DateMatch"}`)
5. **Documentation Generation**: Generate tables with proper type names and links

#### Example Schema Processing
```json
{
  "$defs": {
    "DateMatch": { 
      "type": "object",
      "properties": { "key": {...}, "patterns": {...} }
    }
  },
  "properties": {
    "match": {
      "type": "array",
      "items": { "$ref": "#/$defs/DateMatch" }
    }
  }
}
```

Becomes:
- **Type Display**: "List of [DateMatch](#datematch)" (for array of references)
- **Link Target**: `#datematch` (lowercase type name)
- **Section Generation**: Separate table for DateMatch properties with anchor `id="datematch"`

#### Type Display Rules
1. **Direct Reference**: `{"$ref": "#/$defs/TypeName"}` → "[TypeName](#typename)"
2. **Array of References**: `{"type": "array", "items": {"$ref": "#/$defs/TypeName"}}` → "List of [TypeName](#typename)"
3. **Primitive Arrays**: `{"type": "array", "items": {"type": "string"}}` → "List of String"
4. **Primitive Types**: `{"type": "string"}` → "String"
5. **Generic Objects**: `{"type": "object"}` → "Object"

### Markdown Table Generation

The system will generate tables matching the current format:

```markdown
Option | Required | Type | Description
:--- | :--- |:--- | :---
`match` | No | Object | Specifies which keys should match specific patterns...
`target_key` | No | String | Specifies a parent-level key used to store all captures...
`break_on_match` | No | Boolean | Specifies whether to match all patterns...
```

For nested properties, separate tables will be generated following the existing pattern.

## Error Handling

### Validation Errors

- **Schema Validation**: JSON documentation files must conform to the defined schema
- **Required Field Validation**: Essential fields (name, type, description) must be present
- **HTML Validation**: HTML content in descriptions must be well-formed
- **Build Failure Handling**: Clear error messages indicating which files have issues

### Synchronization Errors

- **Missing Documentation**: When data-prepper generates schemas for plugins without corresponding JSON documentation
- **Orphaned Documentation**: When JSON documentation exists for plugins no longer in data-prepper
- **Structure Mismatches**: When property names or types don't align between projects

### Recovery Mechanisms

- **Graceful Degradation**: Fall back to existing Markdown tables if JSON processing fails
- **Partial Processing**: Continue build process even if some JSON files have errors
- **Error Reporting**: Detailed logs showing which files and properties have issues

## Testing Strategy

The testing approach will use both unit testing and property-based testing to ensure correctness across the documentation generation pipeline.

### Unit Testing

Unit tests will verify specific examples and integration points:

- JSON schema validation for documentation files
- Markdown table generation from JSON input
- HTML content preservation and sanitization
- File system operations and directory structure handling
- Jekyll plugin integration and hook points

### Property-Based Testing

Property-based tests will verify universal properties across all inputs using a suitable Ruby testing library (such as Rantly or PropCheck):

- **Minimum 100 iterations** per property test to ensure comprehensive coverage
- Each test will be tagged with comments referencing the corresponding correctness property

The testing framework will be **Rantly** for property-based testing in Ruby, integrated with the existing Jekyll test suite.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Schema import preserves documentation content
*For any* existing schema file with descriptions and a new schema with structural changes, importing the structural changes should preserve all existing descriptions, examples, and metadata while updating only the structural elements
**Validates: Requirements 1.2, 2.2, 3.1, 6.3**

### Property 2: New properties receive blank description signals  
*For any* property added in data-prepper that doesn't exist in the documentation schema, the import process should add that property with a blank description as a signal for missing documentation
**Validates: Requirements 1.3, 2.1, 3.2**

### Property 3: Property removal synchronization
*For any* property removed from data-prepper schema, that property should be removed from the documentation schema regardless of existing documentation content
**Validates: Requirements 1.4, 3.4**

### Property 4: Structural updates preserve content
*For any* property that exists in both schemas but has structural changes (type, default value), the import should update the structural information while preserving the existing description and examples
**Validates: Requirements 1.5, 3.3**

### Property 5: Change detection and reporting
*For any* schema import operation, the tool should accurately detect and report all structural changes (additions, removals, modifications) and identify properties needing documentation
**Validates: Requirements 1.1, 3.5**

### Property 6: Missing documentation identification
*For any* schema file with blank descriptions, the system should clearly identify and report which properties need documentation attention
**Validates: Requirements 2.3, 4.2**

### Property 7: Enhanced schema documentation generation
*For any* schema file with complete descriptions and examples, the build process should generate comprehensive documentation tables containing all property information
**Validates: Requirements 2.5, 4.1, 4.3, 4.4**

### Property 8: Migration content preservation
*For any* existing documentation being migrated to schema format, all configuration information, descriptions, examples, and metadata should be preserved without loss
**Validates: Requirements 5.1, 5.2, 5.3**

### Property 9: Migration output equivalence
*For any* migrated documentation, the generated output should be functionally equivalent to the original documentation
**Validates: Requirements 5.5**

### Property 10: Directory organization consistency
*For any* schema file created during migration, it should be placed in the correct directory structure based on plugin type (sources/, processors/, sinks/, buffers/)
**Validates: Requirements 5.4**

### Property 11: Blank description preservation
*For any* property without existing documentation, the import process should leave description fields blank rather than generating placeholder text
**Validates: Requirements 6.4**

### Property 12: Validation reporting accuracy
*For any* schema structural changes, the validation system should accurately identify which documentation needs updates to match the new structure
**Validates: Requirements 6.5**

### Property 13: Build error reporting clarity
*For any* invalid schema file or build error, the system should provide clear error messages indicating the specific file and nature of the issue
**Validates: Requirements 4.5**