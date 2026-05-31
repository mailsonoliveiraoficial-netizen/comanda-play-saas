import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _arenaNomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _cidadeController = TextEditingController();
  final TextEditingController _estadoController = TextEditingController();
  final TextEditingController _cepController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController = TextEditingController();

  bool _mostrarSenha = false;
  bool _carregando = false;

  Future<void> _cadastrarArena() async {
    if (_senhaController.text != _confirmarSenhaController.text) {
      _snack("As senhas não conferem!", Colors.red);
      return;
    }

    if (_arenaNomeController.text.isEmpty || _emailController.text.isEmpty) {
      _snack("Preencha os campos obrigatórios!", Colors.red);
      return;
    }

    setState(() => _carregando = true);

    try {
      // 1. Cria o login no Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
      );

      // --- LÓGICA DE TESTE GRÁTIS (7 DIAS) ---
      DateTime hoje = DateTime.now();
      DateTime dataVencimentoTeste = hoje.add(const Duration(days: 7));
      // ---------------------------------------

      // 2. Salva dados no Firestore na coleção 'arenas'
      await FirebaseFirestore.instance.collection('arenas').doc(userCredential.user!.uid).set({
        'nomeArena': _arenaNomeController.text.trim(),
        'email': _emailController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'cep': _cepController.text.trim(),
        'cidade': _cidadeController.text.trim(),
        'estado': _estadoController.text.trim().toUpperCase(),
        'role': 'admin', 
        'senhaSeguranca': '1234', 
        'uid': userCredential.user!.uid,
        'dataCadastro': hoje,
        
        // NOVOS CAMPOS PARA O SISTEMA DE ASSINATURA FUNCIONAR SOZINHO:
        'status_assinatura': 'teste', 
        'vencimento': dataVencimentoTeste, // O home.dart vai ler isso aqui
      });

      _snack("Arena cadastrada com sucesso! Você tem 7 dias de teste.", Colors.green);
      
      if (mounted) {
        // Redireciona ou volta para o login
        Navigator.pop(context);
      }

    } on FirebaseAuthException catch (e) {
      _snack("Erro: ${e.message}", Colors.red);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5),
      appBar: AppBar(backgroundColor: const Color(0xFF0083B0), elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.only(bottom: 30),
              decoration: const BoxDecoration(
                color: Color(0xFF0083B0), 
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(50), bottomRight: Radius.circular(50))
              ),
              child: const Column(children: [
                Icon(Icons.add_business, color: Colors.white, size: 50), 
                Text("Nova Arena", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                children: [
                  _field(_arenaNomeController, "Nome da Arena", Icons.stadium),
                  const SizedBox(height: 10),
                  _field(_emailController, "E-mail", Icons.email, type: TextInputType.emailAddress),
                  const SizedBox(height: 10),
                  _field(_whatsappController, "WhatsApp", Icons.phone, type: TextInputType.phone),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(flex: 2, child: _field(_cidadeController, "Cidade", Icons.location_city)),
                    const SizedBox(width: 10),
                    Expanded(child: _field(_estadoController, "UF", Icons.map)),
                  ]),
                  const SizedBox(height: 10),
                  _field(_cepController, "CEP", Icons.pin_drop, type: TextInputType.number),
                  const SizedBox(height: 20),
                  const Divider(),
                  _passField(_senhaController, "Senha", _mostrarSenha, () => setState(() => _mostrarSenha = !_mostrarSenha)),
                  const SizedBox(height: 10),
                  _passField(_confirmarSenhaController, "Confirmar Senha", _mostrarSenha, () => setState(() => _mostrarSenha = !_mostrarSenha)),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _cadastrarArena,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      child: _carregando 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("CONCLUIR CADASTRO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String h, IconData i, {TextInputType type = TextInputType.text}) => TextField(controller: c, keyboardType: type, decoration: InputDecoration(hintText: h, filled: true, fillColor: Colors.white, prefixIcon: Icon(i, color: const Color(0xFF0083B0)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)));
  Widget _passField(TextEditingController c, String h, bool v, VoidCallback t) => TextField(controller: c, obscureText: !v, decoration: InputDecoration(hintText: h, filled: true, fillColor: Colors.white, prefixIcon: const Icon(Icons.lock, color: Color(0xFF0083B0)), suffixIcon: IconButton(icon: Icon(v ? Icons.visibility : Icons.visibility_off), onPressed: t), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)));
}