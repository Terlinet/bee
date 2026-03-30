import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data';

import 'registrator.dart';
import 'bee_game.dart'; 
import 'metamask_connector.dart';

import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TerlineT Master Trader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const TerlineTPage(),
    );
  }
}

class TerlineTPage extends StatefulWidget {
  const TerlineTPage({super.key});
  @override
  State<TerlineTPage> createState() => _TerlineTPageState();
}

class _TerlineTPageState extends State<TerlineTPage> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  String _response = "";
  bool _isLoading = false;
  bool _isAgentActive = false;
  bool _showVideo = false;
  bool _hasVideoBeenShown = false; 

  String? _chartSymbol;
  String? _chartInterval;

  final List<String> _priorityWatchlist = [
    "BTC", "ETH", "BNB", "SOL", "XRP", "ADA", "DOGE", "SHIB", "AVAX", "DOT", "LINK", "TRX", "MATIC", "WBTC", "UNI", "XMR"
  ];

  late AnimationController _murmurationController;
  late AnimationController _swarmController;
  late List<BirdFlock> _flocks;
  late List<BeeParticle> _swarmParticles;

  late AudioPlayer _audioPlayer; 
  late AudioPlayer _swarmAudioPlayer; 
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isMuted = false;
  bool _speechEnabled = false;

  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  final String hfSpaceUrl = 'https://tertulianoshow-terlinet.hf.space';

  @override
  void initState() {
    super.initState();
    _murmurationController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _swarmController = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    
    _flocks = List.generate(6, (index) => BirdFlock(index));
    _swarmParticles = List.generate(3500, (index) => BeeParticle(index)); 
    
    _audioPlayer = AudioPlayer();
    _swarmAudioPlayer = AudioPlayer();
    _initSpeech();
    _initVideo();
    _setupSwarmAudio();
  }

  Future<void> _setupSwarmAudio() async {
    try {
      await _swarmAudioPlayer.setAsset('assets/beeagent.mp3');
      await _swarmAudioPlayer.setLoopMode(LoopMode.all);
    } catch (e) {
      debugPrint("Erro ao carregar som do enxame: $e");
    }
  }

  void _initVideo() {
    _videoController = VideoPlayerController.asset('assets/Trader.mp4')
      ..initialize().then((_) {
        setState(() => _isVideoInitialized = true);
        _videoController.addListener(() {
          if (_videoController.value.position >= _videoController.value.duration) {
            if (_showVideo) _closeVideo();
          }
        });
      });
  }

  void _closeVideo() {
    setState(() {
      _showVideo = false;
      _hasVideoBeenShown = true; 
      _videoController.pause();
      _videoController.seekTo(Duration.zero);
      _response = "Protocolo de orientação concluído. O Bee Agent está sincronizado. O que deseja analisar?";
    });
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    try { _speechEnabled = await _speech.initialize(); } catch (e) { debugPrint('Erro STT: $e'); }
    setState(() {});
  }

  @override
  void dispose() {
    _murmurationController.dispose();
    _swarmController.dispose();
    _controller.dispose();
    _audioPlayer.dispose();
    _swarmAudioPlayer.dispose();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    if (!_isAgentActive) return;
    if (!_speechEnabled) await _initSpeech();
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          setState(() { 
            _controller.text = result.recognizedWords; 
            if (result.finalResult) { _isListening = false; _sendQuery(); } 
          });
        }, localeId: "pt_BR");
      }
    } else { setState(() => _isListening = false); _speech.stop(); }
  }

  Future<void> _sendQuery() async {
    if (!_isAgentActive) return;
    final String userText = _controller.text;
    if (userText.isEmpty) return;
    
    _controller.clear();
    setState(() { 
      _isLoading = true; 
      _response = "O Bee está convocando o enxame..."; 
    });

    try {
      final response = await http.post(
        Uri.parse('$hfSpaceUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': userText, 
          'is_agent': true, 
          'consult_terlinet': true,
          'market_analysis': true,
          'priority_watchlist': _priorityWatchlist,
          'priority_sync': true
        }),
      ).timeout(const Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _response = data['text'] ?? "";
          _chartSymbol = data['chart_symbol'];
          _chartInterval = data['interval'] ?? "60";
          if (_chartSymbol != null && kIsWeb) {
            final String viewID = "tv-chart-${DateTime.now().millisecondsSinceEpoch}";
            final List<Map<String, String>> studiesList = [
              {"symbol": _chartSymbol!, "id": "SuperTrend@tv-basicstudies"},
              {"symbol": _chartSymbol!, "id": "PivotPointsStandard@tv-basicstudies"}
            ];
            final String indicators = jsonEncode(studiesList);
            final String url = "https://s.tradingview.com/widgetembed/?symbol=$_chartSymbol&interval=$_chartInterval&theme=dark&style=1&studies=${Uri.encodeComponent(indicators)}&hide_side_toolbar=1&details=true&withdateranges=true&show_popup_button=true&locale=pt_BR";
            registerChartWeb(viewID, url);
            _chartInterval = viewID;
          }
          if (data['audio'] != null) { _playVoice(data['audio']); }
        });
      }
    } catch (e) { setState(() => _response = "Conexão interrompida."); } 
    finally { setState(() => _isLoading = false); }
  }

  Future<void> _playVoice(String base64Audio) async {
    if (_isMuted) return;
    try {
      final Uint8List audioBytes = base64Decode(base64Audio);
      await _audioPlayer.setAudioSource(MyCustomSource(audioBytes));
      _audioPlayer.play();
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // CAMADA 1: Fundo
          Container(decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/trader.jpg'), fit: BoxFit.cover))),
          Container(color: Colors.black.withOpacity(0.5)),
          
          // CAMADA 2: Enxame (IgnorePointer garante que não bloqueie cliques)
          IgnorePointer(child: _buildSwarmOverlay()),

          // CAMADA 3: Header e Footer
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 15, left: 20),
                  child: Align(alignment: Alignment.topLeft, child: _buildHeader()),
                ),
                const Spacer(),
                _buildFooter(),
                const SizedBox(height: 10),
              ],
            ),
          ),

          // CAMADA 4: Agente e Vídeo (Posicionamento corrigido para clique certeiro)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 250), 
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_showVideo && _isVideoInitialized) _buildHolographicVideo(),
                  const SizedBox(height: 20),
                  
                  // Padding inferior empurra a hitbox para cima sem usar Transform quebrados
                  Padding(
                    padding: const EdgeInsets.only(bottom: 120),
                    child: VirtualBeeAgent(
                      isActive: _isAgentActive,
                      onTap: () {
                        if (_showVideo) {
                          _closeVideo(); 
                          setState(() => _isAgentActive = true);
                          if (!_isMuted) _swarmAudioPlayer.play();
                        } else if (_isLoading) {
                          setState(() {
                            _isLoading = false;
                            _response = "Análise interrompida. O que deseja saber?";
                          });
                        } else {
                          setState(() {
                            _isAgentActive = !_isAgentActive;
                            if (_isAgentActive) {
                              _swarmController.forward(from: 0.0);
                              if (!_isMuted) _swarmAudioPlayer.play();
                              if (!_hasVideoBeenShown) {
                                _showVideo = true;
                                _videoController.play();
                              } else {
                                _response = "Bee Agent Conectado. Analisando tendências globais de ativos...";
                              }
                            } else {
                              _showVideo = false;
                              _videoController.pause();
                              _audioPlayer.stop();
                              _swarmAudioPlayer.stop();
                              _response = "";
                              _chartSymbol = null;
                            }
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // CAMADA 5: CHAT E RESPOSTA (Sempre na frente)
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 800),
                opacity: _isAgentActive ? 1.0 : 0.0,
                child: _isAgentActive ? Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildChatInput(),
                      const SizedBox(height: 20),
                      _buildResponseArea(),
                    ],
                  ),
                ) : const SizedBox.shrink(),
              ),
            ),
          ),

          if (_chartSymbol != null) _buildChartOverlay(),
          
          // CAMADA 6: Controles de Áudio
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white10,
              onPressed: () {
                setState(() {
                  _isMuted = !_isMuted;
                  if (_isMuted) {
                    _audioPlayer.stop();
                    _swarmAudioPlayer.pause();
                  } else if (_isAgentActive) {
                    _swarmAudioPlayer.play();
                  }
                });
              },
              child: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolographicVideo() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: (MediaQuery.of(context).size.width * 0.85) * 9 / 16,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.6), width: 2),
        boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 25)]
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(aspectRatio: _videoController.value.aspectRatio, child: VideoPlayer(_videoController)),
          ),
          Positioned(
            top: 10, right: 10,
            child: GestureDetector(
              onTap: _closeVideo,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() { 
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 24), 
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.redAccent.withOpacity(0.8), width: 2),
        boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.2), blurRadius: 15)]
      ), 
      child: TextField(
        controller: _controller, 
        style: const TextStyle(color: Colors.white, fontSize: 18), 
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: 'CONSULTAR QUALQUER ATIVO (XRP, XMR, SOL...)', 
          hintStyle: TextStyle(color: Colors.redAccent.withOpacity(0.5), fontSize: 14), 
          border: InputBorder.none, 
          prefixIcon: IconButton(icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.redAccent : Colors.white), onPressed: _listen),
          suffixIcon: IconButton(icon: const Icon(Icons.send, color: Colors.redAccent), onPressed: () => _sendQuery()),
        ), 
        onSubmitted: (_) => _sendQuery()
      )
    ); 
  }

  Widget _buildResponseArea() { 
    if (_response.isEmpty) return const SizedBox.shrink(); 
    return Container(
      padding: const EdgeInsets.all(24), 
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7), 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: Colors.white.withOpacity(0.1))
      ), 
      child: SelectableText(_response, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.5))
    ); 
  }

  Widget _buildHeader() { 
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        AnimatedBuilder(
          animation: _murmurationController, 
          builder: (context, child) => CustomPaint(
            painter: MurmurationPainter(_flocks, _murmurationController.value), 
            size: const Size(260, 60)
          )
        ), 
        const Padding(
          padding: EdgeInsets.only(left: 60.0), 
          child: Row(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Text('T', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w100)), 
              SizedBox(width: 6), 
              Text('E R L I N E', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200, letterSpacing: 4)), 
              SizedBox(width: 6), 
              Text('T', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w100))
            ]
          ),
        )
      ]
    ); 
  }

  Widget _buildSwarmOverlay() {
    return AnimatedBuilder(
      animation: Listenable.merge([_swarmController, _murmurationController]),
      builder: (context, child) => CustomPaint(
        painter: SwarmPainter(_swarmParticles, _swarmController.value, _isAgentActive, _isLoading), 
        size: Size.infinite
      ),
    );
  }

  Widget _buildChartOverlay() {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.redAccent, width: 2), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Padding(padding: EdgeInsets.all(12.0), child: Text("BEE TERMINAL ANALYSIS", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))), IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _chartSymbol = null))]),
            Expanded(child: HtmlElementView(viewType: _chartInterval!)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() { return const Center(child: Text('TerlineT • Master Trader Intelligence 2024', style: TextStyle(color: Colors.white24, fontSize: 9))); }
}

class MyCustomSource extends StreamAudioSource {
  final Uint8List bytes;
  MyCustomSource(this.bytes);
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0; end ??= bytes.length;
    return StreamAudioResponse(sourceLength: bytes.length, contentLength: end - start, offset: start, stream: Stream.value(bytes.sublist(start, end)), contentType: 'audio/mpeg');
  }
}

class BeeParticle {
  final int index;
  late double orbitRadiusX, orbitRadiusY, speed, phase, scaleBase, noiseOffset, arrivalDelay;
  late double offsetPhase; 
  late double sizeFactor;
  late double startSide, startY; 

  BeeParticle(this.index) {
    final rand = math.Random();
    startSide = rand.nextBool() ? 0 : 1; 
    startY = rand.nextDouble();
    orbitRadiusX = 100 + rand.nextDouble() * 130;
    orbitRadiusY = 50 + rand.nextDouble() * 90;
    speed = 0.4 + rand.nextDouble() * 0.8;
    phase = rand.nextDouble() * 2 * math.pi;
    scaleBase = 0.12 + rand.nextDouble() * 0.18;
    noiseOffset = rand.nextDouble() * 5000;
    arrivalDelay = rand.nextDouble() * 0.8;
    offsetPhase = (index / 3500.0) * math.pi * 2; 
    sizeFactor = 0.3 + rand.nextDouble() * 0.7;
  }
}

class SwarmPainter extends CustomPainter {
  final List<BeeParticle> particles;
  final double entryValue; 
  final bool isAgent;
  final bool isLoading;
  SwarmPainter(this.particles, this.entryValue, this.isAgent, this.isLoading);

  @override
  void paint(Canvas canvas, Size size) {
    final double time = DateTime.now().millisecondsSinceEpoch / 2500.0;
    
    // Órbita ajustada para coincidir com o Agent lá no alto
    final beeAgentPos = Offset(size.width / 2, size.height / 2 - 250);

    if (!isAgent) {
      final List<Offset> points = [];
      final Paint paint = Paint()..strokeCap = StrokeCap.round;

      for (var p in particles) {
        final double individualTime = time - (p.index * 0.0002);
        final waveX = (math.sin(individualTime * 0.6) * math.cos(individualTime * 0.3) * 0.45 + 0.5) * size.width;
        final waveY = (math.cos(individualTime * 0.5) * math.sin(individualTime * 0.4) * 0.4 + 0.4) * size.height;
        final cloudDensity = math.sin(individualTime * 2 + p.index * 0.01).abs() * 20;
        final localOffset = Offset(
          math.sin(individualTime * 3 + p.noiseOffset * 0.001) * (40 + cloudDensity) * p.sizeFactor,
          math.cos(individualTime * 2.5 + p.noiseOffset * 0.001) * (30 + cloudDensity) * p.sizeFactor
        );
        points.add(Offset(waveX, waveY) + localOffset);
      }
      paint.color = Colors.yellowAccent.withOpacity(0.35);
      paint.strokeWidth = 2.2;
      canvas.drawPoints(ui.PointMode.points, points, paint);
      
    } else {
      final detailedParticles = particles.take(450).toList();
      final sortedEntries = detailedParticles.map((p) {
        final angle = (time * p.speed) + p.phase;
        return MapEntry(p, math.sin(angle));
      }).toList();
      sortedEntries.sort((a, b) => a.value.compareTo(b.value));

      for (var entry in sortedEntries) {
        final p = entry.key;
        final z = entry.value;
        final startX = p.startSide == 0 ? -200.0 : size.width + 200.0;
        final startPos = Offset(startX, p.startY * size.height);
        final multiplier = isLoading ? 2.5 : 1.0;
        final orbitTime = (time * p.speed * multiplier) + p.phase;
        final orbitPos = beeAgentPos + Offset(math.cos(orbitTime) * p.orbitRadiusX, math.sin(orbitTime) * p.orbitRadiusY);
        
        double progress = (entryValue * 2.5 - p.arrivalDelay).clamp(0.0, 1.0);
        final currentPos = Offset.lerp(startPos, orbitPos, progress)!;
        
        _drawMiniBee(canvas, currentPos, p.scaleBase * (1.3 + z * 0.5), true, orbitTime + math.pi/2, (0.4 + (z + 1) / 2 * 0.6).clamp(0.1, 1.0), z);
      }
    }
  }

  void _drawMiniBee(Canvas canvas, Offset center, double scale, bool isActive, double angle, double opacity, double z) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle + math.pi/2);
    canvas.scale(scale);
    final baseColor = isActive ? Colors.redAccent : Colors.yellowAccent;
    final secondaryColor = isActive ? Colors.red.shade900 : Colors.orange.shade800;
    final wingPaint = Paint()..color = Colors.white.withOpacity(0.4 * opacity)..style = PaintingStyle.fill;
    final wingFlap = math.sin(DateTime.now().millisecondsSinceEpoch * 0.1) * 0.8;
    canvas.save(); canvas.rotate(wingFlap - 0.4); canvas.drawOval(Rect.fromLTWH(-15, -10, 15, 8), wingPaint); canvas.restore();
    canvas.save(); canvas.rotate(-wingFlap + 0.4); canvas.drawOval(Rect.fromLTWH(0, -10, 15, 8), wingPaint); canvas.restore();
    final bodyPaint = Paint()..shader = ui.Gradient.radial(Offset.zero, 12, [Color.lerp(Colors.black, baseColor, 0.5 + (z+1)*0.25)!, Color.lerp(Colors.black, secondaryColor, 0.3 + (z+1)*0.35)!, Colors.black], const [0.2, 0.8, 1.0]);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 24, height: 18), bodyPaint);
    canvas.restore();
  }

  @override bool shouldRepaint(covariant SwarmPainter oldDelegate) => true;
}

class VirtualBeeAgent extends StatefulWidget {
  final VoidCallback onTap;
  final bool isActive;
  const VirtualBeeAgent({super.key, required this.onTap, this.isActive = false});
  @override State<VirtualBeeAgent> createState() => _VirtualBeeAgentState();
}

class _VirtualBeeAgentState extends State<VirtualBeeAgent> with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _wingController;
  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _wingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 50))..repeat(reverse: true);
  }
  @override
  void dispose() { _hoverController.dispose(); _wingController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _hoverController,
      builder: (context, child) {
        final t = _hoverController.value * 2 * math.pi;
        // O GestureDetector agora envolve a abelha em sua posição flutuante real
        return Transform.translate(
          offset: Offset(math.sin(t) * 15, math.sin(2 * t) * 10),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 130, 
              height: 130, 
              color: Colors.transparent,
              child: CustomPaint(painter: BeePainter(wingValue: _wingController.value, isActive: widget.isActive)),
            ),
          ),
        );
      },
    );
  }
}

class BeePainter extends CustomPainter {
  final double wingValue;
  final bool isActive;
  BeePainter({required this.wingValue, this.isActive = false});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final wingPaint = Paint()..color = (isActive ? Colors.redAccent : Colors.cyanAccent).withOpacity(0.3)..style = PaintingStyle.fill..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    void drawWing(double angle, bool left) {
      canvas.save(); canvas.translate(center.dx, center.dy - 5); canvas.rotate(angle + (left ? -wingValue * 0.6 : wingValue * 0.6));
      canvas.drawOval(Rect.fromCenter(center: Offset(left ? -25 : 25, -15), width: 40, height: 15), wingPaint);
      canvas.restore();
    }
    drawWing(-0.5, true); drawWing(0.5, false);
    final bodyPaint = Paint()..shader = ui.Gradient.radial(center, 25, [isActive ? Colors.redAccent : Colors.yellowAccent, isActive ? Colors.red.shade900 : Colors.orange.shade700, Colors.black], const [0.2, 0.7, 1.0]);
    if (isActive) { canvas.drawCircle(center, 25, Paint()..color = Colors.redAccent.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)); }
    canvas.drawOval(Rect.fromCenter(center: center, width: 55, height: 45), bodyPaint);
    final stripePaint = Paint()..color = Colors.black.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCenter(center: center, width: 55, height: 45), 0.5, 2.0, false, stripePaint);
    canvas.drawArc(Rect.fromCenter(center: center, width: 55, height: 45), 3.5, 2.0, false, stripePaint);
    final sensorPaint = Paint()..color = isActive ? Colors.redAccent : Colors.cyanAccent..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(center.dx + 15, center.dy - 6), 6, Paint()..color = Colors.black); 
    canvas.drawCircle(Offset(center.dx + 16, center.dy - 6), 2, sensorPaint); 
    final antPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final path = Path(); path.moveTo(center.dx + 8, center.dy - 18); path.quadraticBezierTo(center.dx + 18, center.dy - 32, center.dx + 26, center.dy - 26);
    canvas.drawPath(path, antPaint); canvas.drawCircle(Offset(center.dx + 26, center.dy - 26), 2, sensorPaint);
  }
  @override bool shouldRepaint(BeePainter oldDelegate) => true;
}

class BirdFlock { final int id; BirdFlock(this.id); }
class MurmurationPainter extends CustomPainter {
  final List<BirdFlock> flocks; final double animationValue;
  MurmurationPainter(this.flocks, this.animationValue);
  @override void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double t = DateTime.now().millisecondsSinceEpoch / 2500.0; 
    for (int i = 0; i < 50; i++) {
      final pos = center + Offset(math.sin(t + i * 0.4) * 110, math.cos(t * 0.4 + i * 0.6) * 40);
      canvas.drawCircle(pos, 1.2, Paint()..color = Colors.white.withOpacity(0.25 + (math.sin(t + i).abs() * 0.3)));
    }
  }
  @override bool shouldRepaint(covariant MurmurationPainter oldDelegate) => true;
}
