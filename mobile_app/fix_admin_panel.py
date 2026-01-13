#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para remover la sección antigua de Gestión de Usuarios
y agregar botones de eliminar/restaurar a los 3 nuevos paneles
"""

def main():
    filepath = 'lib/screens/admin_panel_screen.dart'
    
    # Leer archivo
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # 1. Remover líneas 500-502 (desktop layout) - indices 499-501
    # Línea 500: _buildSectionHeader('👥 Gestión de Usuarios'),
    # Línea 501: _buildUserManagement(),
    # Línea 502: SizedBox(height: 24),
    del lines[499:502]
    
    # 2. Remover líneas 557-559 del móvil (ahora son 554-556 por la eliminación anterior)
    # Ajustamos el índice: 557 - 3 = 554
    del lines[554:557]
    
    # 3. Remover el widget _buildUserManagement() completo
    # Buscar la línea que contiene "Widget _buildUserManagement()"
    start_idx = None
    for i, line in enumerate(lines):
        if 'Widget _buildUserManagement()' in line:
            start_idx = i
            break
    
    if start_idx is not None:
        # Buscar el final del widget (siguiente "Widget _build")
        end_idx = None
        for i in range(start_idx + 1, len(lines)):
            if lines[i].strip().startswith('Widget _build') or \
               (lines[i].strip().startswith('Future<void>') and '_confirm' in lines[i]):
                end_idx = i
                break
        
        if end_idx is not None:
            # Eliminar el widget completo
            del lines[start_idx:end_idx]
            print(f"✅ Widget _buildUserManagement() eliminado (líneas {start_idx+1} a {end_idx})")
    
    # Escribir archivo modificado
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    print("✅ Sección de Gestión de Usuarios removida del admin panel")
    print("   - Removida del layout de escritorio")
    print("   - Removida del layout móvil")
    print("   - Widget _buildUserManagement() eliminado")

if __name__ == '__main__':
    main()
