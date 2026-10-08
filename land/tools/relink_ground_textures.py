#!/usr/bin/env python3
"""Run from the Godot project root: python land/tools/relink_ground_textures.py

Rewrites generated-cache texture references inside land/materials/*.tres to
res:// paths pointing at ORIGINAL source PNG files in this project.
Backups are saved as *.tres.bak; no material values or geometry are changed.
"""
from pathlib import Path
import re

root=Path.cwd()
if not (root/'project.godot').exists():
    raise SystemExit('Run this script inside your Godot project folder (project.godot).')
material_dir=root/'land/materials'
files=list(material_dir.glob('*.tres'))
textures={}
for p in root.rglob('*.png'):
    if '.godot' in p.parts or '.git' in p.parts:
        continue
    textures.setdefault(p.name.lower(),[]).append(p)

import_re=re.compile(r'^\[sub_resource type="CompressedTexture2D" id="([^"]+)"\]\nload_path = "res://\.godot/imported/([^/]+\.png)-[0-9a-f]+\.(?:s3tc\.)?ctex"\n?', re.M)
count=0
for path in files:
    original=path.read_text(encoding='utf-8')
    subresources=list(import_re.finditer(original))
    resolved=[]
    for match in subresources:
        tex_id,filename=match.group(1),match.group(2)
        choices=textures.get(filename.lower(),[])
        if not choices:
            print(f'NOT FOUND {filename} needed by {path.name}')
            continue
        # Prefer folders within the land asset tree when duplicate names exist.
        selected=sorted(choices,key=lambda p: (0 if 'land' in p.parts else 1,len(p.parts)))[0]
        res='res://'+selected.relative_to(root).as_posix()
        resolved.append((match,tex_id,res))
    if not resolved: continue
    new=original
    # Remove resolved legacy compressed-texture blocks only.
    for match,tid,res in reversed(resolved):
        new=new[:match.start()]+new[match.end():]
    extras=[]
    for i,(match,tid,res) in enumerate(resolved,1):
        ext_id=f'texture_{i}'
        extras.append(f'[ext_resource type="Texture2D" path="{res}" id="{ext_id}"]')
        new=new.replace(f'SubResource("{tid}")',f'ExtResource("{ext_id}")')
    marker='\n\n'
    split=new.find(marker)
    if split!=-1:
        new=new[:split]+marker+'\n'.join(extras)+new[split:]
    else:
        raise RuntimeError(f'Bad .tres format: {path}')
    (path.with_suffix('.tres.bak')).write_text(original,encoding='utf-8')
    path.write_text(new,encoding='utf-8')
    print(f'Relinked {len(resolved)} texture(s): {path.relative_to(root)}')
    count+=len(resolved)
print(f'Done. Total source texture references updated: {count}')
