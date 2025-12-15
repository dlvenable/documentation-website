---
layout: default
title: Test Aggregate Table Generation
---

# Test: Aggregate Processor Configuration Table

This demonstrates nested property handling in the JSON-to-Markdown table generation.

## Configuration Options

The following table describes options you can use with the Aggregate processor:

{% include data-prepper-config-table.html plugin="aggregate" plugin_type="processor" %}

## Notes

This example shows:
- Basic properties (identification_keys, group_duration, local_mode)
- Nested object properties (action with sub-properties)
- Array types with items specification
- Default values and examples