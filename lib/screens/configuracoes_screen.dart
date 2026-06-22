import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../main.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _mensagemController = TextEditingController();

  String _horarioInicio = '08:00';
  String _horarioFim = '18:00';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _mensagemController.dispose();
    super.dispose();
  }

  Future<void> _carregarConfiguracoes() async {
    setState(() => _isLoading = true);
    try {
      final nome = await DatabaseHelper.instance.getConfig(
        'nome_salao',
        'Manicure Pro',
      );
      final mensagem = await DatabaseHelper.instance.getConfig(
        'modelo_mensagem_whatsapp',
        'Olá! Aqui é do {salao}. Passando para confirmar seu horário de {servicos} no dia {data} às {hora}. Confirma?',
      );
      final inicio = await DatabaseHelper.instance.getConfig(
        'horario_inicio',
        '08:00',
      );
      final fim = await DatabaseHelper.instance.getConfig(
        'horario_fim',
        '18:00',
      );

      if (mounted) {
        setState(() {
          _nomeController.text = nome;
          _mensagemController.text = mensagem;
          _horarioInicio = inicio;
          _horarioFim = fim;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar configurações: $e')),
        );
      }
    }
  }

  Future<void> _selecionarHorario(bool isInicio) async {
    final partes = (isInicio ? _horarioInicio : _horarioFim).split(':');
    final horaInicial = int.parse(partes[0]);
    final minutoInicial = int.parse(partes[1]);

    final timePicked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: horaInicial, minute: minutoInicial),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.deepPurple,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (timePicked != null) {
      final horaStr = timePicked.hour.toString().padLeft(2, '0');
      final minutoStr = timePicked.minute.toString().padLeft(2, '0');

      setState(() {
        if (isInicio) {
          _horarioInicio = '$horaStr:$minutoStr';
        } else {
          _horarioFim = '$horaStr:$minutoStr';
        }
      });
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await DatabaseHelper.instance.setConfig(
        'nome_salao',
        _nomeController.text.trim(),
      );
      await DatabaseHelper.instance.setConfig(
        'modelo_mensagem_whatsapp',
        _mensagemController.text.trim(),
      );
      await DatabaseHelper.instance.setConfig('horario_inicio', _horarioInicio);
      await DatabaseHelper.instance.setConfig('horario_fim', _horarioFim);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações salvas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar configurações: $e')),
        );
      }
    }
  }

  void _inserirTag(String tag) {
    final text = _mensagemController.text;
    final selection = _mensagemController.selection;
    int start = selection.start;
    int end = selection.end;
    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }
    final newText = text.replaceRange(start, end, tag);
    _mensagemController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + tag.length),
    );
  }

  Future<void> _exportarBackup() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fecha o banco de dados para garantir o flush de todas as transações WAL no .db e liberar bloqueios
      await DatabaseHelper.instance.close();

      final dbPath = await getDatabasesPath();
      final sourcePath = p.join(dbPath, 'manicure_v4.db');

      if (!await File(sourcePath).exists()) {
        throw Exception('Banco de dados não encontrado.');
      }

      // 2. Tenta obter o diretório de cache externo no Android para que outros apps de compartilhamento tenham acesso à leitura do arquivo
      Directory? tempDir;
      if (Platform.isAndroid) {
        try {
          final extDirs = await getExternalCacheDirectories();
          if (extDirs != null && extDirs.isNotEmpty) {
            tempDir = extDirs.first;
          }
        } catch (_) {
          // Fallback silencioso
        }
      }
      tempDir ??= await getTemporaryDirectory();

      final dataStr = DateTime.now().toIso8601String().split('T')[0];
      final backupFileName = 'backup_manicure_$dataStr.db';
      final tempBackupPath = p.join(tempDir.path, backupFileName);

      // 3. Copia o banco de dados para a pasta temporária
      await File(sourcePath).copy(tempBackupPath);

      // 4. Dispara o Share
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempBackupPath)],
          text: 'Backup do aplicativo Manicure Pro ($dataStr)',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup exportado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Garante que o banco seja reaberto e o estado seja restaurado
      try {
        await DatabaseHelper.instance.database;
      } catch (_) {}
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restaurarBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Confirmar Restauração',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Atenção: Esta ação substituirá permanentemente todos os dados atuais do aplicativo pelos dados do arquivo de backup.\n\nDeseja continuar?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Restaurar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);

      if (result == null || result.files.single.path == null) {
        setState(() => _isLoading = false);
        return;
      }

      final pickedPath = result.files.single.path!;
      final dbPath = await getDatabasesPath();
      final tempRestorePath = p.join(dbPath, 'manicure_temp_restore.db');

      // 1. Copia o arquivo selecionado para um banco de dados temporário dentro do diretório de databases do app
      // Isso evita falhas de permissão de escrita/acesso do SQLite ao tentar abrir arquivos no cache ou pastas externas
      await File(pickedPath).copy(tempRestorePath);

      // 2. Abre o banco temporário para validar a integridade das tabelas necessárias
      Database? tempDb;
      bool isValid = false;
      try {
        tempDb = await openDatabase(tempRestorePath);
        final tables = await tempDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table';",
        );
        final tableNames = tables.map((row) => row['name'] as String).toList();
        if (tableNames.contains('clientes') &&
            tableNames.contains('servicos') &&
            tableNames.contains('agendamentos') &&
            tableNames.contains('estoque')) {
          isValid = true;
        }
      } catch (e) {
        // Falha abrindo/lendo o banco temporário
      } finally {
        if (tempDb != null) {
          await tempDb.close();
        }
      }

      // 3. Se for inválido, apaga o arquivo temporário e atira exceção
      if (!isValid) {
        final f = File(tempRestorePath);
        if (await f.exists()) {
          await f.delete();
        }
        throw Exception(
          'O arquivo selecionado não é um backup de banco de dados válido do aplicativo.',
        );
      }

      // 4. Fecha a conexão principal ativa
      await DatabaseHelper.instance.close();

      final destinationPath = p.join(dbPath, 'manicure_v4.db');
      
      // 5. Remove qualquer arquivo principal e seus temporários WAL/SHM antigos antes de substituir
      final mainFile = File(destinationPath);
      final walFile = File('$destinationPath-wal');
      final shmFile = File('$destinationPath-shm');

      if (await mainFile.exists()) await mainFile.delete();
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();

      // 6. Copia o banco de dados temporário validado para o caminho oficial e depois limpa o temporário
      await File(tempRestorePath).copy(destinationPath);
      await File(tempRestorePath).delete();

      if (mounted) {
        setState(() => _isLoading = false);

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Sucesso!',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'O backup foi restaurado com sucesso! O aplicativo será reiniciado para recarregar as novas informações.',
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const MainScreen()),
                    (route) => false,
                  );
                },
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Erro',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Falha ao restaurar o banco de dados:\n$e',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Administrativo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Perfil do Estabelecimento',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Card(
                      color: const Color(0xFF1E1E1E),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _nomeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Nome do Salão / Profissional',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.deepPurple),
                            ),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Insira o nome'
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Card(
                      color: const Color(0xFF1E1E1E),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mensagem de Confirmação (WhatsApp)',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Escolha um modelo pronto abaixo para preencher em 1 clique ou personalize o seu texto:',
                              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            
                            // Modelos Prontos em 1 clique
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple.withValues(alpha: 0.15),
                                    side: const BorderSide(color: Colors.deepPurple, width: 1),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _mensagemController.text = 'Olá! Aqui é do {salao}. Passando para confirmar seu horário de {servicos} no dia {data} às {hora}. Confirma?';
                                    });
                                  },
                                  child: const Text('😊 Amigável', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                                    side: const BorderSide(color: Colors.green, width: 1),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _mensagemController.text = 'Lembrete do seu horário no {salao}: {servicos} dia {data} às {hora}. Aguardamos você!';
                                    });
                                  },
                                  child: const Text('⚡ Direta', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.withValues(alpha: 0.15),
                                    side: const BorderSide(color: Colors.blue, width: 1),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _mensagemController.text = 'Olá, {cliente}. Confirmamos seu agendamento para {servicos} no salão {salao} em {data} às {hora}. Atenciosamente.';
                                    });
                                  },
                                  child: const Text('💼 Formal', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Campo de Texto Principal
                            TextFormField(
                              controller: _mensagemController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Escreva sua mensagem...',
                                hintStyle: const TextStyle(color: Colors.white30),
                                fillColor: Colors.black26,
                                filled: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.deepPurple, width: 1)),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Insira o modelo de mensagem' : null,
                            ),
                            const SizedBox(height: 12),
                            
                            // Botões de Inserção Rápida (Chips)
                            const Text(
                              'Toque abaixo para inserir dados do agendamento no seu texto:',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ActionChip(
                                  backgroundColor: const Color(0xFF2C2C2C),
                                  side: const BorderSide(color: Colors.white12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  avatar: const Icon(Icons.person, size: 14, color: Colors.amber),
                                  label: const Text('Cliente', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  onPressed: () => _inserirTag('{cliente}'),
                                ),
                                ActionChip(
                                  backgroundColor: const Color(0xFF2C2C2C),
                                  side: const BorderSide(color: Colors.white12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  avatar: const Icon(Icons.spa, size: 14, color: Colors.green),
                                  label: const Text('Serviços', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  onPressed: () => _inserirTag('{servicos}'),
                                ),
                                ActionChip(
                                  backgroundColor: const Color(0xFF2C2C2C),
                                  side: const BorderSide(color: Colors.white12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  avatar: const Icon(Icons.calendar_today, size: 14, color: Colors.blue),
                                  label: const Text('Data', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  onPressed: () => _inserirTag('{data}'),
                                ),
                                ActionChip(
                                  backgroundColor: const Color(0xFF2C2C2C),
                                  side: const BorderSide(color: Colors.white12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  avatar: const Icon(Icons.access_time, size: 14, color: Colors.orange),
                                  label: const Text('Horário', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  onPressed: () => _inserirTag('{hora}'),
                                ),
                                ActionChip(
                                  backgroundColor: const Color(0xFF2C2C2C),
                                  side: const BorderSide(color: Colors.white12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  avatar: const Icon(Icons.store, size: 14, color: Colors.purple),
                                  label: const Text('Salão', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  onPressed: () => _inserirTag('{salao}'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      'Horário de Atendimento',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Card(
                      color: const Color(0xFF1E1E1E),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: Colors.green,
                                child: Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white,
                                ),
                              ),
                              title: const Text(
                                'Início do Atendimento',
                                style: TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                _horarioInicio,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                ),
                                onPressed: () => _selecionarHorario(true),
                                child: const Text(
                                  'Alterar',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const Divider(color: Colors.white12, height: 24),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: Colors.red,
                                child: Icon(
                                  Icons.stop_circle_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              title: const Text(
                                'Fim do Atendimento',
                                style: TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                _horarioFim,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                ),
                                onPressed: () => _selecionarHorario(false),
                                child: const Text(
                                  'Alterar',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _salvar,
                      child: const Text(
                        'Salvar Configurações',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Cópia de Segurança (Backup)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Card(
                      color: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Salve um Backup dos dados de seu aplicativo ou transfira-os para um novo dispositivo. A restauração apagará os dados locais atuais.',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _exportarBackup,
                                    icon: const Icon(
                                      Icons.share,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Exportar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _restaurarBackup,
                                    icon: const Icon(
                                      Icons.settings_backup_restore,
                                      size: 20,
                                      color: Colors.amber,
                                    ),
                                    label: const Text(
                                      'Restaurar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2C2C2C),
                                      side: const BorderSide(
                                        color: Colors.white12,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
