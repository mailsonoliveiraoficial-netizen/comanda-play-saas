import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'detalhes_comanda_screen.dart';

class AbrirComandaScreen extends StatefulWidget {
  const AbrirComandaScreen({super.key});

  @override
  State<AbrirComandaScreen> createState() => _AbrirComandaScreenState();
}

class _AbrirComandaScreenState extends State<AbrirComandaScreen> {
  final _clienteController = TextEditingController();
  final _mesaController = TextEditingController();
  String? _clienteSelecionadoId; 
  bool _carregando = false;
  bool _buscandoVinculo = true; 
  
  final String uidLogado = FirebaseAuth.instance.currentUser!.uid;
  String adminUid = ""; 

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
          _buscandoVinculo = false;
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar vínculo: $e");
      setState(() => _buscandoVinculo = false);
    }
  }

  Future<void> _gerarComanda() async {
    if (_clienteController.text.isEmpty) {
      _msg("Digite o nome do cliente!", Colors.red);
      return;
    }

    if (adminUid.isEmpty) {
      _msg("Erro de sincronização. Aguarde um instante.", Colors.orange);
      return;
    }

    setState(() => _carregando = true);

    try {
      Map<String, dynamic> novaComanda = {
        'cliente': _clienteController.text.trim(),
        'clienteId': _clienteSelecionadoId,
        'mesa_quadra': _mesaController.text.trim(),
        'status': 'Aberta',
        'total': 0.0,
        'data_abertura': FieldValue.serverTimestamp(),
        'itens': [], 
        'abertaPor': uidLogado, 
        'adminUid': adminUid, // Guardamos o adminUid na comanda para facilitar buscas
      };

      DocumentReference ref = await FirebaseFirestore.instance
          .collection('arenas')
          .doc(adminUid) 
          .collection('comandas')
          .add(novaComanda)
          .timeout(const Duration(seconds: 10));

      DocumentSnapshot snapshot = await ref.get();

      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(
            builder: (c) => DetalhesComandaScreen(
              comandaDoc: snapshot,
              veioDeCriacaoNova: true,
            )
          )
        );
      }
    } on TimeoutException {
      _msg("Conexão lenta, mas a comanda será sincronizada.", Colors.orange);
    } catch (e) {
      _msg("Erro ao abrir: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _msg(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));

  @override
  Widget build(BuildContext context) {
    if (_buscandoVinculo) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5),
      appBar: AppBar(
        title: const Text("Nova Comanda", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
        backgroundColor: const Color(0xFF0083B0),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            const Icon(Icons.assignment_add, size: 80, color: Color(0xFF0083B0)),
            const SizedBox(height: 30),
            
            RawAutocomplete<Map<String, dynamic>>(
              displayStringForOption: (Map<String, dynamic> option) => option['nome'],
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.isEmpty || adminUid.isEmpty) {
                  return const Iterable<Map<String, dynamic>>.empty();
                }
                
                var snapshot = await FirebaseFirestore.instance
                    .collection('arenas')
                    .doc(adminUid) 
                    .collection('clientes')
                    .where('nome', isGreaterThanOrEqualTo: textEditingValue.text)
                    .where('nome', isLessThanOrEqualTo: '${textEditingValue.text}\uf8ff')
                    .get();

                return snapshot.docs.map((doc) => {
                  'id': doc.id,
                  'nome': doc['nome'],
                  'telefone': doc['telefone'] ?? "",
                });
              },
              onSelected: (Map<String, dynamic> selection) {
                _clienteController.text = selection['nome'];
                _clienteSelecionadoId = selection['id'];
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                if (_clienteController.text != controller.text && _clienteController.text.isNotEmpty) {
                   controller.text = _clienteController.text;
                }
                controller.addListener(() {
                  _clienteController.text = controller.text;
                  if (controller.text.isEmpty) _clienteSelecionadoId = null;
                });

                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: "Nome do Cliente",
                    hintText: "Digite para buscar...",
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF0083B0)),
                    filled: true, 
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15), 
                      borderSide: BorderSide.none
                    ),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      width: MediaQuery.of(context).size.width - 50,
                      color: Colors.white,
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                            title: Text(option['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(option['telefone']),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 15),
            
            TextField(
              controller: _mesaController,
              decoration: InputDecoration(
                labelText: "Mesa ou Quadra (Opcional)",
                prefixIcon: const Icon(Icons.stadium, color: Color(0xFF0083B0)),
                filled: true, 
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15), 
                  borderSide: BorderSide.none
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity, 
              height: 55,
              child: ElevatedButton(
                onPressed: _carregando ? null : _gerarComanda,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3DA9BE), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                ),
                child: _carregando 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "ABRIR COMANDA", 
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}