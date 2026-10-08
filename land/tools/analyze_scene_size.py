#!/usr/bin/env python3
"""Diagnose which Godot text-scene sections take the most disk space.
Usage from Godot project root: python land/tools/analyze_scene_size.py land/scenes/main.tscn
"""
from pathlib import Path
import sys,re

scene=Path(sys.argv[1] if len(sys.argv)>1 else 'land/scenes/main.tscn')
if not scene.exists():
    raise SystemExit(f'File not found: {scene}')
content=scene.read_bytes()
pattern=re.compile(rb'(?m)^\[(?:sub_resource|ext_resource|node|connection|editable)[^\r\n]*\]')
entries=list(pattern.finditer(content))
parts=[]
for i,m in enumerate(entries):
    last=entries[i+1].start() if i+1<len(entries) else len(content)
    parts.append((last-m.start(),m.group().decode('utf-8','replace')[:220]))
print(f'Scene: {scene}\nTotal size: {len(content)/1024/1024:.2f} MiB')
print('Sections:',len(parts))
print('Largest sections:')
for size,header in sorted(parts,reverse=True)[:20]:
    print(f' {size/1024/1024:9.2f} MiB  {header}')
print('\nLarge binary/array-like values (rough counts):')
for keyword in [b'PackedByteArray(', b'PackedVector3Array(', b'PackedInt32Array(', b'ArrayMesh', b'SurfaceTool', b'NavigationMesh', b'Image.create_from_data']:
    print(f' {keyword.decode()}: {content.count(keyword)}')
