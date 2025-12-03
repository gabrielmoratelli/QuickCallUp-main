import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importa os arquivos das telas que criamos
import 'login_page.dart';
import 'home_screen.dart';

Future<void> main() async {
  // Garante a inicialização
  WidgetsFlutterBinding.ensureInitialized();
  
  // Verifica o status do login
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  // Inicia o app, passando a rota inicial correta
  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      
      // 1. Define qual rota deve ser carregada primeiro
      initialRoute: isLoggedIn ? '/home' : '/login',

      // 2. Define o "mapa" de rotas do seu aplicativo
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}