import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const FilaAcougueApp());
}

class FilaAcougueApp extends StatelessWidget {
  const FilaAcougueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fila de Encomendas',
      home: const TelaFila(),
    );
  }
}

class TelaFila extends StatefulWidget {
  const TelaFila({super.key});

  @override
  State<TelaFila> createState() => _TelaFilaState();
}

class _TelaFilaState extends State<TelaFila> {
  late final WebViewController _controller;
  final stt.SpeechToText _speech = stt.SpeechToText();

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterContatos',
        onMessageReceived: (msg) async {
          await _escolherContato();
        },
      )
      ..addJavaScriptChannel(
        'FlutterVoz',
        onMessageReceived: (msg) async {
          if (msg.message == 'iniciar') {
            await _iniciarEscuta();
          } else {
            await _speech.stop();
          }
        },
      )
      ..loadFlutterAsset('assets/pedidos-acougue.html');
  }

  Future<void> _escolherContato() async {
    final permitido = await Permission.contacts.request();
    if (!permitido.isGranted) return;
    final contato = await FlutterContacts.openExternalPick();
    if (contato == null) return;
    final completo = await FlutterContacts.getContact(contato.id);
    if (completo == null) return;
    final nome = completo.displayName;
    final telefone =
        completo.phones.isNotEmpty ? completo.phones.first.number : '';
    final nomeJs = nome.replaceAll("'", "\\'");
    final telJs = telefone.replaceAll("'", "\\'");
    _controller.runJavaScript("window.receberContato('$nomeJs', '$telJs')");
  }

  Future<void> _iniciarEscuta() async {
    final permitido = await Permission.microphone.request();
    if (!permitido.isGranted) return;
    final disponivel = await _speech.initialize();
    if (!disponivel) return;
    _speech.listen(
      localeId: 'pt_BR',
      onResult: (resultado) {
        final texto = resultado.recognizedWords.replaceAll("'", "\\'");
        final ehFinal = resultado.finalResult ? 'true' : 'false';
        _controller.runJavaScript(
          "window.receberTranscricao && window.receberTranscricao('$texto', $ehFinal)",
        );
      },
      onSoundLevelChange: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
