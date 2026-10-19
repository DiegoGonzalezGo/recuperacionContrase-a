import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? errorInicializacion;
  try {
    await Firebase.initializeApp();
  } on FirebaseException catch (error) {
    debugPrint('Firebase initialization failed (${error.code}).');
    errorInicializacion = error;
  } catch (error) {
    debugPrint('Firebase initialization failed (${error.runtimeType}).');
    errorInicializacion = error;
  }
  runApp(MiAplicacion(errorInicializacion: errorInicializacion));
}

class MiAplicacion extends StatelessWidget {
  const MiAplicacion({super.key, this.errorInicializacion});

  final Object? errorInicializacion;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mi primera app',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: errorInicializacion == null
          ? const AuthGate()
          : const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No se pudo iniciar Firebase. Verifica que '
                    'google-services.json corresponda al ID Android '
                    'com.example.sharedpref y que Firebase esté configurado.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'No se pudo consultar el estado de la sesión: ${snapshot.error}',
              ),
            ),
          );
        }

        if (snapshot.data != null) {
          return const PantallaUsuario();
        }

        return const PantallaIngreso();
      },
    );
  }
}

class PantallaUsuario extends StatefulWidget {
  const PantallaUsuario({super.key});

  @override
  State<PantallaUsuario> createState() => _PantallaUsuarioState();
}

class _PantallaUsuarioState extends State<PantallaUsuario> {
  final nombreController = TextEditingController();
  final usuarioController = TextEditingController();
  final matriculaController = TextEditingController();
  final numeroController = TextEditingController();

  String nombreGuardado = '';
  String usuarioGuardado = '';
  String matriculaGuardada = '';
  String numeroGuardado = '';
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  // Recuperar los datos guardados
  Future<void> cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    const campos = ['nombre', 'usuario', 'matricula', 'numero'];

    final tieneDatosDeCuenta = campos.any(
      (campo) => prefs.containsKey('${uid}_$campo'),
    );
    if (!tieneDatosDeCuenta) {
      for (final campo in campos) {
        final valorAnterior = prefs.getString(campo);
        if (valorAnterior != null) {
          await prefs.setString('${uid}_$campo', valorAnterior);
          await prefs.remove(campo);
        }
      }
    }

    if (!mounted) return;
    setState(() {
      nombreGuardado = prefs.getString('${uid}_nombre') ?? '';
      usuarioGuardado = prefs.getString('${uid}_usuario') ?? '';
      matriculaGuardada = prefs.getString('${uid}_matricula') ?? '';
      numeroGuardado = prefs.getString('${uid}_numero') ?? '';
      cargando = false;
    });
  }

  // Guardar los datos del usuario
  Future<void> guardarDatos() async {
    final nombre = nombreController.text.trim();
    final usuario = usuarioController.text.trim();
    final matricula = matriculaController.text.trim();
    final numero = numeroController.text.trim();

    if (nombre.isEmpty ||
        usuario.isEmpty ||
        matricula.isEmpty ||
        numero.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await prefs.setString('${uid}_nombre', nombre);
    await prefs.setString('${uid}_usuario', usuario);
    await prefs.setString('${uid}_matricula', matricula);
    await prefs.setString('${uid}_numero', numero);

    setState(() {
      nombreGuardado = nombre;
      usuarioGuardado = usuario;
      matriculaGuardada = matricula;
      numeroGuardado = numero;
    });

    nombreController.clear();
    usuarioController.clear();
    matriculaController.clear();
    numeroController.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos guardados correctamente')),
    );
  }

  // Eliminar los datos guardados
  Future<void> eliminarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await prefs.remove('${uid}_nombre');
    await prefs.remove('${uid}_usuario');
    await prefs.remove('${uid}_matricula');
    await prefs.remove('${uid}_numero');

    setState(() {
      nombreGuardado = '';
      usuarioGuardado = '';
      matriculaGuardada = '';
      numeroGuardado = '';
    });
  }

  @override
  void dispose() {
    nombreController.dispose();
    usuarioController.dispose();
    matriculaController.dispose();
    numeroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hayUsuario = usuarioGuardado.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi aplicación shared preferences'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
              } on FirebaseAuthException catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(mensajeErrorFirebase(error))),
                );
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: hayUsuario
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.account_circle,
                      size: 100,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '¡Bienvenido, $nombreGuardado!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Usuario: $usuarioGuardado',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Matrícula: $matriculaGuardada',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Número: $numeroGuardado',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: eliminarDatos,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Eliminar datos'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.person_add_alt_1,
                      size: 80,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Registrar usuario',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: usuarioController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de usuario',
                        prefixIcon: Icon(Icons.account_box),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: matriculaController,
                      decoration: const InputDecoration(
                        labelText: 'Matrícula',
                        prefixIcon: Icon(Icons.numbers),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: numeroController,
                      decoration: const InputDecoration(
                        labelText: 'Número de teléfono',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: guardarDatos,
                      child: const Text('Guardar datos'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
