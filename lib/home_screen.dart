import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  String _statusAula = "Verificando...";
  String _statusPresenca = "";
  
  double? _latFaculdade;
  double? _lonFaculdade;
  String _nomeUsuario = "";
  bool _isLoading = true;

  final List<Map<String, dynamic>> _horariosAulas = [
    {'nome': 'Aula 1: Programação Móvel p1', 'inicio': const TimeOfDay(hour: 19, minute: 0), 'fim': const TimeOfDay(hour: 19, minute: 50)},
    {'nome': 'Aula 2: Programação Móvel p2', 'inicio': const TimeOfDay(hour: 19, minute: 51), 'fim': const TimeOfDay(hour: 20, minute: 40)},
    {'nome': 'Aula 3: Programação Móvel p3', 'inicio': const TimeOfDay(hour: 20, minute: 50), 'fim': const TimeOfDay(hour: 21, minute: 40)},
    {'nome': 'Aula 4: Programação Móvel p4', 'inicio': const TimeOfDay(hour: 21, minute: 41), 'fim': const TimeOfDay(hour: 22, minute: 30)},
  ];

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }
  
  Future<void> _carregarDadosIniciais() async {
    await _carregarDadosDoUsuario(); 
    await _resetarChecksDiarios();
    
    if (mounted) {
      setState(() { _isLoading = false; });
      _verificarStatusAula(); 
      _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _verificarStatusAula();
      });
    }
  }

  Future<void> _carregarDadosDoUsuario() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _latFaculdade = prefs.getDouble('user_latitude');
      _lonFaculdade = prefs.getDouble('user_longitude');
      _nomeUsuario = prefs.getString('user_name') ?? "Aluno";
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resetarChecksDiarios() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? ultimoReset = prefs.getInt('ultimoResetDia');
    int diaAtual = DateTime.now().day;
    if (ultimoReset == null || ultimoReset != diaAtual) {
      await prefs.setInt('ultimoResetDia', diaAtual);
      for (int i = 0; i < _horariosAulas.length; i++) {
        await prefs.remove('aula_${i}_check_realizado');
        await prefs.remove('aula_${i}_presente');
        await prefs.remove('aula_${i}_status_msg');
      }
    }
  }

  Future<bool> _verificarLocalizacao() async {
    if (_latFaculdade == null || _lonFaculdade == null) {
      debugPrint("Erro: Coordenadas do usuário não carregadas.");
      return false; 
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      debugPrint('--- LOCALIZAÇÃO DO USUÁRIO ---');
      debugPrint('Latitude: ${position.latitude}, Longitude: ${position.longitude}');
      debugPrint('---------------------------------');

      double distanceInMeters = Geolocator.distanceBetween(
        _latFaculdade!, 
        _lonFaculdade!, 
        position.latitude,
        position.longitude,
      );

      return distanceInMeters <= 500;
    } catch (e) {
      debugPrint('Erro ao pegar localização: $e');
      return false;
    }
  }

  void _verificarStatusAula() async {
    if (_isLoading) return; 

    DateTime agora = DateTime.now();
    TimeOfDay horaAtual = TimeOfDay.fromDateTime(agora);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    String statusEncontrado = "Fora do horário de aula.";
    String presencaEncontrada = "";
    double horaAtualDouble = horaAtual.hour + (horaAtual.minute / 60.0);

    for (int i = 0; i < _horariosAulas.length; i++) {
      var aula = _horariosAulas[i];
      TimeOfDay inicio = aula['inicio'];
      TimeOfDay fim = aula['fim'];
      double inicioDouble = inicio.hour + (inicio.minute / 60.0);
      double fimDouble = fim.hour + (fim.minute / 60.0);
      String prefKeyCheck = 'aula_${i}_check_realizado';
      String prefKeyPresenca = 'aula_${i}_presente';

      // Se está no horário da aula
      if (horaAtualDouble >= inicioDouble && horaAtualDouble < fimDouble) {
        statusEncontrado = "Aula atual: ${aula['nome']}";
        bool jaVerificado = prefs.getBool(prefKeyCheck) ?? false;
        
        if (jaVerificado) {
          presencaEncontrada = prefs.getString('aula_${i}_status_msg') ?? "(Ausente)";
        } else {
          presencaEncontrada = "(Verificando presença...)";
          setState(() { 
            _statusAula = statusEncontrado;
            _statusPresenca = presencaEncontrada;
          });
          
          bool estaPresente = await _verificarLocalizacao(); // Roda o GPS

          await prefs.setBool(prefKeyCheck, true); 
          await prefs.setBool(prefKeyPresenca, estaPresente);
          
          const double minutosDeTolerancia = 5.0;
          double limiteAtraso = inicioDouble + (minutosDeTolerancia / 60.0);

          if (!estaPresente) {

            presencaEncontrada = "(Ausente)";
          } else if (estaPresente && horaAtualDouble > limiteAtraso) {
            // 2. Está no local, MAS atrasado (depois das 19:05, por ex.)
            presencaEncontrada = "(Presente - Atrasado)";
          } else {
            // 3. Está no local E dentro da tolerância (antes das 19:05, por ex.)
            presencaEncontrada = "(Presença registrada)";
          }
          
          await prefs.setString('aula_${i}_status_msg', presencaEncontrada); // Salva a msg
        }
        break; 
      }
    }
    setState(() {
      _statusAula = statusEncontrado;
      _statusPresenca = presencaEncontrada;
    });
  }

  Future<void> _fazerLogout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('user_latitude');
    await prefs.remove('user_longitude');
    await prefs.remove('user_name');
    
    // Limpa os registros de presença da sessão
    for (int i = 0; i < _horariosAulas.length; i++) {
      await prefs.remove('aula_${i}_check_realizado');
      await prefs.remove('aula_${i}_presente');
      await prefs.remove('aula_${i}_status_msg'); // Limpa a msg de status
    }
    await prefs.remove('ultimoResetDia');

    _timer?.cancel();

    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // --- BUILD ATUALIZADO para a cor Laranja ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carregando...')),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Define a cor do status com base na presença
    Color corStatus = Colors.grey;
    if (_statusPresenca == "(Presença registrada)") {
      corStatus = Colors.green;
    } else if (_statusPresenca == "(Presente - Atrasado)") {
      corStatus = Colors.orange; // <-- NOVA COR
    } else if (_statusPresenca.contains("Ausente")) { 
      corStatus = Colors.red;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Painel de $_nomeUsuario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _fazerLogout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'STATUS ATUAL:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusAula,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusPresenca,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: corStatus, // <-- Cor dinâmica
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            const Text(
              'Horários de Hoje:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            
            Expanded(
              child: ListView.builder(
                itemCount: _horariosAulas.length,
                itemBuilder: (context, index) {
                  var aula = _horariosAulas[index];
                  String inicioFormatado = (aula['inicio'] as TimeOfDay).format(context);
                  String fimFormatado = (aula['fim'] as TimeOfDay).format(context);

                  return ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text(aula['nome']),
                    subtitle: Text('Horário: $inicioFormatado - $fimFormatado'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}