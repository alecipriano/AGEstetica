import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({super.key});

  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends State<FinanceiroScreen> {
  String _periodoTipo = 'Mês'; // 'Mês', 'Ano', 'Personalizado'
  DateTime _referenciaMes = DateTime.now();
  int _referenciaAno = DateTime.now().year;
  DateTimeRange? _periodoPersonalizado;

  double _faturamento = 0.0;
  int _qtdAtendimentos = 0;
  List<Map<String, dynamic>> _faturamentoServicos = [];
  Map<int, double> _faturamentoMensal = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarFinanceiro();
  }

  Future<void> _carregarFinanceiro() async {
    setState(() => _isLoading = true);

    try {
      String? dataPrefixo;
      String? dataInicio;
      String? dataFim;

      if (_periodoTipo == 'Mês') {
        dataPrefixo = DateFormat('yyyy-MM').format(_referenciaMes);
      } else if (_periodoTipo == 'Ano') {
        dataPrefixo = _referenciaAno.toString();
      } else if (_periodoTipo == 'Personalizado' && _periodoPersonalizado != null) {
        dataInicio = '${DateFormat('yyyy-MM-dd').format(_periodoPersonalizado!.start)} 00:00:00';
        dataFim = '${DateFormat('yyyy-MM-dd').format(_periodoPersonalizado!.end)} 23:59:59';
      }

      final dados = await DatabaseHelper.instance.getDadosFinanceiros(
        dataPrefixo: dataPrefixo,
        dataInicio: dataInicio,
        dataFim: dataFim,
      );
      final faturamentoServicos = await DatabaseHelper.instance.getFaturamentoPorServico(
        dataPrefixo: dataPrefixo,
        dataInicio: dataInicio,
        dataFim: dataFim,
      );

      final anoInt = _periodoTipo == 'Ano'
          ? _referenciaAno
          : (_periodoTipo == 'Personalizado' && _periodoPersonalizado != null
              ? _periodoPersonalizado!.start.year
              : _referenciaMes.year);
      final faturamentoMensal = await DatabaseHelper.instance.getFaturamentoMensalPorAno(anoInt);

      if (mounted) {
        setState(() {
          _faturamento = dados['faturamento'] ?? 0.0;
          _qtdAtendimentos = dados['qtd'] ?? 0;
          _faturamentoServicos = faturamentoServicos;
          _faturamentoMensal = faturamentoMensal;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados financeiros: $e')),
        );
      }
    }
  }

  Future<void> _exportarCSV() async {
    try {
      String? dataPrefixo;
      String? dataInicio;
      String? dataFim;
      String periodoTitulo = '';

      if (_periodoTipo == 'Mês') {
        dataPrefixo = DateFormat('yyyy-MM').format(_referenciaMes);
        periodoTitulo = DateFormat('MMMM_yyyy', 'pt_BR').format(_referenciaMes);
      } else if (_periodoTipo == 'Ano') {
        dataPrefixo = _referenciaAno.toString();
        periodoTitulo = _referenciaAno.toString();
      } else if (_periodoTipo == 'Personalizado' && _periodoPersonalizado != null) {
        dataInicio = '${DateFormat('yyyy-MM-dd').format(_periodoPersonalizado!.start)} 00:00:00';
        dataFim = '${DateFormat('yyyy-MM-dd').format(_periodoPersonalizado!.end)} 23:59:59';
        final ini = DateFormat('yyyyMMdd').format(_periodoPersonalizado!.start);
        final fim = DateFormat('yyyyMMdd').format(_periodoPersonalizado!.end);
        periodoTitulo = '${ini}_a_$fim';
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecione um período personalizado válido.')),
        );
        return;
      }

      final relatorio = await DatabaseHelper.instance.getRelatorioAgendamentosPeriodo(
        dataPrefixo: dataPrefixo,
        dataInicio: dataInicio,
        dataFim: dataFim,
      );

      if (relatorio.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum dado financeiro encontrado no período selecionado.')),
        );
        return;
      }

      StringBuffer csv = StringBuffer();
      // BOM UTF-8 para compatibilidade com Excel
      csv.write('\uFEFF');
      csv.writeln('ID;Data e Hora;Cliente;Serviços;Valor Total (R\$)');
      for (var row in relatorio) {
        final id = row['id'];
        final dataHora = row['data_hora'];
        final cliente = row['cliente_nome'];
        final servicos = row['servicos'] ?? 'Nenhum';
        final valor = (row['valor_total'] as num?)?.toStringAsFixed(2) ?? '0.00';
        csv.writeln('$id;$dataHora;$cliente;$servicos;$valor');
      }

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/relatorio_financeiro_$periodoTitulo.csv';
      final file = File(path);
      await file.writeAsString(csv.toString(), encoding: utf8);

      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(path)], subject: 'Relatório Financeiro CSV');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar CSV: $e')),
      );
    }
  }

  Future<void> _exportarPDF() async {
    try {
      String? dataPrefixo;
      String? dataInicio;
      String? dataFim;
      String periodoTitulo = '';

      if (_periodoTipo == 'Mês') {
        dataPrefixo = DateFormat('yyyy-MM').format(_referenciaMes);
        final mesNome = DateFormat('MMMM yyyy', 'pt_BR').format(_referenciaMes);
        periodoTitulo = mesNome[0].toUpperCase() + mesNome.substring(1);
      } else if (_periodoTipo == 'Ano') {
        dataPrefixo = _referenciaAno.toString();
        periodoTitulo = _referenciaAno.toString();
      } else if (_periodoTipo == 'Personalizado' && _periodoPersonalizado != null) {
        dataInicio = '${DateFormat('yyyy-MM-dd').format(_periodoPersonalizado!.start)} 00:00:00';
        dataFim = '${DateFormat('yyyy-MM-dd').format(_periodoPersonalizado!.end)} 23:59:59';
        final ini = DateFormat('dd/MM/yyyy').format(_periodoPersonalizado!.start);
        final fim = DateFormat('dd/MM/yyyy').format(_periodoPersonalizado!.end);
        periodoTitulo = '$ini até $fim';
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecione um período personalizado válido.')),
        );
        return;
      }

      final relatorio = await DatabaseHelper.instance.getRelatorioAgendamentosPeriodo(
        dataPrefixo: dataPrefixo,
        dataInicio: dataInicio,
        dataFim: dataFim,
      );

      if (relatorio.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum dado financeiro encontrado no período selecionado.')),
        );
        return;
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Relatório Financeiro - Manicure Pro', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Período: $periodoTitulo', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['ID', 'Data/Hora', 'Cliente', 'Serviços', 'Valor (R\$)'],
                data: relatorio.map((row) {
                  final id = row['id'].toString();
                  String dataFormatada = row['data_hora'];
                  try {
                    final dt = DateTime.parse(row['data_hora']);
                    dataFormatada = DateFormat('dd/MM/yyyy HH:mm').format(dt);
                  } catch (_) {}

                  final cliente = row['cliente_nome'] ?? '';
                  final servicos = row['servicos'] ?? 'Nenhum';
                  final valor = (row['valor_total'] as num?)?.toStringAsFixed(2) ?? '0.00';
                  return [id, dataFormatada, cliente, servicos, 'R\$ $valor'];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellHeight: 25,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Faturamento Total: R\$ ${_faturamento.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ];
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/relatorio_financeiro_${periodoTitulo.replaceAll('/', '_').replaceAll(' ', '_')}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(path)], subject: 'Relatório Financeiro PDF');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar PDF: $e')),
      );
    }
  }

  void _mostrarSeletorMeses() {
    final meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Escolha o Mês', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final selected = _referenciaMes.month == (index + 1);
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selected ? Colors.green : Colors.black26,
                  padding: EdgeInsets.zero,
                ),
                onPressed: () {
                  setState(() {
                    _referenciaMes = DateTime(_referenciaMes.year, index + 1);
                  });
                  Navigator.pop(context);
                  _carregarFinanceiro();
                },
                child: Text(meses[index], style: const TextStyle(fontSize: 11, color: Colors.white)),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(child: _buildPeriodTypeButton('Mês')),
          Expanded(child: _buildPeriodTypeButton('Ano')),
          Expanded(child: _buildPeriodTypeButton('Personalizado')),
        ],
      ),
    );
  }

  Widget _buildPeriodTypeButton(String type) {
    final isSelected = _periodoTipo == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _periodoTipo = type;
        });
        _carregarFinanceiro();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          type == 'Personalizado' ? 'Período' : type,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildMeseSelector() {
    final String mesNome = DateFormat('MMMM yyyy', 'pt_BR').format(_referenciaMes);
    final String mesCapitalizado = mesNome[0].toUpperCase() + mesNome.substring(1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.green),
          onPressed: () {
            setState(() {
              _referenciaMes = DateTime(_referenciaMes.year, _referenciaMes.month - 1);
            });
            _carregarFinanceiro();
          },
        ),
        GestureDetector(
          onTap: _mostrarSeletorMeses,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              mesCapitalizado,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.green),
          onPressed: () {
            setState(() {
              _referenciaMes = DateTime(_referenciaMes.year, _referenciaMes.month + 1);
            });
            _carregarFinanceiro();
          },
        ),
      ],
    );
  }

  Widget _buildAnoSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.green),
          onPressed: () {
            setState(() {
              _referenciaAno--;
            });
            _carregarFinanceiro();
          },
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            '$_referenciaAno',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.green),
          onPressed: () {
            setState(() {
              _referenciaAno++;
            });
            _carregarFinanceiro();
          },
        ),
      ],
    );
  }

  Widget _buildPersonalizadoSelector() {
    String label = 'Escolher Período';
    if (_periodoPersonalizado != null) {
      final ini = DateFormat('dd/MM').format(_periodoPersonalizado!.start);
      final fim = DateFormat('dd/MM').format(_periodoPersonalizado!.end);
      label = '$ini - $fim';
    }
    return ElevatedButton.icon(
      icon: const Icon(Icons.date_range, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () async {
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          initialDateRange: _periodoPersonalizado,
          locale: const Locale('pt', 'BR'),
          builder: (context, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Colors.green,
                  onPrimary: Colors.black,
                  surface: Color(0xFF1E1E1E),
                  onSurface: Colors.white,
                ),
                datePickerTheme: const DatePickerThemeData(
                  rangePickerHeaderHeadlineStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  headerHeadlineStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              child: child!,
            );
          },
        );
        if (range != null) {
          setState(() {
            _periodoPersonalizado = range;
          });
          _carregarFinanceiro();
        }
      },
    );
  }

  Widget _buildExportButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.table_chart, color: Colors.black),
            label: const Text('Excel (CSV)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _exportarCSV,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text('PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _exportarPDF,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardGrafico() {
    if (_faturamentoMensal.isEmpty) return const SizedBox.shrink();

    final maxFaturamento = _faturamentoMensal.values.fold(0.0, (max, val) => val > max ? val : max);

    final mesesAbrev = {
      1: 'Jan', 2: 'Fev', 3: 'Mar', 4: 'Abr', 5: 'Mai', 6: 'Jun',
      7: 'Jul', 8: 'Ago', 9: 'Set', 10: 'Out', 11: 'Nov', 12: 'Dez'
    };

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Faturamento por Mês',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Ano: ${_periodoTipo == 'Ano' ? _referenciaAno : (_periodoTipo == 'Personalizado' && _periodoPersonalizado != null ? _periodoPersonalizado!.start.year : _referenciaMes.year)}',
                  style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(12, (index) {
                  final mes = index + 1;
                  final valor = _faturamentoMensal[mes] ?? 0.0;
                  final double barHeight = maxFaturamento > 0 ? (valor / maxFaturamento) * 90 : 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          valor > 0
                              ? (valor >= 1000
                                  ? 'R\$ ${(valor / 1000).toStringAsFixed(1)}k'
                                  : 'R\$ ${valor.toStringAsFixed(0)}')
                              : '',
                          style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 14,
                          height: barHeight < 4 && valor > 0 ? 4 : barHeight,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.deepPurple, Colors.green],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          mesesAbrev[mes] ?? '',
                          style: TextStyle(
                            color: valor > 0 ? Colors.white : Colors.white38,
                            fontSize: 10,
                            fontWeight: valor > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketMedio = _qtdAtendimentos > 0 ? _faturamento / _qtdAtendimentos : 0.0;
    final isSmallScreen = MediaQuery.of(context).size.width < 400;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Financeiro'),
        backgroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 80.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPeriodTypeSelector(),
                    const SizedBox(height: 12),
                    Center(
                      child: _periodoTipo == 'Mês'
                          ? _buildMeseSelector()
                          : (_periodoTipo == 'Ano' ? _buildAnoSelector() : _buildPersonalizadoSelector()),
                    ),
                    const SizedBox(height: 16),
                    _buildExportButtons(),
                    const SizedBox(height: 24),

                    // Card de Faturamento
                    _buildDashboardCard(
                      title: 'Faturamento',
                      value: 'R\$ ${_faturamento.toStringAsFixed(2)}',
                      icon: Icons.attach_money,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),

                    // Atendimentos e Ticket Médio (Responsivos)
                    if (isSmallScreen) ...[
                      // Layout empilhado
                      _buildDashboardCard(
                        title: 'Atendimentos',
                        value: '$_qtdAtendimentos',
                        icon: Icons.check_circle_outline,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(height: 16),
                      _buildDashboardCard(
                        title: 'Ticket Médio',
                        value: 'R\$ ${ticketMedio.toStringAsFixed(2)}',
                        icon: Icons.analytics_outlined,
                        color: Colors.orange,
                      ),
                    ] else ...[
                      // Layout lado a lado
                      Row(
                        children: [
                          Expanded(
                            child: _buildDashboardCard(
                              title: 'Atendimentos',
                              value: '$_qtdAtendimentos',
                              icon: Icons.check_circle_outline,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDashboardCard(
                              title: 'Ticket Médio',
                              value: 'R\$ ${ticketMedio.toStringAsFixed(2)}',
                              icon: Icons.analytics_outlined,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildDashboardGrafico(),
                    const SizedBox(height: 24),
                    const Text(
                      'Desempenho por Serviço',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_faturamentoServicos.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'Nenhum serviço concluído neste período.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _faturamentoServicos.length,
                        itemBuilder: (context, index) {
                          final serv = _faturamentoServicos[index];
                          final nome = serv['nome'] ?? 'Desconhecido';
                          final qtd = serv['quantidade'] ?? 0;
                          final total = (serv['total'] as num?)?.toDouble() ?? 0.0;

                          return Card(
                            color: const Color(0xFF1E1E1E),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.deepPurple,
                                child: Icon(Icons.spa, color: Colors.white),
                              ),
                              title: Text(
                                nome,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '$qtd ${qtd == 1 ? "atendimento" : "atendimentos"}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: Text(
                                'R\$ ${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDashboardCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
