import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Essa função vai checar se o usuário pode entrar ou não
Future<void> checarAcessoUsuario(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) return;

  // Busca os dados do usuário no banco
  final doc = await FirebaseFirestore.instance.collection('arenas').doc(user.uid).get();

  if (!doc.exists) {
    print("Usuário não encontrado no banco!");
    return;
  }

  final dados = doc.data()!;
  
  if (dados['role'] == 'admin') {
    // SE FOR ADMIN: Vai para a tela de Admin
    print("Entrando como Admin...");
    Navigator.pushReplacementNamed(context, '/home_admin'); 
  } else {
    // SE FOR FUNCIONÁRIO:
    String adminId = dados['adminUid'] ?? '';
    
    // Agora vamos ver se o patrão (admin) pagou a conta
    final docAdmin = await FirebaseFirestore.instance.collection('arenas').doc(adminId).get();
    
    if (docAdmin.exists && docAdmin.data()?['status_assinatura'] == 'ativo') {
      print("Acesso liberado pelo Admin!");
      Navigator.pushReplacementNamed(context, '/home_funcionario');
    } else {
      // Se cair aqui, a tela para de carregar e mostra o erro
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Acesso bloqueado. Verifique com o dono da Arena.")),
      );
    }
  }
}