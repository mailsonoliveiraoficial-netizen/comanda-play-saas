import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class CadastrarProdutoScreen extends StatefulWidget {
  const CadastrarProdutoScreen({super.key});

  @override
  State<CadastrarProdutoScreen> createState() => _CadastrarProdutoScreenState();
}

class _CadastrarProdutoScreenState extends State<CadastrarProdutoScreen> {
  final _nomeC = TextEditingController();
  final _precoC = TextEditingController();
  final _estoqueC = TextEditingController();
  String _catSel = 'Bebidas';
  bool _loading = false;
  
  bool _controlarEstoque = true; 

  String _userRole = 'funcionario'; 
  String _adminUid = ""; 

  final List<String> _categorias = ['Bebidas', 'Alimentos', 'Serviços', 'Outros'];

  @override
  void initState() {
    super.initState();
    _carregarVinculoEPermissoes();
  }

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

  IconData _getIcon(String cat) {
    switch (cat) {
      case 'Bebidas': return Icons.local_bar;
      case 'Alimentos': return Icons.restaurant;
      case 'Serviços': return Icons.sports_tennis;
      default: return Icons.category;
    }
  }

  Future<void> _salvar() async {
    if (_nomeC.text.isEmpty || _precoC.text.isEmpty) {
      _msg("Preencha Nome e Preço!", Colors.red);
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseFirestore.instance
          .collection('arenas').doc(_adminUid)
          .collection('produtos').add({
        'nome': _nomeC.text.trim(),
        // --- TRATAMENTO DA VÍRGULA AQUI ---
        'preco': double.tryParse(_precoC.text.replaceAll(',', '.')) ?? 0.0,
        'categoria': _catSel,
        'estoque': _controlarEstoque ? (int.tryParse(_estoqueC.text) ?? 0) : -1,
        'controlarEstoque': _controlarEstoque, 
        'data': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));

      _nomeC.clear(); _precoC.clear(); _estoqueC.clear();
      _msg("Produto cadastrado com sucesso!", Colors.green);
    } catch (e) {
      _msg("Erro ao salvar: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _editar(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    TextEditingController nEdit = TextEditingController(text: data['nome']);
    TextEditingController pEdit = TextEditingController(text: data['preco'].toString());
    String estoqueInicial = (data['estoque'] != -1) ? data['estoque'].toString() : "";
    TextEditingController eEdit = TextEditingController(text: estoqueInicial);
    String catEdit = data['categoria'] ?? 'Bebidas';
    bool controlaEdit = data['controlarEstoque'] ?? (data['estoque'] != -1);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Editar Produto", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006D92))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(nEdit, "Nome", Icons.edit),
                // --- TECLADO DECIMAL NA EDIÇÃO ---
                _buildField(pEdit, "Preço", Icons.attach_money, teclado: const TextInputType.numberWithOptions(decimal: true)),
                SwitchListTile(
                  title: const Text("Controlar Estoque?", style: TextStyle(fontSize: 14)),
                  value: controlaEdit,
                  activeThumbColor: const Color(0xFF0083B0),
                  onChanged: (v) => setDialogState(() => controlaEdit = v),
                ),
                if (controlaEdit)
                  _buildField(eEdit, "Quantidade Atual", Icons.inventory, teclado: TextInputType.number),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  initialValue: catEdit,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => catEdit = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0083B0)),
              onPressed: () async {
                await doc.reference.update({
                  'nome': nEdit.text,
                  // --- TRATAMENTO DA VÍRGULA NA EDIÇÃO ---
                  'preco': double.tryParse(pEdit.text.replaceAll(',', '.')) ?? 0.0,
                  'estoque': controlaEdit ? (int.tryParse(eEdit.text) ?? 0) : -1,
                  'controlarEstoque': controlaEdit,
                  'categoria': catEdit,
                });
                if (mounted) Navigator.pop(context);
                _msg("Produto atualizado!", Colors.blue);
              },
              child: const Text("SALVAR", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void _excluir(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Remover Produto?"),
        content: const Text("Esta ação excluirá o item permanentemente do estoque."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              doc.reference.delete();
              Navigator.pop(context);
              _msg("Produto removido!", Colors.orange);
            },
            child: const Text("EXCLUIR", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _msg(String m, Color c) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));
    }
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {TextInputType teclado = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: teclado,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF0083B0)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5),
      appBar: AppBar(
        title: const Text("Estoque da Arena", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0083B0),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
            ),
            child: Column(
              children: [
                _buildField(_nomeC, "Nome do Produto", Icons.shopping_bag_outlined),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        _precoC, 
                        "Preço Venda", 
                        Icons.payments_outlined, 
                        // --- TECLADO DECIMAL NO CADASTRO ---
                        teclado: const TextInputType.numberWithOptions(decimal: true)
                      )
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildField(
                        _estoqueC, 
                        _controlarEstoque ? "Qtd Inicial" : "Ilimitado", 
                        Icons.inventory_2_outlined, 
                        teclado: TextInputType.number
                      )
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text("Baixar estoque automaticamente?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF006D92))),
                  subtitle: Text(_controlarEstoque ? "O sistema subtrairá cada venda." : "Vendas não afetam a quantidade."),
                  value: _controlarEstoque,
                  activeThumbColor: const Color(0xFF0083B0),
                  onChanged: (v) => setState(() => _controlarEstoque = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _catSel,
                  decoration: InputDecoration(
                    labelText: "Categoria",
                    prefixIcon: const Icon(Icons.layers_outlined, color: Color(0xFF0083B0)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _catSel = v!),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _salvar,
                    icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                    label: const Text("CADASTRAR PRODUTO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF2A144),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text("ITENS EM ESTOQUE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
          ),

          Expanded(
            child: _adminUid.isEmpty 
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('arenas').doc(_adminUid)
                      .collection('produtos')
                      .orderBy('data', descending: true)
                      .snapshots(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhum item no estoque."));

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        int est = data['estoque'] ?? -1;
                        bool controla = data['controlarEstoque'] ?? (est != -1);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF0083B0).withOpacity(0.1),
                              child: Icon(_getIcon(data['categoria'] ?? 'Outros'), color: const Color(0xFF0083B0)),
                            ),
                            title: Text(data['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              "R\$ ${(data['preco'] ?? 0.0).toStringAsFixed(2)} • ${controla ? "Estoque: $est" : "Estoque: Ilimitado ∞"}"
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit_note, color: Colors.blue), onPressed: () => _editar(doc)),
                                IconButton(icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red), onPressed: () => _excluir(doc)),
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