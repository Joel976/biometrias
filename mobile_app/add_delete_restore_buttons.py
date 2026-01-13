#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para agregar botones de eliminar/restaurar a los 3 paneles de usuarios
"""

def main():
    filepath = 'lib/screens/admin_panel_screen.dart'
    
    # Leer archivo
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # ============= MODIFICAR _buildOfflineOnlyUsers =============
    # Reemplazar el botón de "Sincronizar" por botones de eliminar/restaurar
    
    old_offline_button = '''trailing: IconButton(
                      icon: Icon(Icons.cloud_upload, color: Colors.blue),
                      tooltip: 'Sincronizar al backend',
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '⏳ Sincronización pendiente de implementación',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          ),
                    ),'''
    
    new_offline_button = '''trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botón de eliminar (solo si no está eliminado)
                        if (user.estado != 'eliminado')
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Eliminar usuario',
                            onPressed: () => _confirmDeleteUser(user),
                          ),
                        // Botón de restaurar (solo si está eliminado)
                        if (user.estado == 'eliminado')
                          IconButton(
                            icon: Icon(Icons.restore, color: Colors.blue),
                            tooltip: 'Restaurar usuario',
                            onPressed: () => _confirmRestoreUser(user),
                          ),
                      ],
                    ),'''
    
    content = content.replace(old_offline_button, new_offline_button)
    
    # ============= MODIFICAR _buildOnlineOnlyUsers =============
    
    old_online_button = '''trailing: IconButton(
                      icon: Icon(Icons.download, color: Colors.green),
                      tooltip: 'Descargar a local',
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '⏳ Descarga pendiente de implementación',
                              ),
                              backgroundColor: Colors.blue,
                            ),
                          ),
                    ),'''
    
    new_online_button = '''trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botón de eliminar (solo si no está eliminado)
                        if (user.estado != 'eliminado')
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Eliminar usuario',
                            onPressed: () => _confirmDeleteUser(user),
                          ),
                        // Botón de restaurar (solo si está eliminado)
                        if (user.estado == 'eliminado')
                          IconButton(
                            icon: Icon(Icons.restore, color: Colors.blue),
                            tooltip: 'Restaurar usuario',
                            onPressed: () => _confirmRestoreUser(user),
                          ),
                      ],
                    ),'''
    
    content = content.replace(old_online_button, new_online_button)
    
    # ============= MODIFICAR _buildSyncedUsers =============
    
    old_synced_icon = '''trailing: Icon(Icons.check_circle, color: Colors.green),'''
    
    new_synced_button = '''trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botón de eliminar (solo si no está eliminado)
                        if (user.estado != 'eliminado')
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Eliminar usuario',
                            onPressed: () => _confirmDeleteUser(user),
                          ),
                        // Botón de restaurar (solo si está eliminado)
                        if (user.estado == 'eliminado')
                          IconButton(
                            icon: Icon(Icons.restore, color: Colors.blue),
                            tooltip: 'Restaurar usuario',
                            onPressed: () => _confirmRestoreUser(user),
                          ),
                      ],
                    ),'''
    
    content = content.replace(old_synced_icon, new_synced_button)
    
    # Escribir archivo modificado
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ Botones de eliminar/restaurar agregados a los 3 paneles:")
    print("   - 📱 Usuarios Solo Offline")
    print("   - ☁️ Usuarios Solo Online")
    print("   - 🔄 Usuarios Sincronizados")
    print("\n✅ Los botones ahora se muestran dinámicamente según el estado del usuario:")
    print("   - 🗑️ Botón ELIMINAR (rojo) si usuario activo")
    print("   - ♻️ Botón RESTAURAR (azul) si usuario eliminado")

if __name__ == '__main__':
    main()
