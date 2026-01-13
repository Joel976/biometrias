import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/biometric_backend_service.dart';

/// Ejemplo práctico de cómo usar la integración con el backend en la nube
/// IP: 167.71.155.9
/// Puerto Oreja: 8080
/// Puerto Voz: 8081

class BackendIntegrationExample extends StatefulWidget {
  const BackendIntegrationExample({Key? key}) : super(key: key);

  @override
  State<BackendIntegrationExample> createState() =>
      _BackendIntegrationExampleState();
}

class _BackendIntegrationExampleState extends State<BackendIntegrationExample> {
  final backendService = BiometricBackendService();
  String _status = 'Listo';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integración Backend Nube')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Estado
              Card(
                color: _loading ? Colors.orange[100] : Colors.green[100],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (_loading) const CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(
                        _status,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // SECCIÓN: USUARIOS
              const Text(
                '👤 USUARIOS',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: _loading ? null : _testRegistrarUsuario,
                child: const Text('1. Registrar Usuario'),
              ),

              ElevatedButton(
                onPressed: _loading ? null : _testEliminarUsuario,
                child: const Text('2. Eliminar Usuario (soft delete)'),
              ),

              ElevatedButton(
                onPressed: _loading ? null : _testRestaurarUsuario,
                child: const Text('3. Restaurar Usuario'),
              ),

              const Divider(height: 40),

              // SECCIÓN: OREJA
              const Text(
                '👂 BIOMETRÍA DE OREJA',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: _loading ? null : _testRegistrarOreja,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('4. Registrar Biometría Oreja (7+ fotos)'),
              ),

              ElevatedButton(
                onPressed: _loading ? null : _testAutenticarOreja,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('5. Autenticar con Oreja'),
              ),

              const Divider(height: 40),

              // SECCIÓN: VOZ
              const Text(
                '🎤 BIOMETRÍA DE VOZ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: _loading ? null : _testRegistrarVoz,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: const Text('6. Registrar Biometría Voz (6 audios)'),
              ),

              ElevatedButton(
                onPressed: _loading ? null : _testAutenticarVoz,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
                child: const Text('7. Autenticar con Voz'),
              ),

              const Divider(height: 40),

              // SECCIÓN: FRASES
              const Text(
                '💬 FRASES DINÁMICAS',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: _loading ? null : _testListarFrases,
                child: const Text('8. Listar Frases'),
              ),

              ElevatedButton(
                onPressed: _loading ? null : _testFraseAleatoria,
                child: const Text('9. Obtener Frase Aleatoria'),
              ),

              ElevatedButton(
                onPressed: _loading ? null : _testAgregarFrase,
                child: const Text('10. Agregar Nueva Frase'),
              ),

              const Divider(height: 40),

              // SECCIÓN: CONECTIVIDAD
              const Text(
                '🌐 CONECTIVIDAD',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: _loading ? null : _testConectividad,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('11. Verificar Conectividad'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // TESTS
  // ============================================

  Future<void> _testRegistrarUsuario() async {
    setState(() {
      _loading = true;
      _status = 'Registrando usuario...';
    });

    try {
      final result = await backendService.registrarUsuario(
        identificadorUnico: '0102030405',
        nombres: 'Juan',
        apellidos: 'Pérez',
      );

      setState(() {
        _status = '✅ Usuario registrado!\n${result.toString()}';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testEliminarUsuario() async {
    setState(() {
      _loading = true;
      _status = 'Eliminando usuario...';
    });

    try {
      final result = await backendService.eliminarUsuario(
        identificador: '0102030405',
      );

      setState(() {
        _status = '✅ Usuario eliminado!\n${result.toString()}';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testRestaurarUsuario() async {
    setState(() {
      _loading = true;
      _status = 'Restaurando usuario...';
    });

    try {
      final result = await backendService.restaurarUsuario(
        identificador: '0102030405',
      );

      setState(() {
        _status = '✅ Usuario restaurado!\n${result.toString()}';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testRegistrarOreja() async {
    setState(() {
      _loading = true;
      _status =
          'Registrando biometría de oreja...\n(necesitas capturar 7+ fotos)';
    });

    try {
      // TODO: Reemplazar con tus fotos reales
      // Ejemplo con datos dummy:
      List<Uint8List> fotos = [];
      for (int i = 0; i < 7; i++) {
        // Aquí deberías capturar fotos reales de la cámara
        fotos.add(Uint8List(100)); // Dummy data
      }

      final result = await backendService.registrarBiometriaOreja(
        identificador: '0102030405',
        imagenes: fotos,
      );

      setState(() {
        _status = '✅ Biometría de oreja registrada!\n${result.toString()}';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e\n\nNota: Necesitas capturar 7+ fotos reales';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testAutenticarOreja() async {
    setState(() {
      _loading = true;
      _status = 'Autenticando con oreja...\n(incluye validación TFLite)';
    });

    try {
      // TODO: Reemplazar con foto real
      final foto = Uint8List(100); // Dummy data

      final result = await backendService.autenticarOreja(
        imagenBytes: foto,
        identificador: '0102030405',
      );

      if (result['autenticado'] == true) {
        setState(() {
          _status =
              '✅ AUTENTICADO!\n\nMargen: ${result['margen']}\nUmbral: ${result['umbral']}\n${result['mensaje']}';
        });
      } else {
        setState(() {
          _status = '❌ NO AUTENTICADO\n\n${result['mensaje']}';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e\n\nNota: Necesitas una foto real de oreja';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testRegistrarVoz() async {
    setState(() {
      _loading = true;
      _status = 'Registrando biometría de voz...\n(necesitas grabar 6 audios)';
    });

    try {
      // TODO: Reemplazar con audios reales
      List<Uint8List> audios = [];
      for (int i = 0; i < 6; i++) {
        audios.add(Uint8List(100)); // Dummy data
      }

      final result = await backendService.registrarBiometriaVoz(
        identificador: '0102030405',
        audios: audios,
      );

      setState(() {
        _status = '✅ Biometría de voz registrada!\n${result.toString()}';
      });
    } catch (e) {
      setState(() {
        _status =
            '❌ Error: $e\n\nNota: Necesitas grabar 6 audios reales (.flac)';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testAutenticarVoz() async {
    setState(() {
      _loading = true;
      _status = 'Autenticando con voz...';
    });

    try {
      // Primero obtener frase aleatoria
      final frase = await backendService.obtenerFraseAleatoria();

      setState(() {
        _status = 'Frase obtenida: "${frase['frase']}"\n\nGrabando audio...';
      });

      // TODO: Reemplazar con audio real
      final audio = Uint8List(100); // Dummy data

      final result = await backendService.autenticarVoz(
        audioBytes: audio,
        identificador: '0102030405',
        idFrase: frase['id_frase'],
      );

      if (result['autenticado'] == true) {
        setState(() {
          _status = '✅ VOZ AUTENTICADA!\n\nFrase: "${frase['frase']}"';
        });
      } else {
        setState(() {
          _status = '❌ VOZ NO AUTENTICADA\n\n${result['mensaje']}';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e\n\nNota: Necesitas grabar audio real (.flac)';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testListarFrases() async {
    setState(() {
      _loading = true;
      _status = 'Listando frases...';
    });

    try {
      final frases = await backendService.listarFrases();

      String listado = '📝 FRASES DISPONIBLES (${frases.length}):\n\n';
      for (var frase in frases) {
        listado +=
            '${frase['id_frase']}: ${frase['frase']}\n   ${frase['activo'] == 1 ? '✅ Activa' : '⚠️ Inactiva'}\n\n';
      }

      setState(() {
        _status = listado;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testFraseAleatoria() async {
    setState(() {
      _loading = true;
      _status = 'Obteniendo frase aleatoria...';
    });

    try {
      final frase = await backendService.obtenerFraseAleatoria();

      setState(() {
        _status =
            '🎲 FRASE ALEATORIA:\n\nID: ${frase['id_frase']}\nFrase: "${frase['frase']}"\nEstado: ${frase['activo'] == 1 ? 'Activa' : 'Inactiva'}';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testAgregarFrase() async {
    setState(() {
      _loading = true;
      _status = 'Agregando nueva frase...';
    });

    try {
      final result = await backendService.agregarFrase(
        frase: 'Mi voz es única y segura',
      );

      setState(() {
        _status = '✅ Frase agregada!\n${result.toString()}';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testConectividad() async {
    setState(() {
      _loading = true;
      _status = 'Verificando conectividad...';
    });

    try {
      final online = await backendService.isOnline();

      setState(() {
        _status = online
            ? '✅ BACKEND EN LÍNEA\n\n🌐 Conectado a:\n• Oreja: 167.71.155.9:8080\n• Voz: 167.71.155.9:8081'
            : '⚠️ SIN CONEXIÓN\n\nModo offline activado.\nLas autenticaciones usarán templates locales.';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error verificando conectividad: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }
}
