import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class DetalhesComandaScreen extends StatefulWidget {
  final DocumentSnapshot comandaDoc;
  final bool veioDeCriacaoNova;

  const DetalhesComandaScreen({
    super.key,
    required this.comandaDoc,
    this.veioDeCriacaoNova = false,
  });

  @override
  State<DetalhesComandaScreen> createState() => _DetalhesComandaScreenState();
}

class _DetalhesComandaScreenState extends State<DetalhesComandaScreen> {
  final uidLogado = FirebaseAuth.instance.currentUser!.uid;
  String adminUid = "";
  String busca = "";
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarVinculo();
  }

  Future<void> _carregarVinculo() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('arenas').doc(uidLogado).get();
      if (doc.exists) {
        String role = doc.data()?['role'] ?? 'admin';
        setState(() {
          adminUid = (role == 'admin') ? uidLogado : (doc.data()?['adminUid'] ?? uidLogado);
          _carregando = false;
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar vínculo: $e");
      setState(() => _carregando = false);
    }
  }

  DocumentReference get _comandaRefAdmin {
    return FirebaseFirestore.instance
        .collection('arenas')
        .doc(adminUid)
        .collection('comandas')
        .doc(widget.comandaDoc.id);
  }

  IconData _getIcon(String cat) {
    if (cat == 'Bebidas') return Icons.local_bar;
    if (cat == 'Alimentos') return Icons.restaurant;
    return Icons.category;
  }

  // --- LÓGICA DE ESTOQUE ---
  Future<void> _ajustarEstoqueProduto(String nomeProd, int quantidadeParaSomar) async {
    if (adminUid.isEmpty) return;
    var produtosRef = FirebaseFirestore.instance.collection('arenas').doc(adminUid).collection('produtos');
    var query = await produtosRef.where('nome', isEqualTo: nomeProd).get();
    if (query.docs.isNotEmpty) {
      var doc = query.docs.first;
      var data = doc.data();
      if (data.containsKey('estoque') && data['estoque'] != -1) {
        await doc.reference.update({'estoque': FieldValue.increment(quantidadeParaSomar)});
      }
    }
  }

  // --- LÓGICA DE ITENS ---
  void _adicionarItemAvulso() {
    final nomeController = TextEditingController();
    final valorController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Item Avulso", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: "Nome do Item"),
              textCapitalization: TextCapitalization.sentences,
            ),
            TextField(
              controller: valorController,
              decoration: const InputDecoration(labelText: "Valor (R\$)", prefixText: "R\$ "),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              double? valor = double.tryParse(valorController.text.replaceAll(',', '.'));
              if (nomeController.text.isNotEmpty && valor != null) {
                await _registrarItemManual(nomeController.text, valor);
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                }
              }
            },
            child: const Text("ADICIONAR", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _registrarItemManual(String nome, double precoUnitario) async {
    DocumentSnapshot snapComanda = await _comandaRefAdmin.get();
    List itens = List.from(snapComanda['itens'] ?? []);
    itens.add({
      'nome': nome,
      'preco': precoUnitario,
      'unitario': precoUnitario,
      'qtd': 1,
      'data': DateTime.now(),
      'avulso': true,
    });
    await _comandaRefAdmin.update({
      'itens': itens,
      'total': FieldValue.increment(precoUnitario),
      'status': 'Aberta',
    });
  }

  Future<void> _atualizarQuantidadeItem(Map<String, dynamic> itemAlvo, int alteracao) async {
    try {
      DocumentSnapshot snap = await _comandaRefAdmin.get();
      List itens = List.from(snap['itens'] ?? []);
      double totalGeral = (snap['total'] ?? 0.0).toDouble();
      int index = itens.indexWhere((i) => i['nome'] == itemAlvo['nome']);

      if (index != -1) {
        double precoUnitario = (itens[index]['unitario'] ?? 0.0).toDouble();
        int qtdAtual = itens[index]['qtd'] ?? 0;
        int novaQtd = qtdAtual + alteracao;

        if (novaQtd <= 0) {
          _solicitarSenhaExclusao(itemAlvo);
          return;
        }

        itens[index]['qtd'] = novaQtd;
        itens[index]['preco'] = precoUnitario * novaQtd;
        totalGeral += (precoUnitario * alteracao);

        await _comandaRefAdmin.update({
          'itens': itens,
          'total': totalGeral,
        });

        if (itemAlvo['avulso'] != true) {
          _ajustarEstoqueProduto(itemAlvo['nome'], -alteracao);
        }
      }
    } catch (e) {
      debugPrint("Erro ao atualizar: $e");
    }
  }

  void _solicitarSenhaExclusao(Map<String, dynamic> item) {
    final TextEditingController senhaController = TextEditingController();
    const String senhaMestre = "1234";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Acesso Restrito"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Senha do gerente para excluir:"),
            const SizedBox(height: 15),
            TextField(
              controller: senhaController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Senha",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("VOLTAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (senhaController.text == senhaMestre) {
                Navigator.pop(context);
                _removerItem(item);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Senha Incorreta!"), backgroundColor: Colors.red));
              }
            },
            child: const Text("EXCLUIR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _removerItem(Map<String, dynamic> item) async {
    try {
      double valorParaSubtrair = (item['preco'] ?? 0.0).toDouble();
      int qtdParaDevolver = item['qtd'] ?? 0;

      await _comandaRefAdmin.update({
        'itens': FieldValue.arrayRemove([item]),
        'total': FieldValue.increment(-valorParaSubtrair),
      });

      if (item['avulso'] != true) {
        _ajustarEstoqueProduto(item['nome'], qtdParaDevolver);
      }
    } catch (e) {
      debugPrint("Erro ao remover: $e");
    }
  }

  Future<void> _executarVenda(DocumentSnapshot produto, int quantidade) async {
    var d = produto.data() as Map<String, dynamic>;
    String nomeProd = d['nome'];
    double precoUnitario = (d['preco'] ?? 0.0).toDouble();
    double valorAdicionado = precoUnitario * quantidade;

    DocumentSnapshot snapComanda = await _comandaRefAdmin.get();
    List itens = List.from(snapComanda['itens'] ?? []);

    int indexExistente = itens.indexWhere((i) => i['nome'] == nomeProd);

    if (indexExistente != -1) {
      itens[indexExistente]['qtd'] += quantidade;
      itens[indexExistente]['preco'] = itens[indexExistente]['qtd'] * precoUnitario;
    } else {
      itens.add({
        'nome': nomeProd,
        'preco': valorAdicionado,
        'unitario': precoUnitario,
        'qtd': quantidade,
        'data': DateTime.now(),
        'avulso': false,
      });
    }

    await _comandaRefAdmin.update({
      'itens': itens,
      'total': FieldValue.increment(valorAdicionado),
      'status': 'Aberta',
    });

    if (d.containsKey('estoque') && d['estoque'] != -1) {
      await produto.reference.update({'estoque': FieldValue.increment(-quantidade)});
    }
  }

  // --- LÓGICA DE FINALIZAÇÃO COM DESCONTO ---

  Future<void> _finalizarPagamento(String forma, double totalLiquido, double desconto) async {
    var snap = await _comandaRefAdmin.get();
    double totalBrutoOriginal = (snap['total'] ?? 0.0).toDouble();

    await _comandaRefAdmin.update({
      'status': 'Paga',
      'forma_pagamento': forma,
      'valor_bruto': totalBrutoOriginal,
      'desconto': desconto,
      'total': totalLiquido, // O valor real que entrou no caixa
      'data_fechamento': DateTime.now(),
    });

    _atualizarFidelidadeCliente(totalLiquido);

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _atualizarFidelidadeCliente(double totalComanda) async {
    try {
      var snap = await _comandaRefAdmin.get();
      var dados = snap.data() as Map<String, dynamic>;
      String? clienteId = dados['clienteId'];

      if (clienteId != null && clienteId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('arenas')
            .doc(adminUid)
            .collection('clientes')
            .doc(clienteId)
            .update({
          'total_gasto': FieldValue.increment(totalComanda),
          'qtd_pedidos': FieldValue.increment(1),
          'ultima_visita': DateTime.now(),
        });
      }
    } catch (e) {
      debugPrint("Erro fidelidade: $e");
    }
  }

  // --- MODAL DE PAGAMENTO ATUALIZADO ---

  void _mostrarOpcoesPagamento(double totalBruto) {
    double descontoDinheiro = 0.0;
    double descontoPorcentagem = 0.0;
    double totalFinal = totalBruto;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          
          void calcular() {
            double subtotal = totalBruto - descontoDinheiro;
            double valorPercentual = subtotal * (descontoPorcentagem / 100);
            totalFinal = subtotal - valorPercentual;
            if (totalFinal < 0) totalFinal = 0;
          }

          return AlertDialog(
            backgroundColor: const Color(0xFFF2E8D5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Fechar Comanda", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Total Bruto: R\$ ${totalBruto.toStringAsFixed(2)}", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 15),
                  
                  // Campos de Desconto
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(labelText: "Desc. R\$", prefixText: "R\$ ", border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            setDialogState(() {
                              descontoDinheiro = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                              calcular();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(labelText: "Desc. %", suffixText: "%", border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            setDialogState(() {
                              descontoPorcentagem = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                              calcular();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("TOTAL A PAGAR:", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("R\$ ${totalFinal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  const Text("Selecione a Forma:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  _itemPagamentoCustom("PIX", Icons.pix, Colors.teal, () => _finalizarPagamento("PIX", totalFinal, totalBruto - totalFinal)),
                  _itemPagamentoCustom("Cartão", Icons.credit_card, Colors.blue, () => _finalizarPagamento("Cartão", totalFinal, totalBruto - totalFinal)),
                  _itemPagamentoCustom("Dinheiro", Icons.payments, Colors.green, () => _finalizarPagamento("Dinheiro", totalFinal, totalBruto - totalFinal)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _itemPagamentoCustom(String nome, IconData icone, Color cor, VoidCallback onTap) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cor.withOpacity(0.3), width: 1)
      ),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        leading: Icon(icone, color: cor),
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }

  // --- INTERFACE PRINCIPAL ---

  void _confirmarAdicao(DocumentSnapshot produto) {
    int quantidade = 1;
    var d = produto.data() as Map<String, dynamic>;
    double preco = (d['preco'] ?? 0.0).toDouble();
    int estoque = d.containsKey('estoque') ? d['estoque'] : -1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Adicionar ${d['nome']}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (estoque != -1) Text("Estoque atual: $estoque", style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 35),
                    onPressed: () { if (quantidade > 1) setDialogState(() => quantidade--); },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Text("$quantidade", style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 35),
                    onPressed: () {
                      if (estoque != -1 && quantidade >= estoque) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Limite de estoque atingido!")));
                      } else {
                        setDialogState(() => quantidade++);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text("Subtotal: R\$ ${(preco * quantidade).toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, color: Colors.blueGrey)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0083B0)),
              onPressed: () {
                _executarVenda(produto, quantidade);
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("CONFIRMAR", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void _abrirSelecaoProdutos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFFF2E8D5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25))
          ),
          child: Column(
            children: [
              const SizedBox(height: 15),
              const Text("Adicionar Item", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0083B0))),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _adicionarItemAvulso,
                    icon: const Icon(Icons.edit_note, color: Colors.white),
                    label: const Text("LANÇAR ITEM AVULSO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text("OU BUSQUE NO ESTOQUE", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Buscar produto...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
                  ),
                  onChanged: (value) => setModalState(() => busca = value.toLowerCase()),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder(
                  stream: adminUid.isEmpty ? null : FirebaseFirestore.instance.collection('arenas').doc(adminUid).collection('produtos').snapshots(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var lista = snapshot.data!.docs.where((doc) => doc['nome'].toString().toLowerCase().contains(busca)).toList();
                    
                    return ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: lista.length,
                      itemBuilder: (context, index) {
                        var p = lista[index];
                        double pPreco = (p['preco'] ?? 0.0).toDouble();
                        String cat = p['categoria'] ?? 'Outros';

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF0083B0).withOpacity(0.1),
                              child: Icon(_getIcon(cat), color: const Color(0xFF0083B0)),
                            ),
                            title: Text(p['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("R\$ ${pPreco.toStringAsFixed(2)}"),
                            trailing: const Icon(Icons.add_circle, color: Color(0xFF0083B0)),
                            onTap: () => _confirmarAdicao(p),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return StreamBuilder<DocumentSnapshot>(
      stream: _comandaRefAdmin.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        var d = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        List itens = d['itens'] ?? [];
        double total = (d['total'] ?? 0.0).toDouble();

        return Scaffold(
          backgroundColor: const Color(0xFFF2E8D5),
          appBar: AppBar(
            title: Text("${d['cliente'] ?? 'Comanda'}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF0083B0),
            iconTheme: const IconThemeData(color: Colors.white),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TOTAL:", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text("R\$ ${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0083B0))),
                  ],
                ),
              ),
              Expanded(
                child: itens.isEmpty
                ? const Center(child: Text("Nenhum item na comanda."))
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: itens.length,
                    itemBuilder: (context, index) {
                      var item = itens[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          title: Text(item['nome'] ?? "Produto", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("R\$ ${(item['unitario'] ?? 0.0).toStringAsFixed(2)} cada"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _atualizarQuantidadeItem(item, -1),
                              ),
                              Text("${item['qtd']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                onPressed: () => _atualizarQuantidadeItem(item, 1),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _abrirSelecaoProdutos,
                        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                        label: const Text("ADICIONAR PRODUTO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3DA9BE), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: widget.veioDeCriacaoNova
                        ? ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0083B0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                            child: const Text("CONCLUIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          )
                        : ElevatedButton(
                            onPressed: total > 0 ? () => _mostrarOpcoesPagamento(total) : null,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                            child: const Text("FINALIZAR E PAGAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}