import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
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
      builder: errorInicializacion == null
          ? (context, child) =>
                SesionConInactividad(child: child ?? const SizedBox.shrink())
          : null,
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

class SesionConInactividad extends StatefulWidget {
  const SesionConInactividad({required this.child, super.key});

  final Widget child;

  static void registrarActividad(BuildContext context) {
    context
        .getInheritedWidgetOfExactType<_SesionInactividadScope>()
        ?.registrarActividad();
  }

  static Future<void> cerrarSesion(BuildContext context) async {
    final scope = context
        .getInheritedWidgetOfExactType<_SesionInactividadScope>();
    if (scope == null) {
      await FirebaseAuth.instance.signOut();
      return;
    }
    await scope.cerrarSesion(context);
  }

  @override
  State<SesionConInactividad> createState() => _SesionConInactividadState();
}

class _SesionConInactividadState extends State<SesionConInactividad>
    with WidgetsBindingObserver {
  static const _duracionInactividad = Duration(seconds: 15);

  StreamSubscription<User?>? _suscripcionAuth;
  Timer? _temporizador;
  DateTime? _ultimaActividad;
  bool _autenticado = false;
  bool _cerrandoSesion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _suscripcionAuth = FirebaseAuth.instance.authStateChanges().listen(
      _actualizarEstadoAutenticacion,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          'Inactivity monitor could not observe auth state '
          '(${error.runtimeType}).',
        );
      },
    );
  }

  void _actualizarEstadoAutenticacion(User? usuario) {
    _autenticado = usuario != null;
    if (!_autenticado) {
      _temporizador?.cancel();
      _temporizador = null;
      _ultimaActividad = null;
      _cerrandoSesion = false;
      return;
    }

    if (_ultimaActividad == null) {
      _registrarActividad();
    }
  }

  void _registrarActividad() {
    if (!_autenticado || _cerrandoSesion) return;

    _ultimaActividad = DateTime.now();
    _programarCierre(_duracionInactividad);
  }

  void _programarCierre(Duration demora) {
    _temporizador?.cancel();
    _temporizador = Timer(demora, _comprobarInactividad);
  }

  void _comprobarInactividad() {
    if (!_autenticado || _cerrandoSesion || _ultimaActividad == null) return;

    final transcurrido = DateTime.now().difference(_ultimaActividad!);
    final restante = _duracionInactividad - transcurrido;
    if (restante > Duration.zero) {
      _programarCierre(restante);
      return;
    }

    unawaited(_cerrarSesion());
  }

  Future<void> _cerrarSesion([BuildContext? contextoManual]) async {
    if (!_autenticado || _cerrandoSesion) return;

    _temporizador?.cancel();
    _temporizador = null;
    _cerrandoSesion = true;
    var cierreCompletado = false;
    try {
      await FirebaseAuth.instance.signOut();
      cierreCompletado = true;
    } on FirebaseAuthException catch (error) {
      debugPrint('Sign out failed (${error.code}).');
      if (contextoManual != null && contextoManual.mounted) {
        ScaffoldMessenger.of(contextoManual)
            .showSnackBar(SnackBar(content: Text(mensajeErrorFirebase(error))));
      }
    } finally {
      if (!cierreCompletado && _autenticado) {
        _cerrandoSesion = false;
        _registrarActividad();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _comprobarInactividad();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _temporizador?.cancel();
    unawaited(_suscripcionAuth?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _registrarActividad(),
      onPointerMove: (_) => _registrarActividad(),
      onPointerSignal: (_) => _registrarActividad(),
      child: Focus(
        onKeyEvent: (node, event) {
          _registrarActividad();
          return KeyEventResult.ignored;
        },
        child: _SesionInactividadScope(
          registrarActividad: _registrarActividad,
          cerrarSesion: _cerrarSesion,
          child: widget.child,
        ),
      ),
    );
  }
}

class _SesionInactividadScope extends InheritedWidget {
  const _SesionInactividadScope({
    required this.registrarActividad,
    required this.cerrarSesion,
    required super.child,
  });

  final VoidCallback registrarActividad;
  final Future<void> Function([BuildContext? contextoManual]) cerrarSesion;

  @override
  bool updateShouldNotify(_SesionInactividadScope oldWidget) => false;
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
  final ImagePicker _selectorImagen = ImagePicker();

  String nombreGuardado = '';
  String usuarioGuardado = '';
  String matriculaGuardada = '';
  String numeroGuardado = '';
  XFile? _imagenCapturada;
  bool cargando = true;
  bool _abriendoCamara = false;

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

  Future<void> _abrirCamara() async {
    if (_abriendoCamara) return;
    setState(() => _abriendoCamara = true);

    try {
      final permiso = await Permission.camera.request();
      if (!mounted) return;

      if (!permiso.isGranted) {
        final requiereConfiguracion =
            permiso.isPermanentlyDenied || permiso.isRestricted;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              requiereConfiguracion
                  ? 'El permiso de cámara está bloqueado. Habilítalo en la configuración de la aplicación.'
                  : 'Se necesita permiso de cámara para tomar una foto.',
            ),
            action: requiereConfiguracion
                ? SnackBarAction(
                    label: 'Abrir ajustes',
                    onPressed: () async {
                      await openAppSettings();
                    },
                  )
                : null,
          ),
        );
        return;
      }

      final imagen = await _selectorImagen.pickImage(
        source: ImageSource.camera,
      );
      if (imagen == null || !mounted) return;
      setState(() => _imagenCapturada = imagen);
    } on PlatformException catch (error) {
      debugPrint('Could not open camera (${error.code}).');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la cámara.')),
        );
      }
    } finally {
      if (mounted) setState(() => _abriendoCamara = false);
    }
  }

  Widget _controlesCamara() {
    return Column(
      children: [
        if (_imagenCapturada != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_imagenCapturada!.path),
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
        ],
        OutlinedButton.icon(
          onPressed: _abriendoCamara ? null : _abrirCamara,
          icon: _abriendoCamara
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.camera_alt_outlined),
          label: Text(_abriendoCamara ? 'Abriendo cámara...' : 'Abrir cámara'),
        ),
      ],
    );
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
              await SesionConInactividad.cerrarSesion(context);
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
                    const SizedBox(height: 16),
                    _controlesCamara(),
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
                      onChanged: (_) =>
                          SesionConInactividad.registrarActividad(context),
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: usuarioController,
                      onChanged: (_) =>
                          SesionConInactividad.registrarActividad(context),
                      decoration: const InputDecoration(
                        labelText: 'Nombre de usuario',
                        prefixIcon: Icon(Icons.account_box),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: matriculaController,
                      onChanged: (_) =>
                          SesionConInactividad.registrarActividad(context),
                      decoration: const InputDecoration(
                        labelText: 'Matrícula',
                        prefixIcon: Icon(Icons.numbers),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: numeroController,
                      onChanged: (_) =>
                          SesionConInactividad.registrarActividad(context),
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
                    const SizedBox(height: 16),
                    _controlesCamara(),
                  ],
                ),
        ),
      ),
    );
  }
}
