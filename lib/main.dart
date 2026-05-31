import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; 
import 'package:arena_comanda/screens/login_screen.dart';
import 'package:arena_comanda/screens/home_screen.dart';

// Importações para as Rotas
import 'package:arena_comanda/screens/fechamento_caixa_screen.dart';
import 'package:arena_comanda/screens/cadastrar_produto_screen.dart';
import 'package:arena_comanda/screens/abrir_comanda_screen.dart';
import 'package:arena_comanda/screens/comandas_abertas_screen.dart';
import 'package:arena_comanda/screens/cadastro_cliente_screen.dart';
import 'package:arena_comanda/screens/gerenciar_equipe_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Erro ao inicializar Firebase: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Arena Comanda',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
      ),
      // O StreamBuilder continua cuidando da segurança do login
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const HomeScreen(); 
          }
          return const LoginScreen();
        },
      ),
      // MAPA DE ROTAS: Isso permite que o F5 funcione permanecendo na página
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/abrir_comanda': (context) => const AbrirComandaScreen(),
        '/comandas_abertas': (context) => const ComandasAbertasScreen(),
        '/estoque': (context) => const CadastrarProdutoScreen(),
        '/clientes': (context) => const CadastroClienteScreen(),
        '/equipe': (context) => const GerenciarEquipeScreen(),
        '/fechamento': (context) => const FechamentoCaixaScreen(),
      },
    );
  }
}