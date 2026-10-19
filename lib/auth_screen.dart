import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PantallaIngreso extends StatefulWidget {
  const PantallaIngreso({super.key});

  @override
  State<PantallaIngreso> createState() => _PantallaIngresoState();
}

class _PantallaIngresoState extends State<PantallaIngreso> {
  final _formKey = GlobalKey<FormState>();
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();
  bool _creandoCuenta = false;
  bool _ocultarContrasena = true;
  bool _procesando = false;

  @override
  void dispose() {
    _correoController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  Future<void> _enviarFormulario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _procesando = true);
    try {
      final correo = _correoController.text.trim();
      final contrasena = _contrasenaController.text;
      if (_creandoCuenta) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: correo,
          password: contrasena,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: correo,
          password: contrasena,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeErrorFirebase(error))));
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _abrirRecuperacion() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RecuperarContrasena(correoInicial: _correoController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso a la cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _creandoCuenta ? 'Crear cuenta' : 'Iniciar sesión',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _correoController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final correo = value?.trim() ?? '';
                      if (correo.isEmpty ||
                          !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(correo)) {
                        return 'Escribe un correo electrónico válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contrasenaController,
                    obscureText: _ocultarContrasena,
                    autofillHints: [
                      _creandoCuenta
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _ocultarContrasena
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        onPressed: () => setState(
                          () => _ocultarContrasena = !_ocultarContrasena,
                        ),
                        icon: Icon(
                          _ocultarContrasena
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final contrasena = value ?? '';
                      if (contrasena.isEmpty) return 'Escribe tu contraseña';
                      if (_creandoCuenta && contrasena.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _enviarFormulario(),
                  ),
                  if (!_creandoCuenta)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _procesando ? null : _abrirRecuperacion,
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    )
                  else
                    const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _procesando ? null : _enviarFormulario,
                    child: _procesando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _creandoCuenta ? 'Crear cuenta' : 'Iniciar sesión',
                          ),
                  ),
                  TextButton(
                    onPressed: _procesando
                        ? null
                        : () =>
                              setState(() => _creandoCuenta = !_creandoCuenta),
                    child: Text(
                      _creandoCuenta
                          ? '¿Ya tienes cuenta? Inicia sesión'
                          : '¿No tienes cuenta? Regístrate',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RecuperarContrasena extends StatefulWidget {
  const RecuperarContrasena({required this.correoInicial, super.key});

  final String correoInicial;

  @override
  State<RecuperarContrasena> createState() => _RecuperarContrasenaState();
}

class _RecuperarContrasenaState extends State<RecuperarContrasena> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _correoController;
  bool _procesando = false;
  bool _correoEnviado = false;

  @override
  void initState() {
    super.initState();
    _correoController = TextEditingController(text: widget.correoInicial);
  }

  @override
  void dispose() {
    _correoController.dispose();
    super.dispose();
  }

  Future<void> _enviarCorreo() async {
    if (!_formKey.currentState!.validate()) return;

    final correo = _correoController.text.trim();
    setState(() => _procesando = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: correo);
      if (mounted) setState(() => _correoEnviado = true);
    } on FirebaseAuthException catch (error) {
      debugPrint('Password reset failed (${error.code}).');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorRecuperacion(error))),
        );
      }
    } catch (error) {
      debugPrint('Password reset failed (${error.runtimeType}).');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo enviar la solicitud. Revisa tu conexión e inténtalo de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _correoEnviado
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mark_email_read_outlined,
                        size: 72,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Firebase aceptó la solicitud. Si existe una cuenta asociada, recibirás instrucciones en su correo para restablecer la contraseña.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Volver al inicio de sesión'),
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Escribe el correo de tu cuenta y te enviaremos un enlace para restablecer tu contraseña.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _correoController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final correo = value?.trim() ?? '';
                            if (correo.isEmpty ||
                                !RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                                    .hasMatch(correo)) {
                              return 'Escribe un correo electrónico válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _procesando ? null : _enviarCorreo,
                          child: _procesando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Enviar correo de recuperación'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

String mensajeErrorFirebase(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-email':
      return 'El correo electrónico no es válido.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'El correo o la contraseña son incorrectos.';
    case 'email-already-in-use':
      return 'Ya existe una cuenta registrada con ese correo.';
    case 'weak-password':
      return 'La contraseña es demasiado débil. Usa al menos 6 caracteres.';
    case 'too-many-requests':
      return 'Hubo demasiados intentos. Inténtalo de nuevo más tarde.';
    case 'network-request-failed':
      return 'No se pudo conectar. Revisa tu conexión a internet.';
    case 'operation-not-allowed':
      return 'Activa el acceso con correo y contraseña en Firebase.';
    default:
      return error.message ?? 'No se pudo completar la operación.';
  }
}

String mensajeErrorRecuperacion(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-email':
      return 'Escribe una dirección de correo válida.';
    case 'too-many-requests':
      return 'Se realizaron demasiados intentos. Espera un momento e inténtalo de nuevo.';
    case 'network-request-failed':
      return 'No se pudo conectar con Firebase. Revisa tu conexión a internet.';
    case 'operation-not-allowed':
      return 'La recuperación no está habilitada. Verifica el proveedor Correo electrónico/Contraseña en Firebase.';
    case 'configuration-not-found':
    case 'app-not-authorized':
      return 'La configuración de Firebase no coincide con esta aplicación. Verifica el proyecto y el ID de Android.';
    case 'user-not-found':
      return 'No se pudo procesar la solicitud. Revisa el correo y la configuración de Firebase.';
    default:
      return 'Firebase no pudo aceptar la solicitud. Inténtalo de nuevo más tarde o revisa la configuración del proyecto.';
  }
}
