import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Catálogo de Películas',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF00106B), // Azul Cobalto de tu paleta
          foregroundColor: Colors.white,
        ),
      ),
      home: const AuthScreen(),
    );
  }
}

// ==========================================
// 1. PANTALLA DE INICIO (LOGIN / REGISTRO)
// ==========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _isLogin = true;
  String _httpMensaje = "Cargando dato curioso HTTP...";

  @override
  void initState() {
    super.initState();
    _hacerPeticionHTTP();
  }

  // Cumplimiento de Rúbrica: Solicitud HTTP
  Future<void> _hacerPeticionHTTP() async {
    try {
      final response = await http.get(Uri.parse('https://catfact.ninja/fact'));
      if (response.statusCode == 200) {
        setState(() {
          _httpMensaje = "Dato HTTP: ${json.decode(response.body)['fact']}";
        });
      }
    } catch (e) {
      setState(() => _httpMensaje = "Error HTTP");
    }
  }

  Future<void> _submit() async {
    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(
            email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
      } else {
        await _auth.createUserWithEmailAndPassword(
            email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
      }
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainScreen()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bienvenido al Catálogo')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_creation, size: 80, color: Color(0xFFFF5500)), // Naranja fuego
            const SizedBox(height: 20),
            Text(_isLogin ? 'Ingresar a tu cuenta' : 'Registrar Nuevo Usuario',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Correo Electrónico', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003D12), foregroundColor: Colors.white),
              child: Text(_isLogin ? 'Ingresar' : 'Registrarse'),
            ),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(_isLogin ? '¿No tienes cuenta? Regístrate' : '¿Ya tienes cuenta? Ingresa'),
            ),
            const Divider(),
            Text(_httpMensaje, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12), textAlign: TextAlign.center,),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA PRINCIPAL (CONTENEDOR CON MENÚ)
// ==========================================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _indiceActual = 0;
  final List<Widget> _pantallas = [const CatalogScreen(), const AdminScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Películas'),
        actions: [
          // Cumplimiento Rúbrica: Menú superior para seleccionar el catálogo o admin
          PopupMenuButton<int>(
            onSelected: (item) => setState(() => _indiceActual = item),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0, child: Text('Ver Catálogo')),
              const PopupMenuItem(value: 1, child: Text('Administración (Altas/Bajas)')),
              PopupMenuItem(
                value: 2, 
                child: const Text('Cerrar Sesión'),
                onTap: () {
                  FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
                },
              ),
            ],
          ),
        ],
      ),
      body: _pantallas[_indiceActual],
    );
  }
}

// ==========================================
// 2. PANTALLA DE CATÁLOGO
// ==========================================
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('peliculas').snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay películas en el catálogo.'));
        }
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var peli = snapshot.data!.docs[index];
            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                leading: Image.network(
                  peli['urlImagen'], 
                  width: 50, 
                  height: 80, 
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                ),
                title: Text(peli['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Click para ver detalles'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetailScreen(pelicula: peli)),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ==========================================
// 3. PANTALLA DE DESCRIPCIÓN DE LA PELÍCULA
// ==========================================
class DetailScreen extends StatelessWidget {
  final QueryDocumentSnapshot pelicula;
  const DetailScreen({super.key, required this.pelicula});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(pelicula['titulo'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.network(
                pelicula['urlImagen'], 
                height: 300, 
                errorBuilder: (c, e, s) => const Icon(Icons.movie, size: 100)
              ),
            ),
            const SizedBox(height: 20),
            Text('Título: ${pelicula['titulo']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Año de estreno: ${pelicula['anio']}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 5),
            Text('Director: ${pelicula['director']}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 5),
            Text('Género: ${pelicula['genero']}', style: const TextStyle(fontSize: 18)),
            const Divider(height: 30, thickness: 2),
            const Text('Sinopsis:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(pelicula['sinopsis'], style: const TextStyle(fontSize: 16, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. PANTALLA DE ADMINISTRACIÓN (ALTAS Y BAJAS)
// ==========================================
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tituloCtrl = TextEditingController();
  final TextEditingController _anioCtrl = TextEditingController();
  final TextEditingController _directorCtrl = TextEditingController();
  final TextEditingController _generoCtrl = TextEditingController();
  final TextEditingController _sinopsisCtrl = TextEditingController();
  final TextEditingController _imagenCtrl = TextEditingController();

  Future<void> _altaPelicula() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('peliculas').add({
        'titulo': _tituloCtrl.text,
        'anio': _anioCtrl.text,
        'director': _directorCtrl.text,
        'genero': _generoCtrl.text,
        'sinopsis': _sinopsisCtrl.text,
        'urlImagen': _imagenCtrl.text,
      });
      _formKey.currentState!.reset();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Película dada de alta')));
    }
  }

  Future<void> _bajaPelicula(String id) async {
    await FirebaseFirestore.instance.collection('peliculas').doc(id).delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Película dada de baja')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        children: [
          const Text('Alta de Película', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Expanded(
            flex: 1,
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(controller: _tituloCtrl, decoration: const InputDecoration(labelText: 'Título'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                  TextFormField(controller: _anioCtrl, decoration: const InputDecoration(labelText: 'Año'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                  TextFormField(controller: _directorCtrl, decoration: const InputDecoration(labelText: 'Director'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                  TextFormField(controller: _generoCtrl, decoration: const InputDecoration(labelText: 'Género'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                  TextFormField(controller: _sinopsisCtrl, decoration: const InputDecoration(labelText: 'Sinopsis'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                  TextFormField(controller: _imagenCtrl, decoration: const InputDecoration(labelText: 'URL de la Imagen'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _altaPelicula,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar Película'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003D12), foregroundColor: Colors.white),
                  )
                ],
              ),
            ),
          ),
          const Divider(thickness: 2),
          const Text('Baja de Películas (Desliza para borrar)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(
            flex: 1,
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('peliculas').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    return Dismissible(
                      key: Key(doc.id),
                      background: Container(color: Colors.red, alignment: Alignment.centerRight, child: const Icon(Icons.delete, color: Colors.white)),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _bajaPelicula(doc.id),
                      child: ListTile(
                        title: Text(doc['titulo']),
                        subtitle: Text(doc['anio']),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _bajaPelicula(doc.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}