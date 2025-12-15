# Design Document

## Overview

This system extends the existing data-prepper schema generation process to integrate with structured JSON documentation from the documentation-website project. The design maintains backward compatibility while adding optional documentation merging capabilities and validation mechanisms to ensure consistency between schema structure and documentation content.

The system operates on the principle of graceful degradation - it works perfectly without documentation integration, but provides enhanced schemas with descriptions when documentation is available.

## Architecture

The enhanced schema generation system follows a layered architecture:

1. **Core Schema Generation Layer**: Existing functionality that generates structural schemas from Java configuration classes
2. **Documentation Integration Layer**: New functionality that reads and merges documentation JSON files
3. **Validation Layer**: New functionality that detects mismatches between schema structure and documentation
4. **Configuration Layer**: New functionality that manages integration settings and fallback behavior

**Enhanced Schema Generation Flow:**
- Plugin Configuration Classes → Core Schema Generator → Structural Schema
- Documentation JSON Files (optional) → Documentation Reader → Documentation Data
- Structural Schema + Documentation Data → Schema Merger → Complete Schema (temporary)
- Complete Schema → Validation Engine → Validation Reports
- Configuration Settings → Integration Controller → Controls entire flow

This creates a system where the core schema generation remains unchanged, but can be enhanced with documentation when available.

## Components and Interfaces

### Enhanced Schema Generator

The existing schema generator will be extended with optional documentation integration:

```java
public class EnhancedSchemaGenerator {
    private final CoreSchemaGenerator coreGenerator;
    private final DocumentationReader documentationReader;
    private final SchemaMerger schemaMerger;
    private final SchemaValidator schemaValidator;
    private final IntegrationConfig config;
    
    public JsonSchema generateSchema(Class<?> configClass) {
        // Generate core structural schema (existing functionality)
        JsonSchema structuralSchema = coreGenerator.generateStructuralSchema(configClass);
        
        if (!config.isDocumentationIntegrationEnabled()) {
            return structuralSchema;
        }
        
        // Attempt to read documentation (new functionality)
        Optional<DocumentationData> documentation = 
            documentationReader.readDocumentation(configClass);
            
        if (documentation.isEmpty()) {
            return structuralSchema;
        }
        
        // Merge and validate (new functionality)
        JsonSchema mergedSchema = schemaMerger.merge(structuralSchema, documentation.get());
        schemaValidator.validate(mergedSchema, structuralSchema);
        
        return mergedSchema;
    }
}
```

### Documentation Reader

Reads and parses JSON documentation files from the documentation-website project:

```java
public class DocumentationReader {
    private final Path documentationProjectPath;
    private final ObjectMapper objectMapper;
    
    public Optional<DocumentationData> readDocumentation(Class<?> configClass) {
        String pluginName = extractPluginName(configClass);
        String pluginType = extractPluginType(configClass);
        
        Path documentationFile = documentationProjectPath
            .resolve("_data/data-prepper")
            .resolve(pluginType + "s")  // processors, sources, sinks, buffers
            .resolve(pluginName + ".json");
            
        if (!Files.exists(documentationFile)) {
            return Optional.empty();
        }
        
        try {
            return Optional.of(objectMapper.readValue(documentationFile.toFile(), DocumentationData.class));
        } catch (IOException e) {
            log.warn("Failed to read documentation for {}: {}", pluginName, e.getMessage());
            return Optional.empty();
        }
    }
}
```

### Schema Merger

Combines structural schemas with documentation data:

```java
public class SchemaMerger {
    public JsonSchema merge(JsonSchema structuralSchema, DocumentationData documentation) {
        JsonSchema.Builder mergedBuilder = JsonSchema.builder()
            .from(structuralSchema);  // Copy all structural information
            
        // Add descriptions to properties
        for (Map.Entry<String, PropertyDocumentation> entry : documentation.getProperties().entrySet()) {
            String propertyName = entry.getKey();
            PropertyDocumentation propDoc = entry.getValue();
            
            if (structuralSchema.hasProperty(propertyName)) {
                mergedBuilder.addPropertyDescription(propertyName, propDoc.getDescription());
                if (propDoc.getDefault() != null) {
                    mergedBuilder.addPropertyDefault(propertyName, propDoc.getDefault());
                }
            }
        }
        
        return mergedBuilder.build();
    }
}
```

### Integration Configuration

Manages settings for documentation integration:

```java
@ConfigurationProperties("data-prepper.schema.documentation")
public class IntegrationConfig {
    private boolean enabled = true;
    private String documentationProjectPath = "../documentation-website";
    private boolean failOnValidationErrors = false;
    private boolean logValidationWarnings = true;
    
    // getters and setters
}
```

## Data Models

### Documentation Data Structure

The expected JSON structure from documentation-website:

```java
public class DocumentationData {
    private String name;
    private String pluginType;
    private Map<String, PropertyDocumentation> properties;
    
    // getters and setters
}

public class PropertyDocumentation {
    private String type;
    private String description;
    private boolean required;
    private Object defaultValue;
    private Map<String, PropertyDocumentation> properties; // for nested objects
    
    // getters and setters
}
```

### Validation Report Structure

```java
public class ValidationReport {
    private String pluginName;
    private List<ValidationIssue> issues;
    private ValidationStatus status;
    
    public enum ValidationStatus {
        VALID, WARNING, ERROR
    }
}

public class ValidationIssue {
    private IssueType type;
    private String propertyPath;
    private String message;
    private String suggestion;
    
    public enum IssueType {
        MISSING_DOCUMENTATION,
        OBSOLETE_DOCUMENTATION,
        TYPE_MISMATCH,
        INVALID_FORMAT
    }
}
```

## Error Handling

### Documentation Unavailability

- **Missing Documentation Project**: Continue with structural schemas only
- **Missing Documentation Files**: Generate schemas without descriptions for affected plugins
- **Invalid JSON Format**: Log warnings and fall back to structural schemas
- **Network/IO Issues**: Graceful degradation with appropriate logging

### Validation Errors

- **Property Mismatches**: Generate detailed reports but continue build process
- **Type Conflicts**: Log warnings and prefer structural schema types
- **Format Violations**: Provide specific error messages with suggested fixes

### Build Integration Errors

- **Configuration Issues**: Clear error messages about invalid paths or settings
- **Permission Problems**: Informative messages about file access issues
- **Version Conflicts**: Compatibility checks with clear upgrade guidance

## Testing Strategy

The testing approach will use both unit testing and property-based testing to ensure correctness across the schema integration pipeline.

### Unit Testing

Unit tests will verify specific examples and integration points:

- Schema generation with and without documentation
- Documentation reading and parsing from various file formats
- Schema merging logic with different documentation structures
- Validation reporting for various mismatch scenarios
- Configuration handling and fallback behavior

### Property-Based Testing

Property-based tests will verify universal properties across all inputs using a suitable Java testing library (such as jqwik or QuickTheories):

- **Minimum 100 iterations** per property test to ensure comprehensive coverage
- Each test will be tagged with comments referencing the corresponding correctness property

The testing framework will be **jqwik** for property-based testing in Java, integrated with the existing test suite.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Schema generation independence
*For any* plugin configuration class, the schema generator should produce valid schemas regardless of documentation availability
**Validates: Requirements 1.1, 1.4, 4.1**

### Property 2: Structural schema preservation
*For any* plugin configuration class, the structural information (property names, types, required fields) should be identical whether documentation is merged or not
**Validates: Requirements 5.1, 5.2, 5.3**

### Property 3: Documentation merge completeness
*For any* valid documentation JSON and corresponding structural schema, all documented properties that exist in the schema should have their descriptions included in the merged result
**Validates: Requirements 2.1, 2.3**

### Property 4: Build-time merge non-persistence
*For any* schema generation process with documentation merging enabled, no merged schemas should be written to source control or permanent storage
**Validates: Requirements 2.4, 2.5**

### Property 5: Validation completeness
*For any* structural schema and documentation pair, the validation process should identify all properties that exist in one but not the other
**Validates: Requirements 3.1, 3.2, 3.3**

### Property 6: Configuration fallback consistency
*For any* configuration state (enabled/disabled, available/unavailable documentation), the system should behave predictably and maintain backward compatibility
**Validates: Requirements 4.2, 4.4, 5.4**

### Property 7: Error reporting clarity
*For any* validation error or integration failure, the system should provide specific, actionable error messages that identify the exact issue and suggest solutions
**Validates: Requirements 3.3, 3.5, 6.3**

### Property 8: Interface contract validation
*For any* documentation JSON file, the system should validate that it conforms to the expected structure and provide clear feedback for format violations
**Validates: Requirements 6.1, 6.3, 6.4**

### Property 9: Directory structure consistency
*For any* plugin configuration class, the system should look for documentation in the correct directory based on plugin type and naming conventions
**Validates: Requirements 6.4, 6.5**

### Property 10: Backward compatibility preservation
*For any* existing schema consumer or validation process, the enhanced schema generation should not break existing functionality when documentation integration is disabled
**Validates: Requirements 5.1, 5.4, 5.5**