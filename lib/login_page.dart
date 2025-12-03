import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final List<Map<String, dynamic>> _listaDeUsuarios = [
    {
      'matricula': '1001',
      'usuario': 'ana.silva',
      'senha': 'senha1',
      'latitude': -26.3036798, 
      'longitude': -48.8505007
    },
    {
      'matricula': '1002',
      'usuario': 'bruno.santos',
      'senha': 'senha2',
      'latitude': -26.3036798, 
      'longitude': -48.8505007
    },
    {
      'matricula': '1003',
      'usuario': 'carla.gomes',
      'senha': 'senha3',
      'latitude': -26.3036798,
      'longitude': -48.8505007
    },
  ];

  final TextEditingController _matriculaController = TextEditingController();
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  // 2. Função de Login ATUALIZADA
  Future<void> _fazerLogin() async {
    final String matriculaDigitada = _matriculaController.text;
    final String usuarioDigitado = _usuarioController.text;
    final String senhaDigitada = _senhaController.text;

    Map<String, dynamic>? usuarioLogado; // Armazena os dados do usuário

    for (var usuario in _listaDeUsuarios) {
      if (usuario['matricula'] == matriculaDigitada &&
          usuario['usuario'] == usuarioDigitado &&
          usuario['senha'] == senhaDigitada) {
        usuarioLogado = usuario;
        break;
      }
    }

    if (usuarioLogado != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setBool('isLoggedIn', true);
      await prefs.setDouble('user_latitude', usuarioLogado['latitude']);
      await prefs.setDouble('user_longitude', usuarioLogado['longitude']);
      await prefs.setString('user_name', usuarioLogado['usuario']); 

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Matrícula, usuário ou senha incorretos.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _matriculaController.dispose();
    _usuarioController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login de Estudante')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _matriculaController,
                  decoration: const InputDecoration(
                    labelText: 'Matrícula',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.school),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _usuarioController,
                  decoration: const InputDecoration(
                    labelText: 'Usuário',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _senhaController,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _fazerLogin,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}