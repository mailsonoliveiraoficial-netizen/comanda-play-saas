import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cadastrar_funcionario_screen.dart';

class GerenciarEquipeScreen extends StatefulWidget {
  const GerenciarEquipeScreen({super.key});

  @override
  State<GerenciarEquipeScreen> createState() => _GerenciarEquipeScreenState();
}

class _GerenciarEquipeScreenState extends State<GerenciarEquipeScreen> {
  // Pegamos o UID do dono logado para filtrar a lista
  final String meuAdminUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  // --- 1. FUNÇÃO PARA ALTERAR A SENHA DE SEGURANÇA ---
  void _alterarSenhaSeguranca() {
    TextEditingController novaSenhaController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Senha de Segurança", style: TextStyle(color: Color(0xFF006D92), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Esta senha será usada pelos funcionários para acessar áreas restritas.", style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: novaSenhaController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: "Nova Senha",
                hintText: "Digite a nova senha",
                border: OutlineInputBorder(),
                helperText: "Apenas números (mínimo 4)"
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0083B0)),
            onPressed: () async {
              if (novaSenhaController.text.length >= 4) {
                await FirebaseFirestore.instance
                    .collection('arenas')
                    .doc(meuAdminUid)
                    .update({'senhaSeguranca': novaSenhaController.text.trim()});
                
                if (mounted) {
                  Navigator.pop(context);
                  _mostrarSnackBar("Senha de segurança atualizada!", Colors.green);
                }
              } else {
                _mostrarSnackBar("Mínimo de 4 números!", Colors.red);
              }
            },
            child: const Text("SALVAR", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- 2. FUNÇÃO PARA EXCLUIR FUNCIONÁRIO ---
  void _excluirFuncionario(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Excluir Funcionário?"),
        content: Text("Deseja remover ${doc['nomeFuncionario']} da sua equipe? Esta ação não pode ser desfeita."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('arenas').doc(doc.id).delete();
              if (mounted) {
                Navigator.pop(context); // Fecha o Dialog
                Navigator.pop(context); // Fecha o Modal de detalhes
                _mostrarSnackBar("Funcionário removido com sucesso.", Colors.orange);
              }
            },
            child: const Text("EXCLUIR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 3. FUNÇÃO PARA EDITAR NOME DO FUNCIONÁRIO ---
  void _editarFuncionario(DocumentSnapshot doc) {
    TextEditingController nomeEditC = TextEditingController(text: doc['nomeFuncionario']);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Editar Funcionário"),
        content: TextField(
          controller: nomeEditC,
          decoration: const InputDecoration(labelText: "Nome Completo", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3DA9BE)),
            onPressed: () async {
              if (nomeEditC.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('arenas').doc(doc.id).update({
                  'nomeFuncionario': nomeEditC.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  _mostrarSnackBar("Dados atualizados!", Colors.blue);
                }
              }
            },
            child: const Text("SALVAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostrarSnackBar(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cor));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5),
      appBar: AppBar(
        title: const Text("Equipe e Segurança", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0083B0),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined, color: Colors.white),
            onPressed: _alterarSenhaSeguranca,
            tooltip: "Mudar Senha de Segurança",
          )
        ],
      ),
      body: Column(
        children: [
          // Banner Superior
          Container(
            color: const Color(0xFF0083B0),
            padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CadastrarFuncionarioScreen())),
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text("NOVO FUNCIONÁRIO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2A144), 
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
              ),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
            child: Row(
              children: [
                Icon(Icons.group, size: 18, color: Colors.grey),
                SizedBox(width: 10),
                Text("EQUIPE CADASTRADA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('arenas')
                  .where('role', isEqualTo: 'funcionario')
                  .where('adminUid', isEqualTo: meuAdminUid) 
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                if (snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.grey.withOpacity(0.3)),
                        const SizedBox(height: 10),
                        const Text("Nenhum funcionário cadastrado.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemBuilder: (context, index) {
                    var func = snapshot.data!.docs[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF3DA9BE).withOpacity(0.2), 
                          child: const Icon(Icons.person, color: Color(0xFF0083B0))
                        ),
                        title: Text(func['nomeFuncionario'] ?? 'Sem Nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(func['email'], style: const TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        onTap: () => _abrirDetalhes(context, func),
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

  // --- MODAL DE OPÇÕES ---
  void _abrirDetalhes(BuildContext context, DocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))
        ),
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text(doc['nomeFuncionario'] ?? 'Funcionário', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF006D92))),
            Text(doc['email'] ?? '', style: const TextStyle(color: Colors.grey)),
            const Divider(height: 40),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text("Editar Nome"),
              onTap: () => _editarFuncionario(doc),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Remover da Equipe"),
              onTap: () => _excluirFuncionario(doc),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}