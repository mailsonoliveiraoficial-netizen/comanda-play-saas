import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CadastroClienteScreen extends StatefulWidget {
  const CadastroClienteScreen({super.key});

  @override
  State<CadastroClienteScreen> createState() => _CadastroClienteScreenState();
}

class _CadastroClienteScreenState extends State<CadastroClienteScreen> {
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  
  // Variáveis de Vínculo e Permissão
  String _userRole = 'funcionario'; 
  String _adminUid = ""; 
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregarVinculoEPermissoes();
  }

  // Descobre se o usuário é Admin ou Funcionário e qual o ID do "Patrão"
  Future<void> _carregarVinculoEPermissoes() async {
    final uidLogado = FirebaseAuth.instance.currentUser?.uid;
    if (uidLogado != null) {
      var doc = await FirebaseFirestore.instance.collection('arenas').doc(uidLogado).get();
      if (doc.exists && mounted) {
        setState(() {
          _userRole = doc.data()?['role'] ?? 'funcionario';
          _adminUid = (_userRole == 'admin') ? uidLogado : (doc.data()?['adminUid'] ?? "");
        });
      }
    }
  }

  // --- SALVAR CLIENTE COM VALIDAÇÃO ---
  Future<void> _salvarCliente() async {
    String nomeLimpo = _nomeController.text.trim();

    if (nomeLimpo.isEmpty) {
      _msg("Digite o nome do cliente!", Colors.red);
      return;
    }

    if (_adminUid.isEmpty) {
      _msg("Erro de vínculo. Verifique sua conexão.", Colors.red);
      return;
    }

    setState(() => _carregando = true);

    try {
      // 1. Verifica duplicidade na pasta do ADMIN
      final query = await FirebaseFirestore.instance
          .collection('arenas')
          .doc(_adminUid)
          .collection('clientes')
          .where('nome', isEqualTo: nomeLimpo)
          .get();

      if (query.docs.isNotEmpty) {
        _msg("O cliente '$nomeLimpo' já está cadastrado!", Colors.orange);
        setState(() => _carregando = false);
        return;
      }

      // 2. Salva o novo cliente
      await FirebaseFirestore.instance
          .collection('arenas')
          .doc(_adminUid)
          .collection('clientes')
          .add({
        'nome': nomeLimpo,
        'telefone': _telefoneController.text.trim(),
        'total_gasto': 0.0,
        'qtd_pedidos': 0,
        'data_cadastro': FieldValue.serverTimestamp(),
      });

      _nomeController.clear();
      _telefoneController.clear();
      _msg("Cliente cadastrado com sucesso!", Colors.green);
    } catch (e) {
      _msg("Erro ao salvar: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // --- EDITAR CLIENTE ---
  void _modalEditarCliente(String docId, String nomeAtual, String telAtual) {
    TextEditingController editNome = TextEditingController(text: nomeAtual);
    TextEditingController editTel = TextEditingController(text: telAtual);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Permite arredondar o fundo
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF2E8D5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20, left: 25, right: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("Editar Cadastro", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF006D92))),
            const SizedBox(height: 20),
            _buildField(editNome, "Nome", Icons.person),
            _buildField(editTel, "Telefone", Icons.phone, teclado: TextInputType.phone),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0083B0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('arenas').doc(_adminUid).collection('clientes').doc(docId)
                      .update({
                    'nome': editNome.text.trim(),
                    'telefone': editTel.text.trim(),
                  });
                  Navigator.pop(context);
                  _msg("Cadastro atualizado!", Colors.blue);
                },
                child: const Text("SALVAR ALTERAÇÕES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- EXCLUIR CLIENTE (PROTEGIDO) ---
  void _confirmarExclusao(String docId, String nome) {
    if (_userRole != 'admin') {
      _msg("Apenas o Administrador pode excluir clientes!", Colors.orange);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Excluir Cliente?"),
        content: Text("Isso apagará o histórico de $nome. Esta ação não pode ser desfeita."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('arenas').doc(_adminUid).collection('clientes').doc(docId).delete();
                Navigator.pop(context);
                _msg("Cliente removido.", Colors.redAccent);
              },
              child: const Text("EXCLUIR", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  void _msg(String t, [Color cor = Colors.black]) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
      ));

  Widget _buildField(TextEditingController controller, String label, IconData icon, {TextInputType teclado = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: teclado,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(icon, color: const Color(0xFF0083B0)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5),
      appBar: AppBar(
        title: const Text("Clientes & Ranking", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0083B0),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ÁREA DE CADASTRO
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0083B0),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
            ),
            child: Column(
              children: [
                _buildField(_nomeController, "Nome do Cliente", Icons.person_add),
                _buildField(_telefoneController, "Telefone", Icons.phone, teclado: TextInputType.phone),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _carregando ? null : _salvarCliente,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF2A144),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: _carregando
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("CADASTRAR CLIENTE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text("RANKING DE FIDELIDADE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF006D92))),
              SizedBox(width: 10),
              Icon(Icons.emoji_events, color: Colors.orange, size: 28),
            ],
          ),
          const SizedBox(height: 10),

          // LISTA / RANKING
          Expanded(
            child: _adminUid.isEmpty 
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('arenas').doc(_adminUid).collection('clientes')
                    .orderBy('total_gasto', descending: true)
                    .limit(20)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var clientes = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: clientes.length,
                    itemBuilder: (context, index) {
                      var cliente = clientes[index];
                      var data = cliente.data() as Map<String, dynamic>;
                      
                      // Lógica de Medalhas
                      Widget medalha;
                      if (index == 0) {
                        medalha = const Icon(Icons.workspace_premium, color: Colors.amber, size: 35);
                      } else if (index == 1) medalha = const Icon(Icons.workspace_premium, color: Color(0xFFC0C0C0), size: 30);
                      else if (index == 2) medalha = const Icon(Icons.workspace_premium, color: Color(0xFFCD7F32), size: 28);
                      else medalha = CircleAvatar(radius: 12, backgroundColor: Colors.white, child: Text("${index + 1}", style: const TextStyle(fontSize: 10, color: Colors.black)));

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: medalha,
                          title: Text(data['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Gasto Total: R\$ ${(data['total_gasto'] ?? 0.0).toStringAsFixed(2)}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _modalEditarCliente(cliente.id, data['nome'], data['telefone'] ?? "")),
                              if(_userRole == 'admin')
                                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _confirmarExclusao(cliente.id, data['nome'])),
                            ],
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