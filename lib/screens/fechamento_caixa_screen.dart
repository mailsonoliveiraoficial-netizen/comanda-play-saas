import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';

class FechamentoCaixaScreen extends StatefulWidget {
  const FechamentoCaixaScreen({super.key});

  @override
  State<FechamentoCaixaScreen> createState() => _FechamentoCaixaScreenState();
}

class _FechamentoCaixaScreenState extends State<FechamentoCaixaScreen> {
  final String uidLogado = FirebaseAuth.instance.currentUser!.uid;
  
  String adminUid = ""; 
  bool _carregandoVinculo = true;

  DateTime dataSelecionada = DateTime.now();
  bool filtroMensal = false; 

  double totalPix = 0;
  double totalCartao = 0;
  double totalDinheiro = 0;
  double faturamentoTotal = 0;
  double totalDesconto = 0; // Nova variável para controle de descontos
  int totalComandas = 0;

  @override
  void initState() {
    super.initState();
    _carregarDadosArena();
  }

  Future<void> _carregarDadosArena() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('arenas').doc(uidLogado).get();
      if (doc.exists) {
        String role = doc.data()?['role'] ?? 'admin';
        setState(() {
          adminUid = (role == 'admin') ? uidLogado : (doc.data()?['adminUid'] ?? uidLogado);
          _carregandoVinculo = false;
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar vínculo: $e");
      setState(() => _carregandoVinculo = false);
    }
  }

  Future<void> _selecionarData(BuildContext context) async {
    final DateTime? colhida = await showDatePicker(
      context: context,
      initialDate: dataSelecionada,
      firstDate: DateTime(2023), 
      lastDate: DateTime.now(),   
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF0083B0)),
        ),
        child: child!,
      ),
    );
    if (colhida != null && colhida != dataSelecionada) {
      setState(() => dataSelecionada = colhida);
    }
  }

  Future<void> _enviarRelatorioEmail(List<QueryDocumentSnapshot> comandas) async {
    try {
      var arenaDoc = await FirebaseFirestore.instance.collection('arenas').doc(adminUid).get();
      String emailDono = arenaDoc.data()?['email'] ?? "";
      String nomeArena = arenaDoc.data()?['nomeArena'] ?? "Minha Arena";

      String periodo = filtroMensal 
          ? DateFormat('MMMM/yyyy').format(dataSelecionada).toUpperCase() 
          : DateFormat('dd/MM/yyyy').format(dataSelecionada);
      
      String linkPizza = "https://quickchart.io/chart?c={type:'pie',data:{labels:['Pix','Cartao','Dinheiro'],datasets:[{data:[$totalPix,$totalCartao,$totalDinheiro]}]}}";
      
      String assunto = "📊 Relatório ${filtroMensal ? 'Mensal' : 'Diário'} - $nomeArena";
      
      String corpo = "📊 RELATÓRIO DE VENDAS - $nomeArena\n";
      corpo += "📅 PERÍODO: $periodo\n";
      corpo += "----------------------------------------------\n\n";
      
      corpo += "💰 FATURAMENTO LÍQUIDO: R\$ ${faturamentoTotal.toStringAsFixed(2)}\n";
      corpo += "🔻 TOTAL DESCONTOS: R\$ ${totalDesconto.toStringAsFixed(2)}\n"; // Incluído no e-mail
      corpo += "🎫 TOTAL DE COMANDAS: $totalComandas\n\n";
      
      corpo += "📈 DISTRIBUIÇÃO FINANCEIRA:\n";
      corpo += "• Pix: R\$ ${totalPix.toStringAsFixed(2)}\n";
      corpo += "• Cartão: R\$ ${totalCartao.toStringAsFixed(2)}\n";
      corpo += "• Dinheiro: R\$ ${totalDinheiro.toStringAsFixed(2)}\n\n";

      corpo += "🖼️ VER GRÁFICO DE PIZZA (CLIQUE ABAIXO):\n$linkPizza\n\n";
      
      corpo += "----------------------------------------------\n";
      corpo += "📝 DETALHAMENTO DAS VENDAS:\n";

      for (var doc in comandas) {
        final d = doc.data() as Map<String, dynamic>;
        double valor = (d['total'] ?? 0).toDouble();
        double desc = (d['desconto'] ?? 0).toDouble();
        String infoDesc = desc > 0 ? " (Desc: R\$ ${desc.toStringAsFixed(2)})" : "";
        
        corpo += "- ${d['cliente'] ?? 'Avulso'}: R\$ ${valor.toStringAsFixed(2)}$infoDesc (${d['forma_pagamento']})\n";
      }

      corpo += "\n\nSistema Arena - Relatório Automático";

      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: emailDono,
        query: 'subject=${Uri.encodeComponent(assunto)}&body=${Uri.encodeComponent(corpo)}',
      );
      
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Erro ao gerar e-mail: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao gerar e-mail.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoVinculo) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    DateTime inicioBusca = filtroMensal 
        ? DateTime(dataSelecionada.year, dataSelecionada.month, 1) 
        : DateTime(dataSelecionada.year, dataSelecionada.month, dataSelecionada.day, 0, 0, 0);
    DateTime fimBusca = filtroMensal 
        ? DateTime(dataSelecionada.year, dataSelecionada.month + 1, 0, 23, 59, 59) 
        : DateTime(dataSelecionada.year, dataSelecionada.month, dataSelecionada.day, 23, 59, 59);

    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5), 
      appBar: AppBar(
        title: const Text("Fechamento de Caixa", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0083B0),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: () => _selecionarData(context))
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('arenas').doc(adminUid).collection('comandas')
            .where('status', isEqualTo: 'Paga')
            .where('data_fechamento', isGreaterThanOrEqualTo: inicioBusca)
            .where('data_fechamento', isLessThanOrEqualTo: fimBusca)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // Reiniciando contadores
          totalPix = 0; totalCartao = 0; totalDinheiro = 0; faturamentoTotal = 0; totalDesconto = 0;
          var docs = snapshot.data!.docs;
          totalComandas = docs.length;

          for (var doc in docs) {
            final d = doc.data() as Map<String, dynamic>;
            
            // IMPORTANTE: 'total' já é o valor com desconto.
            double valorPago = (d['total'] ?? 0).toDouble();
            double descontoDado = (d['desconto'] ?? 0).toDouble();
            
            faturamentoTotal += valorPago;
            totalDesconto += descontoDado;

            String pgto = d['forma_pagamento']?.toString().toLowerCase() ?? "";
            if (pgto.contains('pix')) totalPix += valorPago;
            else if (pgto.contains('cart')) totalCartao += valorPago;
            else totalDinheiro += valorPago;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildSeletorFiltro(),
                const SizedBox(height: 20),
                _buildHeaderData(),
                const SizedBox(height: 20),
                // Grid de Cards Principais
                Row(
                  children: [
                    _cardResumo("Faturamento", "R\$ ${faturamentoTotal.toStringAsFixed(2)}", Colors.green, Icons.monetization_on),
                    const SizedBox(width: 15),
                    _cardResumo("Descontos", "R\$ ${totalDesconto.toStringAsFixed(2)}", Colors.redAccent, Icons.trending_down),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _cardResumo("Comandas", "$totalComandas", const Color(0xFF0083B0), Icons.receipt),
                    const SizedBox(width: 15),
                    _cardResumo("Ticket Médio", "R\$ ${(totalComandas > 0 ? faturamentoTotal / totalComandas : 0).toStringAsFixed(2)}", Colors.purple, Icons.analytics),
                  ],
                ),
                const SizedBox(height: 30),
                if (totalComandas > 0) ...[
                  const Text("DISTRIBUIÇÃO DE RECEBIMENTOS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 25), 
                  _buildGrafico(),
                  const SizedBox(height: 30),
                  _buildBotaoEmail(docs),
                ] else _buildEmptyState(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSeletorFiltro() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(filtroMensal ? "Visão Mensal" : "Visão Diária", style: const TextStyle(fontWeight: FontWeight.bold)),
          Switch(
            value: filtroMensal,
            activeColor: const Color(0xFF0083B0),
            onChanged: (val) => setState(() => filtroMensal = val),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderData() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          filtroMensal ? DateFormat('MMMM / yyyy').format(dataSelecionada).toUpperCase() : DateFormat('dd/MM/yyyy').format(dataSelecionada),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF006D92)),
        ),
        const Icon(Icons.analytics_outlined, color: Color(0xFF0083B0)),
      ],
    );
  }

  Widget _cardResumo(String label, String valor, Color cor, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            Icon(icon, color: cor, size: 22),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            FittedBox(
              child: Text(valor, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cor), textAlign: TextAlign.center)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrafico() {
    double maiorValor = [totalPix, totalCartao, totalDinheiro].reduce((a, b) => a > b ? a : b);
    
    return Container(
      height: 240, 
      padding: const EdgeInsets.fromLTRB(10, 25, 10, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maiorValor == 0) ? 10 : maiorValor * 1.35,
          barTouchData: BarTouchData(
            enabled: false,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.transparent,
              tooltipPadding: EdgeInsets.zero,
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  "R\$ ${rod.toY.toStringAsFixed(2)}",
                  TextStyle(
                    color: rod.color, 
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) {
                  const style = TextStyle(fontSize: 10, fontWeight: FontWeight.bold);
                  switch (v.toInt()) {
                    case 0: return const Text("PIX", style: style);
                    case 1: return const Text("CARTÃO", style: style);
                    case 2: return const Text("DINHEIRO", style: style);
                  }
                  return const Text("");
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            _barGroup(0, totalPix, Colors.blue),
            _barGroup(1, totalCartao, Colors.orange),
            _barGroup(2, totalDinheiro, Colors.green),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double y, Color c) {
    return BarChartGroupData(
      x: x, 
      barRods: [
        BarChartRodData(
          toY: y, 
          color: c, 
          width: 25, 
          borderRadius: BorderRadius.circular(4)
        )
      ],
      showingTooltipIndicators: [0],
    );
  }

  Widget _buildBotaoEmail(List<QueryDocumentSnapshot> docs) {
    return ElevatedButton.icon(
      onPressed: () => _enviarRelatorioEmail(docs),
      icon: const Icon(Icons.mail, color: Colors.white),
      label: const Text("ENVIAR PARA E-MAIL DA ARENA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3DA9BE),
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildEmptyState() => const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text("Nenhuma venda neste período.", style: TextStyle(color: Colors.grey))));
}