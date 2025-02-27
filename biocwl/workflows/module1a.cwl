#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
baseCommand: [ module1a.py, get-data-frame, to-json,--orient, records ]
inputs:
  gene_set:
    type: File
    inputBinding:
      position: 0
      prefix: --input_payload_file
  threshold:
    type: float
    inputBinding:
      position: 1
      prefix: --threshold
outputs:
  functionally_similar_genes:
    type: stdout
stdout: module1a.records.json