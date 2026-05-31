import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TelaBloqueio extends StatelessWidget {
  const TelaBloqueio({super.key});

  // Função para abrir o seu WhatsApp
  void _abrirWhatsApp() async {
    String seuNumero = "5511999999999"; // <-- COLOQUE SEU NÚMERO AQUI (com DDD)
    String mensagem = "Olá! Meu acesso ao app Arena está bloqueado. Gostaria de renovar.";
    Uri url = Uri.parse("https://wa.me/$seuNumero?text=${Uri.encodeComponent(mensagem)}");
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E8D5), // O tom de bege do seu app
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_clock, size: 100, color: Color(0xFF0083B0)),
            const SizedBox(height: 30),
            const Text(
              "ASSINATURA PENDENTE",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF006D92)),
            ),
            const SizedBox(height: 15),
            const Text(
              "Para continuar gerenciando sua arena e ver seus lucros, ative seu plano mensal.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _abrirWhatsApp,
                icon: const Icon(Icons.chat, color: Colors.white),                label: const Text("ATIVAR AGORA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}