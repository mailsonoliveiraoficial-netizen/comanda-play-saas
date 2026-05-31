import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ADICIONADO: Para consultar o banco
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  
  bool _mostrarSenha = false;
  bool _carregando = false;

  // --- FUNÇÃO PARA RECUPERAR SENHA ---
  Future<void> _recuperarSenha() async {
    final TextEditingController resetEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Recuperar Senha"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enviaremos um link de redefinição para o seu e-mail."),
            const SizedBox(height: 15),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: "Digite seu e-mail",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (resetEmailController.text.isNotEmpty) {
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: resetEmailController.text.trim(),
                  );
                  if (mounted) Navigator.pop(context);
                  _mostrarMensagem("E-mail de recuperação enviado!", Colors.green);
                } catch (e) {
                  _mostrarMensagem("Erro ao enviar e-mail. Verifique o endereço.", Colors.red);
                }
              }
            },
            child: const Text("Enviar"),
          ),
        ],
      ),
    );
  }

  // --- FUNÇÃO DE LOGIN ATUALIZADA (COM CHECAGEM DE ASSINATURA) ---
  Future<void> _fazerLogin() async {
    if (_emailController.text.isEmpty || _senhaController.text.isEmpty) {
      _mostrarMensagem("Preencha todos os campos", Colors.orange);
      return;
    }

    setState(() => _carregando = true);

    try {
      // 1. Autentica no Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      // 2. Busca os dados do usuário no Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('arenas')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        throw "Usuário não encontrado no banco de dados.";
      }

      Map<String, dynamic> dados = userDoc.data() as Map<String, dynamic>;
      String role = dados['role'] ?? 'admin'; // Padrão é admin se não houver role

      // 3. Lógica de Verificação de Assinatura
      bool acessoLiberado = false;

      if (role == 'admin') {
        // Se for Admin, olha a própria assinatura
        if (dados['status_assinatura'] == 'ativo') {
          acessoLiberado = true;
        }
      } else {
        // Se for Funcionário, olha a assinatura do patrão (adminUid)
        String? adminUid = dados['adminUid'];
        if (adminUid != null && adminUid.isNotEmpty) {
          DocumentSnapshot adminDoc = await FirebaseFirestore.instance
              .collection('arenas')
              .doc(adminUid)
              .get();

          if (adminDoc.exists) {
            Map<String, dynamic> adminDados = adminDoc.data() as Map<String, dynamic>;
            if (adminDados['status_assinatura'] == 'ativo') {
              acessoLiberado = true;
            }
          }
        }
      }

      // 4. Direcionamento Final
      if (mounted) {
        if (acessoLiberado) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          // Se a assinatura não estiver ativa, você pode mandar para uma tela de erro
          // Ou mostrar essa mensagem abaixo:
          _mostrarMensagem("Acesso Bloqueado: Assinatura da Arena está inativa.", Colors.red);
          await FirebaseAuth.instance.signOut(); // Desloga para não ficar preso
        }
      }

    } on FirebaseAuthException catch (e) {
      String erro = "E-mail ou senha incorretos.";
      if (e.code == 'user-not-found') erro = "Usuário não encontrado.";
      if (e.code == 'wrong-password') erro = "Senha incorreta.";
      _mostrarMensagem(erro, Colors.red);
    } catch (e) {
      _mostrarMensagem(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mostrarMensagem(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: cor),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (O restante do seu código de UI permanece idêntico)
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 230,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF0083B0),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(50),
                  bottomRight: Radius.circular(50),
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.beach_access, color: Colors.white, size: 70),
                      SizedBox(width: 5),
                      Icon(Icons.wb_sunny, color: Colors.orange, size: 25),
                    ],
                  ),
                  Text(
                    "Comanda Play",
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const Text(
                    "Bem-vindo à sua Arena",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: "E-mail",
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.email, color: Color(0xFF0083B0)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _senhaController,
                    obscureText: !_mostrarSenha,
                    decoration: InputDecoration(
                      hintText: "Senha",
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.lock, color: Color(0xFF0083B0)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _mostrarSenha ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _recuperarSenha,
                      child: const Text(
                        "Esqueci minha senha",
                        style: TextStyle(color: Color(0xFF0083B0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _fazerLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0083B0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _carregando 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "ENTRAR",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text("OU"),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        "CADASTRAR MINHA ARENA",
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}