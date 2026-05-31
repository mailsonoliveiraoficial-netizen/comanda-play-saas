import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class CadastrarFuncionarioScreen extends StatefulWidget {
  const CadastrarFuncionarioScreen({super.key});

  @override
  State<CadastrarFuncionarioScreen> createState() => _CadastrarFuncionarioScreenState();
}

class _CadastrarFuncionarioScreenState extends State<CadastrarFuncionarioScreen> {
  final _nomeC = TextEditingController();
  final _emailC = TextEditingController();
  final _senhaC = TextEditingController();
  bool _loading = false;
  bool _senhaVisivel = false;

  Future<void> _salvar() async {
    // Validação simples
    if (_nomeC.text.trim().isEmpty || _emailC.text.trim().isEmpty || _senhaC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha todos os campos corretamente!"), backgroundColor: Colors.orange)
      );
      return;
    }

    if (_senhaC.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("A senha deve ter no mínimo 6 caracteres!"), backgroundColor: Colors.orange)
      );
      return;
    }
    
    setState(() => _loading = true);

    try {
      // 1. Pegamos o ID do administrador logado (o patrão)
      String? donoId = FirebaseAuth.instance.currentUser?.uid;
      if (donoId == null) throw "Erro: Administrador não identificado.";

      // --- TÉCNICA DE APP TEMPORÁRIO (Perfeito para não deslogar o Admin) ---
      String tempAppName = "tempApp_${DateTime.now().millisecondsSinceEpoch}";
      FirebaseApp tempApp = await Firebase.initializeApp(
        name: tempAppName,
        options: Firebase.app().options,
      );

      // 2. Criar o login no Firebase Auth (Instância secundária)
      UserCredential cred = await FirebaseAuth.instanceFor(app: tempApp).createUserWithEmailAndPassword(
        email: _emailC.text.trim(),
        password: _senhaC.text.trim(),
      );

      // 3. Salvar no Firestore com o VÍNCULO adminUid
      await FirebaseFirestore.instance.collection('arenas').doc(cred.user!.uid).set({
        'nomeFuncionario': _nomeC.text.trim(),
        'email': _emailC.text.trim(),
        'role': 'funcionario',
        'uid': cred.user!.uid,
        'adminUid': donoId, // Link fundamental para sincronizar dados
        'status_assinatura': 'ativo', 
        'dataCriacao': FieldValue.serverTimestamp(),
      });

      // 4. Encerrar app temporário
      await tempApp.delete();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Funcionário Adicionado com Sucesso!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao cadastrar: $e"), backgroundColor: Colors.red)
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5),
      appBar: AppBar(
        elevation: 0,
        title: const Text("Novo Acesso", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
        backgroundColor: const Color(0xFF0083B0),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Decorativo
            Container(
              width: double.infinity,
              color: const Color(0xFF0083B0),
              padding: const EdgeInsets.only(bottom: 30),
              child: const Column(
                children: [
                  Icon(Icons.person_add_alt_1, size: 60, color: Colors.white),
                  SizedBox(height: 10),
                  Text("Crie uma conta para seu colaborador", style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  _buildInput(_nomeC, "Nome Completo", Icons.person, false),
                  const SizedBox(height: 15),
                  _buildInput(_emailC, "E-mail de Login", Icons.email, false),
                  const SizedBox(height: 15),
                  _buildInput(_senhaC, "Senha de Acesso", Icons.lock, true),
                  const SizedBox(height: 40),
                  
                  _loading 
                    ? const CircularProgressIndicator(color: Color(0xFF0083B0))
                    : SizedBox(
                        width: double.infinity, 
                        height: 55, 
                        child: ElevatedButton(
                          onPressed: _salvar, 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF2A144), // Laranja Arena
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                          ), 
                          child: const Text("CADASTRAR FUNCIONÁRIO", 
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                        )
                      ),
                  const SizedBox(height: 20),
                  const Text("O funcionário usará este e-mail e senha para logar no sistema.", 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icone, bool isPassword) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? !_senhaVisivel : false,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Icon(icone, color: const Color(0xFF0083B0)),
          suffixIcon: isPassword 
            ? IconButton(
                icon: Icon(_senhaVisivel ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
              )
            : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}