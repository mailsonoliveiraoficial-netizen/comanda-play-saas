import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // --- ADICIONADO PARA RECARREGAR O WEBAPP ---
import 'fechamento_caixa_screen.dart'; 

// --- (TELA DE BLOQUEIO MANTIDA IGUAL) ---
class TelaBloqueio extends StatelessWidget {
  final String? nomeDaArena; 
  const TelaBloqueio({super.key, this.nomeDaArena});

  void _abrirWhatsApp(String plano, String preco) async {
    String seuNumero = "5567981334950"; 
    String arenaDesc = nomeDaArena != null ? "da arena $nomeDaArena" : "";
    String mensagem = "Olá! Gostaria de renovar a assinatura $arenaDesc. Escolhi o $plano ($preco).";
    
    final Uri url = Uri.parse("https://wa.me/$seuNumero?text=${Uri.encodeComponent(mensagem)}");
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Erro ao abrir link: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: Column(
          children: [
            const Icon(Icons.lock_clock, size: 80, color: Color(0xFFF2A144)),
            const SizedBox(height: 20),
            const Text(
              "Renove a assinatura", 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF006D92)),
            ),
            const SizedBox(height: 10),
            Text(
              nomeDaArena != null 
                ? "O acesso da $nomeDaArena precisa ser renovado para continuar operando." 
                : "Seu período de acesso terminou. Escolha um plano abaixo para liberar agora:",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 30),
            
            _cardPlano(
              context,
              titulo: "PLANO MENSAL",
              preco: "R\$ 89,90",
              detalhe: "Pagamento mês a mês",
              cor: const Color(0xFF3DA9BE),
              onTap: () => _abrirWhatsApp("Plano Mensal", "R\$ 89,90"),
            ),
            _cardPlano(
              context,
              titulo: "PLANO TRIMESTRAL",
              preco: "R\$ 239,70",
              detalhe: "Equivale a R\$ 79,90/mês",
              badge: "MAIS POPULAR",
              cor: const Color(0xFF0083B0),
              onTap: () => _abrirWhatsApp("Plano Trimestral", "R\$ 239,70"),
            ),
            _cardPlano(
              context,
              titulo: "PLANO ANUAL",
              preco: "R\$ 718,80",
              detalhe: "Equivale a R\$ 59,90/mês",
              badge: "MELHOR DESCONTO (33%)",
              cor: const Color(0xFFF2A144),
              isDestaque: true,
              onTap: () => _abrirWhatsApp("Plano Anual", "R\$ 718,80"),
            ),
            
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text("Sair da conta", style: TextStyle(color: Colors.grey)),
            )
          ],
        ),
      ),
    );
  }

  Widget _cardPlano(BuildContext context, {
    required String titulo, 
    required String preco, 
    required String detalhe, 
    required Color cor, 
    required VoidCallback onTap,
    String? badge,
    bool isDestaque = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDestaque ? Border.all(color: cor, width: 3) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(5)),
                child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: cor)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(preco, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(detalhe, style: const TextStyle(color: Colors.grey)),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: cor),
        onTap: onTap,
      ),
    );
  }
}

// --- TELA INICIAL (HOME) ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String nomeArena = "Carregando...";
  String role = "funcionario";
  String adminUid = ""; 
  bool _carregando = true;
  bool _valoresOcultos = true;
  final String uidLogado = FirebaseAuth.instance.currentUser?.uid ?? "";

  // --- ADICIONADO: CONTROLE DE VERSÃO ---
  final String versaoApp = "1.0.5"; 

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  // --- ADICIONADO: FUNÇÃO PARA RECARREGAR O APP ---
  void _sincronizarAtualizacao() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Buscando atualizações no servidor..."),
        backgroundColor: Color(0xFF0083B0),
        duration: Duration(seconds: 2),
      ),
    );
    
    // Pequeno delay para o usuário ver a mensagem e o app recarregar
    Future.delayed(const Duration(seconds: 2), () {
      html.window.location.reload(); // Comando que limpa e recarrega a página
    });
  }

  Future<void> _carregarDadosIniciais() async {
    if (uidLogado.isNotEmpty) {
      try {
        var doc = await FirebaseFirestore.instance.collection('arenas').doc(uidLogado).get();
        if (doc.exists && mounted) {
          var dados = doc.data();
          setState(() {
            role = dados?['role'] ?? "funcionario";
            nomeArena = dados?['nomeArena'] ?? "Minha Arena";
            adminUid = (role == 'admin') ? uidLogado : (dados?['adminUid'] ?? "");
            _carregando = false;
          });
        }
      } catch (e) {
        debugPrint("Erro ao carregar dados: $e");
      }
    }
  }

  void _toggleVisibilidadeValores() {
    if (_valoresOcultos) {
      _solicitarSenhaDialog(() {
        setState(() => _valoresOcultos = false);
      });
    } else {
      setState(() => _valoresOcultos = true);
    }
  }

  void _mostrarDialogSuporte() {
    String tipo = "Suporte Online";
    TextEditingController msgController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Suporte & Sugestões", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0083B0))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Como podemos ajudar hoje?", style: TextStyle(fontSize: 13)),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: tipo,
              items: ["Suporte Online", "Sugestão de Melhoria"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => tipo = val!,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: msgController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Descreva aqui sua mensagem...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              if (msgController.text.isEmpty) return;
              String msgFinal = "*Mensagem de $tipo*\n\n${msgController.text}";
              final Uri url = Uri.parse("https://wa.me/5567981334950?text=${Uri.encodeComponent(msgFinal)}");
              await launchUrl(url, mode: LaunchMode.externalApplication);
              if (mounted) Navigator.pop(context);
            },
            child: const Text("ENVIAR WHATSAPP", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _verificarAcesso(VoidCallback? acaoPermitida) {
    if (acaoPermitida == null) return;
    if (role == 'admin') {
      acaoPermitida();
    } else {
      _solicitarSenhaDialog(acaoPermitida);
    }
  }

  void _solicitarSenhaDialog(VoidCallback sucesso) {
    TextEditingController sController = TextEditingController();
    bool verificando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Acesso Restrito"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Digite a senha de segurança definida pelo Admin.", style: TextStyle(fontSize: 12)),
              const SizedBox(height: 15),
              TextField(
                controller: sController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: "Senha Admin", border: OutlineInputBorder()),
              ),
              if (verificando) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: verificando ? null : () async {
                setDialogState(() => verificando = true);
                
                try {
                  var docAdmin = await FirebaseFirestore.instance
                      .collection('arenas')
                      .doc(adminUid.isEmpty ? uidLogado : adminUid)
                      .get(const GetOptions(source: Source.server));

                  if (docAdmin.exists) {
                    String senhaReal = docAdmin.data()?['senhaSeguranca'] ?? "1234";

                    if (sController.text == senhaReal) {
                      Navigator.pop(context);
                      sucesso();
                    } else {
                      setDialogState(() => verificando = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Senha Incorreta!"), backgroundColor: Colors.red)
                      );
                    }
                  }
                } catch (e) {
                  setDialogState(() => verificando = false);
                  debugPrint("Erro ao validar: $e");
                }
              },
              child: const Text("Confirmar"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceiroRealTime() {
    if (adminUid.isEmpty) return const SizedBox.shrink();
    
    final hoje = DateTime.now();
    final inicioDia = DateTime(hoje.year, hoje.month, hoje.day);
    final inicioMes = DateTime(hoje.year, hoje.month, 1);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('arenas').doc(adminUid).collection('comandas')
          .where('status', isEqualTo: 'Paga')
          .snapshots(),
      builder: (context, snapshot) {
        double totalGeral = 0, totalHoje = 0, totalMes = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            Map<String, dynamic> dataDoc = doc.data() as Map<String, dynamic>;
            double valor = (dataDoc['total'] ?? 0).toDouble();
            totalGeral += valor;
            Timestamp? dataFechamento = dataDoc['data_fechamento'];
            if (dataFechamento != null) {
              DateTime data = dataFechamento.toDate();
              if (data.isAfter(inicioDia)) totalHoje += valor;
              if (data.isAfter(inicioMes)) totalMes += valor;
            }
          }
        }

        return Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(20), 
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("FINANCEIRO (TOQUE PARA VER FECHAMENTO)", 
                      style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      icon: Icon(_valoresOcultos ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF0083B0), size: 18),
                      onPressed: _toggleVisibilidadeValores,
                    )
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                   onTap: () => _verificarAcesso(() {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const FechamentoCaixaScreen()));
                  }),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat("Hoje", _valoresOcultos ? "R\$ ****" : "R\$ ${totalHoje.toStringAsFixed(2)}", Icons.trending_up, Colors.green),
                      _stat("Mês", _valoresOcultos ? "R\$ ****" : "R\$ ${totalMes.toStringAsFixed(2)}", Icons.calendar_month, const Color(0xFFF2A144)),
                      _stat("Geral", _valoresOcultos ? "R\$ ****" : "R\$ ${totalGeral.toStringAsFixed(2)}", Icons.stars, const Color(0xFF006D92)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _stat(String label, String valor, IconData icone, Color cor) => Column(
    children: [
      Icon(icone, size: 22, color: cor),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      Text(valor, style: TextStyle(fontWeight: FontWeight.bold, color: cor, fontSize: 13))
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    String docStatus = (role == 'admin') ? uidLogado : adminUid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('arenas').doc(docStatus).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildScaffoldPrincipal(context, DateTime.now().add(const Duration(days: 365)));
        }

        var dadosAssinatura = snapshot.data!.data() as Map<String, dynamic>;
        Timestamp? tsVencimento = dadosAssinatura['vencimento'];
        DateTime vencimento = tsVencimento?.toDate() ?? DateTime.now().add(const Duration(days: 1));
        String nomeDaArenaLocal = dadosAssinatura['nomeArena'] ?? "Arena";

        if (DateTime.now().isAfter(vencimento)) {
          return TelaBloqueio(nomeDaArena: nomeDaArenaLocal);
        }

        return _buildScaffoldPrincipal(context, vencimento);
      },
    );
  }

  Widget _buildScaffoldPrincipal(BuildContext context, DateTime vencimento) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0083B0),
        title: Text(nomeArena, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          // --- ADICIONADO: BOTÃO DE SINCRONIZAR ATUALIZAÇÃO ---
          IconButton(
            tooltip: "Verificar Atualizações",
            icon: const Icon(Icons.sync_outlined, color: Colors.white),
            onPressed: _sincronizarAtualizacao,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => FirebaseAuth.instance.signOut().then((_) => Navigator.pushReplacementNamed(context, '/login')),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogSuporte,
        backgroundColor: const Color(0xFF0083B0),
        child: const Icon(Icons.chat_bubble, color: Colors.white),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWeb = constraints.maxWidth > 800;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 15),
                  decoration: BoxDecoration(color: const Color(0xFF006D92), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("SISTEMA ONLINE", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      Text(role == 'admin' ? "ADMINISTRADOR" : "FUNCIONÁRIO",
                        style: TextStyle(color: role == 'admin' ? Colors.orangeAccent : Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                _buildFinanceiroRealTime(),
                const SizedBox(height: 15),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: isWeb ? 4 : 2, 
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: isWeb ? 1.5 : 1.1,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildMenuCard("Abrir Comanda", Icons.add_circle_outline, const Color(0xFF3DA9BE), () => Navigator.pushNamed(context, '/abrir_comanda')),
                      _buildMenuCard("Comandas Abertas", Icons.receipt_long, const Color(0xFF3DA9BE), () => Navigator.pushNamed(context, '/comandas_abertas')),
                      _buildMenuCard("Estoque / Produtos", Icons.inventory_2_outlined, const Color(0xFFF2A144), () => _verificarAcesso(() => Navigator.pushNamed(context, '/estoque'))),
                      _buildMenuCard("Clientes", Icons.person_add_alt_1, const Color(0xFFF2A144), () => Navigator.pushNamed(context, '/clientes')),
                    ],
                  ),
                ),
                if (role == 'admin')
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity, height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/equipe'),
                            icon: const Icon(Icons.group, color: Colors.white, size: 20),
                            label: const Text("GERENCIAR EQUIPE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0083B0), 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                          ),
                        ),
                        _buildAlertaVencimento(vencimento),
                      ],
                    ),
                  ),
                
                // --- ADICIONADO: RODAPÉ COM VERSÃO ---
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    "Versão $versaoApp",
                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlertaVencimento(DateTime vencimento) {
    DateTime hoje = DateTime.now();
    int diasRestantes = vencimento.difference(hoje).inDays + 1;
    
    if (diasRestantes <= 0 || diasRestantes > 7) return const SizedBox.shrink();

    Color corAlerta = diasRestantes <= 2 ? Colors.red : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: corAlerta.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: corAlerta)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, color: corAlerta, size: 16),
          const SizedBox(width: 8),
          Text("Atenção: Seu acesso expira em $diasRestantes dias.", style: TextStyle(color: corAlerta, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildMenuCard(String titulo, IconData icone, Color cor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: cor, 
          borderRadius: BorderRadius.circular(20), 
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 32, color: Colors.white),
            const SizedBox(height: 8),
            Text(titulo, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))
          ],
        ),
      ),
    );
  }
}