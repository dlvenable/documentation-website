---
layout: default
title: Parse JSON
parent: Processors
grand_parent: Pipelines
nav_order: 290
---

# Parse JSON processor

The `parse_json` processor parses JSON-formatted strings within an event, including nested fields. It can optionally use a JSON pointer to extract a specific part of the source JSON and add the extracted data to the event.

## Configuration

You can configure the `parse_json` processor with the following options.

<!--
This table is generated from JSON documentation. Do not edit it directly.
Source: _data/data-prepper/processors/parse-json.json
-->

{% include data-prepper-config-table.html plugin="parse-json" plugin_type="processor" %}

## Usage

To use the `parse_json` processor, add it to your `pipeline.yaml` configuration file:

```yaml
parse-json-pipeline:
  source:
    ...
  ...
  processor:
    - parse_json:
```
{% include copy.html %}

All examples use the following JSON message for the event output:

```json
{"outer_key": {"inner_key": "inner_value"}}
```
{% include copy.html %}

### Basic example

The following example parses a JSON message field and flattens the data into the event. The original `message` from the example event remains, and the parsed content is added at the root level, as shown in the following output: 

```json
{
  "message": "{\"outer_key\": {\"inner_key\": \"inner_value\"}}",
  "outer_key": {
    "inner_key": "inner_value"
  }
}
```

### Delete a source

If you want to remove the original field from the originating JSON message, use the `delete_source` option, as shown in the following example pipeline:

```yaml
parse-json-pipeline:
  source:
    ...
  ...
  processor:
    - parse_json:
        delete_source: true
```
{% include copy.html %}

In the following event, the `message` field is parsed and removed, leaving only the structured output:

```json
{
  "outer_key": {
    "inner_key": "inner_value"
  }
}
```


### Example using a JSON pointer

You can use the `pointer` option to extract a specific nested field from the JSON data, as shown in the following example pipeline:

```yaml
parse-json-pipeline:
  source:
    ...
  ...
  processor:
    - parse_json:
        pointer: "/outer_key/inner_key"
```
{% include copy.html %}

Only the value at the pointer path `/outer_key/inner_key` is extracted and added to the event. If you set `destination`, the extracted value will be added to that field instead:

```json
{
  "message": "{\"outer_key\": {\"inner_key\": \"inner_value\"}}",
  "inner_key": "inner_value"
}
```
