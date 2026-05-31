import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'detalhes_comanda_screen.dart';

class ComandasAbertasScreen extends StatefulWidget {
  const ComandasAbertasScreen({super.key});

  @override
  State<ComandasAbertasScreen> createState() => _ComandasAbertasScreenState();
}

class _ComandasAbertasScreenState extends State<ComandasAbertasScreen> {
  final String uidLogado = FirebaseAuth.instance.currentUser!.uid;
  String adminUid = ""; // Onde a mágica acontece
  bool _carregandoVinculo = true;
  String _filtroNome = ""; 

  @override
  void initState() {
    super.initState();
    _buscarDonoDaConta();
  }

  // Função para garantir que funcionário e admin olhem para a mesma pasta
  Future<void> _buscarDonoDaConta() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('arenas').doc(uidLogado).get();
      if (doc.exists) {
        String role = doc.data()?['role'] ?? 'admin';
        setState(() {
          // Se for admin, usa o próprio UID. Se funcionário, usa o UID do patrão.
          adminUid = (role == 'admin') ? uidLogado : (doc.data()?['adminUid'] ?? uidLogado);
          _carregandoVinculo = false;
        });
      }
    } catch (e) {
      debugPrint("Erro ao buscar vínculo: $e");
      setState(() => _carregandoVinculo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5),
      appBar: AppBar(
        title: const Text("Comandas Ativas", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0083B0),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _carregandoVinculo 
          ? const Center(child: CircularProgressIndicator()) 
          : Column(
        children: [
          // --- CAMPO DE BUSCA ---
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: TextField(
              onChanged: (valor) {
                setState(() {
                  _filtroNome = valor.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Buscar por nome do cliente...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0083B0)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // --- LISTA DE COMANDAS ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // AQUI ESTÁ O SEGREDO: Escutando a coleção do ADMIN
              stream: FirebaseFirestore.instance
                  .collection('arenas')
                  .doc(adminUid)
                  .collection('comandas')
                  .where('status', isEqualTo: 'Aberta')
                  .orderBy('data_abertura', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Erro ao carregar comandas."));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filtramos a lista localmente com base no que foi digitado
                var listaFiltrada = snapshot.data!.docs.where((doc) {
                  var nomeCliente = doc['cliente'].toString().toLowerCase();
                  return nomeCliente.contains(_filtroNome);
                }).toList();

                if (listaFiltrada.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, size: 80, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("Nenhuma comanda encontrada.",
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: listaFiltrada.length,
                  itemBuilder: (context, index) {
                    var comanda = listaFiltrada[index];
                    var dados = comanda.data() as Map<String, dynamic>;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFF0083B0).withOpacity(0.1),
                          child:
                              const Icon(Icons.person, color: Color(0xFF0083B0)),
                        ),
                        title: Text(
                          dados['cliente'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(dados['mesa_quadra'] ?? "Geral",
                                    style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.green, width: 0.5),
                              ),
                              child: const Text("EM ABERTO",
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("TOTAL",
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                            Text(
                              "R\$ ${(dados['total'] ?? 0.0).toStringAsFixed(2)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0083B0),
                                  fontSize: 16),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetalhesComandaScreen(
                                comandaDoc: comanda,
                                veioDeCriacaoNova: false,
                              ),
                            ),
                          );
                        },
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