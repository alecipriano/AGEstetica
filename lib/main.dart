import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:decimal/decimal.dart';
import 'screens/clientes_screen.dart';
import 'screens/servicos_screen.dart';
import 'screens/agenda_screen.dart';
import 'screens/financeiro_screen.dart';
import 'screens/estoque_screen.dart';
import 'screens/configuracoes_screen.dart';
import 'database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const ManicureApp());
}

class ManicureApp extends StatelessWidget {
  const ManicureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGEstetica',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      locale: const Locale('pt', 'BR'),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.deepPurple,
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurple,
          secondary: Colors.green,
          surface: Color(0xFF1E1E1E),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          labelStyle: const TextStyle(color: Colors.white70),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.green, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white24),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String _nomeSalao = 'AGEstetica';

  final List<Widget> _screens = [
    const AgendaScreen(),
    const ClientesScreen(),
    const EstoqueScreen(),
    const ServicosScreen(showAppBar: false),
  ];

  @override
  void initState() {
    super.initState();
    _carregarNomeSalao();
  }

  Future<void> _carregarNomeSalao() async {
    final nome = await DatabaseHelper.instance.getConfig('nome_salao', 'AGEstetica');
    if (mounted) {
      setState(() {
        _nomeSalao = nome;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_nomeSalao),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF121212),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.deepPurple,
                    child: Icon(Icons.spa, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _nomeSalao,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Gestão e Agendamento',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calculate_outlined, color: Colors.deepPurple),
              title: const Text('Calculadora Rápida', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Calculadora Rápida'),
                      backgroundColor: const Color(0xFF1E1E1E),
                    ),
                    body: const CalculadoraScreen(),
                  )),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_money, color: Colors.deepPurple),
              title: const Text('Financeiro', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FinanceiroScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Colors.deepPurple),
              title: const Text('Administrativo', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ConfiguracoesScreen()),
                );
                _carregarNomeSalao();
              },
            ),
          ],
        ),
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.black,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Clientes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Estoque',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.spa_outlined),
            label: 'Serviços',
          ),
        ],
      ),
    );
  }
}

class CalculadoraScreen extends StatefulWidget {
  const CalculadoraScreen({super.key});

  @override
  State<CalculadoraScreen> createState() => _CalculadoraScreenState();
}

class _CalculadoraScreenState extends State<CalculadoraScreen> {
  final _formKey = GlobalKey<FormState>();

  final _vlrmaoController = TextEditingController();
  final _vlrpeController = TextEditingController();
  final _totalmaoController = TextEditingController();
  final _totalpeController = TextEditingController();
  final _porcentagemController = TextEditingController(text: '100');
  final _adiantamentoController = TextEditingController();

  Decimal _resultadoMao = Decimal.zero;
  Decimal _resultadoPe = Decimal.zero;
  Decimal _resultadoGeral = Decimal.zero;
  Decimal _receber = Decimal.zero;

  void _calcular() {
    if (_formKey.currentState!.validate()) {
      Decimal valorMao = Decimal.parse(_vlrmaoController.text.replaceAll(',', '.'));
      Decimal valorPe = Decimal.parse(_vlrpeController.text.replaceAll(',', '.'));
      Decimal totalMao = Decimal.parse(_totalmaoController.text.replaceAll(',', '.'));
      Decimal totalPe = Decimal.parse(_totalpeController.text.replaceAll(',', '.'));
      Decimal porcentagem = Decimal.parse(_porcentagemController.text.replaceAll(',', '.'));
      String strAdiantamento = _adiantamentoController.text.replaceAll(',', '.');
      Decimal adiantamento = strAdiantamento.isEmpty ? Decimal.zero : Decimal.parse(strAdiantamento);

      setState(() {
        _resultadoMao = totalMao * valorMao;
        _resultadoPe = totalPe * valorPe;
        _resultadoGeral = _resultadoMao + _resultadoPe;
        _receber = (_resultadoGeral * porcentagem * Decimal.parse('0.01')) - adiantamento;
      });
    }
  }

  void _limpar() {
    _vlrmaoController.clear();
    _vlrpeController.clear();
    _totalmaoController.clear();
    _totalpeController.clear();
    _porcentagemController.text = '100';
    _adiantamentoController.clear();

    setState(() {
      _resultadoMao = Decimal.zero;
      _resultadoPe = Decimal.zero;
      _resultadoGeral = Decimal.zero;
      _receber = Decimal.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTextField('Valor Mão', _vlrmaoController),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField('Valor Pé', _vlrpeController),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField('Total Mãos Feitas', _totalmaoController),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField('Total Pés Feitos', _totalpeController),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField('Porcentagem (%)', _porcentagemController),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField('Adiantamento (R\$)', _adiantamentoController, isRequired: false),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _limpar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text('LIMPAR'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _calcular,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // Botão verde
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text('CALCULAR', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.white70),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Obrigatório';
        }
        if (value != null && value.isNotEmpty) {
          final limpo = value.replaceAll(',', '.');
          try {
            Decimal.parse(limpo);
          } catch (_) {
            return 'Número inválido';
          }
        }
        return null;
      },
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        children: [
          const Text(
            'RESULTADOS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const Divider(color: Colors.white24, height: 30),
          _buildResultRow('Total Mão:', _resultadoMao),
          const SizedBox(height: 8),
          _buildResultRow('Total Pé:', _resultadoPe),
          const SizedBox(height: 8),
          _buildResultRow('Total Geral:', _resultadoGeral),
          const Divider(color: Colors.white24, height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'A RECEBER:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'R\$ ${_receber.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, Decimal value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.white70)),
        Text(
          'R\$ ${value.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _vlrmaoController.dispose();
    _vlrpeController.dispose();
    _totalmaoController.dispose();
    _totalpeController.dispose();
    _porcentagemController.dispose();
    _adiantamentoController.dispose();
    super.dispose();
  }
}
