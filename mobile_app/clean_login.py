#!/usr/bin/env python3
# -*- coding: utf-8 -*-

filepath = 'lib/screens/login_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Eliminar líneas con variables no usadas
new_lines = []
skip_block = False
for i, line in enumerate(lines):
    # Eliminar líneas 572-574 (margen, umbral, idPredicho)
    if 'final margen = result' in line:
        continue
    if 'final umbral = result' in line:
        continue
    if 'final idPredicho = result' in line:
        continue
    
    # Eliminar bloque de 'String detalles' para voz
    if 'String detalles =' in line and 'Voz Fallida' in line:
        skip_block = True
        continue
    
    if skip_block:
        if '[Login]' in line and 'Autenticación en nube fallida' in line:
            skip_block = False
        else:
            continue
    
    new_lines.append(line)

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print('✅ Código limpiado')
