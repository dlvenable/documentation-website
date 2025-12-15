---
layout: default
title: Test HTML Content Preservation
---

# Test: HTML Content Preservation in JSON Documentation

This demonstrates how HTML markup in JSON descriptions is preserved in the generated tables.

## Configuration Options

{% include data-prepper-config-table.html plugin="html-test" plugin_type="processor" %}

## Expected Behavior

The generated table should preserve:
- `<code>` tags for inline code formatting
- `<em>` and `<strong>` tags for emphasis
- `<a href="">` tags for links
- HTML entities like `&lt;`, `&gt;`, `&amp;`
- Nested HTML content in sub-properties

## Validation

Check that:
1. HTML tags render correctly (not as plain text)
2. Links are clickable
3. Code formatting is applied
4. HTML entities display properly
5. No HTML is escaped or broken