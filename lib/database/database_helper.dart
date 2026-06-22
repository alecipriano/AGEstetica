import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import '../models/cliente.dart';
import '../models/servico.dart';
import '../models/agendamento.dart';
import '../models/estoque_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Mudando o nome para criar um banco novo com as novas tabelas/colunas
    _database = await _initDB('manicure_v4.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE clientes ADD COLUMN observacoes TEXT DEFAULT ""');
          } catch (_) {
            // Ignores if column already exists
          }
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE clientes ADD COLUMN ficha_saude TEXT DEFAULT ""');
          } catch (_) {
            // Ignores if column already exists
          }
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
      CREATE TABLE clientes (
        id $idType,
        nome $textType,
        telefone $textType,
        observacoes TEXT DEFAULT "",
        ficha_saude TEXT DEFAULT ""
      )
    ''');

    await db.execute('''
      CREATE TABLE servicos (
        id $idType,
        nome $textType,
        preco $realType,
        tempo_estimado INTEGER NOT NULL DEFAULT 30
      )
    ''');

    await db.execute('''
      CREATE TABLE agendamentos (
        id $idType,
        cliente_id INTEGER NOT NULL,
        data_hora $textType,
        status $textType,
        observacao TEXT,
        duracao_minutos INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE agendamento_servicos (
        id $idType,
        agendamento_id INTEGER NOT NULL,
        servico_id INTEGER NOT NULL,
        preco_cobrado $realType,
        FOREIGN KEY (agendamento_id) REFERENCES agendamentos (id) ON DELETE CASCADE,
        FOREIGN KEY (servico_id) REFERENCES servicos (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE configuracoes (
        id $idType,
        chave TEXT NOT NULL UNIQUE,
        valor TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE estoque (
        id $idType,
        nome $textType,
        quantidade INTEGER NOT NULL,
        detalhe TEXT,
        valor $realType
      )
    ''');

    // Inserir configurações iniciais padrão
    await db.insert('configuracoes', {'chave': 'nome_salao', 'valor': 'Manicure Pro'});
    await db.insert('configuracoes', {'chave': 'horario_inicio', 'valor': '08:00'});
    await db.insert('configuracoes', {'chave': 'horario_fim', 'valor': '18:00'});
  }

  // --- Operações de Clientes ---
  Future<int> insertCliente(Cliente cliente) async {
    final db = await instance.database;
    return await db.insert('clientes', cliente.toMap());
  }

  Future<List<Cliente>> getClientes() async {
    final db = await instance.database;
    final result = await db.query('clientes', orderBy: 'nome ASC');
    return result.map((json) => Cliente.fromMap(json)).toList();
  }

  Future<int> updateCliente(Cliente cliente) async {
    final db = await instance.database;
    return db.update(
      'clientes',
      cliente.toMap(),
      where: 'id = ?',
      whereArgs: [cliente.id],
    );
  }

  Future<int> deleteCliente(int id) async {
    final db = await instance.database;
    return await db.delete(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getTotalGastoPorCliente(int clienteId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT SUM(a_s.preco_cobrado) as total
      FROM agendamento_servicos a_s
      INNER JOIN agendamentos a ON a.id = a_s.agendamento_id
      WHERE a.cliente_id = ? AND a.status = 'Concluído'
    ''', [clienteId]);
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  // --- Operações de Serviços ---
  Future<int> insertServico(Servico servico) async {
    final db = await instance.database;
    return await db.insert('servicos', servico.toMap());
  }

  Future<List<Servico>> getServicos() async {
    final db = await instance.database;
    final result = await db.query('servicos', orderBy: 'nome ASC');
    return result.map((json) => Servico.fromMap(json)).toList();
  }

  Future<int> updateServico(Servico servico) async {
    final db = await instance.database;
    return db.update(
      'servicos',
      servico.toMap(),
      where: 'id = ?',
      whereArgs: [servico.id],
    );
  }

  Future<int> deleteServico(int id) async {
    final db = await instance.database;
    return await db.delete(
      'servicos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isServicoVinculado(int servicoId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as qtd FROM agendamento_servicos WHERE servico_id = ?',
      [servicoId],
    );
    if (result.isNotEmpty) {
      final qtd = result.first['qtd'] as num? ?? 0;
      return qtd > 0;
    }
    return false;
  }

  // --- Operações de Agendamentos ---
  Future<int> insertAgendamento(Agendamento agendamento, List<AgendamentoServico> servicos) async {
    final db = await instance.database;
    int agendamentoId = 0;
    
    await db.transaction((txn) async {
      agendamentoId = await txn.insert('agendamentos', agendamento.toMap());
      
      for (var s in servicos) {
        var sMap = s.toMap();
        sMap['agendamento_id'] = agendamentoId;
        await txn.insert('agendamento_servicos', sMap);
      }
    });
    
    return agendamentoId;
  }

  Future<List<Agendamento>> getAgendamentos() async {
    final db = await instance.database;
    final result = await db.query('agendamentos', orderBy: 'data_hora ASC');
    return result.map((json) => Agendamento.fromMap(json)).toList();
  }

  Future<List<Agendamento>> getAgendamentosPorCliente(int clienteId) async {
    final db = await instance.database;
    final result = await db.query(
      'agendamentos',
      where: 'cliente_id = ?',
      whereArgs: [clienteId],
      orderBy: 'data_hora DESC', // Recentes primeiro
    );
    return result.map((json) => Agendamento.fromMap(json)).toList();
  }
  
  Future<List<Agendamento>> getAgendamentosConcluidos() async {
    final db = await instance.database;
    final result = await db.query(
      'agendamentos',
      where: 'status = ?',
      whereArgs: ['Concluído'],
      orderBy: 'data_hora DESC',
    );
    return result.map((json) => Agendamento.fromMap(json)).toList();
  }
  
  Future<List<AgendamentoServico>> getServicosDoAgendamento(int agendamentoId) async {
    final db = await instance.database;
    final result = await db.query(
      'agendamento_servicos',
      where: 'agendamento_id = ?',
      whereArgs: [agendamentoId],
    );
    return result.map((json) => AgendamentoServico.fromMap(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getServicosDetalhesPorAgendamento(int agendamentoId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT s.nome, a_s.preco_cobrado
      FROM agendamento_servicos a_s
      INNER JOIN servicos s ON s.id = a_s.servico_id
      WHERE a_s.agendamento_id = ?
    ''', [agendamentoId]);
  }

  Future<void> updateAgendamento(Agendamento agendamento, List<AgendamentoServico> servicos) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'agendamentos',
        agendamento.toMap(),
        where: 'id = ?',
        whereArgs: [agendamento.id],
      );
      
      await txn.delete(
        'agendamento_servicos',
        where: 'agendamento_id = ?',
        whereArgs: [agendamento.id],
      );
      
      for (var s in servicos) {
        var sMap = s.toMap();
        sMap['agendamento_id'] = agendamento.id;
        await txn.insert('agendamento_servicos', sMap);
      }
    });
  }

  Future<int> updateAgendamentoStatus(int id, String status) async {
    final db = await instance.database;
    return db.update(
      'agendamentos',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAgendamento(int id) async {
    final db = await instance.database;
    return await db.delete(
      'agendamentos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Agendamento>> getAgendamentosPorData(DateTime data) async {
    final db = await instance.database;
    final dataString = DateFormat('yyyy-MM-dd').format(data);
    
    final result = await db.rawQuery('''
      SELECT a.*, c.nome as cliente_nome, c.telefone as cliente_telefone, c.observacoes as cliente_observacoes, c.ficha_saude as cliente_ficha_saude,
             (SELECT GROUP_CONCAT(s.nome, ' | ') FROM agendamento_servicos a_s INNER JOIN servicos s ON a_s.servico_id = s.id WHERE a_s.agendamento_id = a.id) as servicos
      FROM agendamentos a
      INNER JOIN clientes c ON a.cliente_id = c.id
      WHERE a.data_hora LIKE ?
      ORDER BY a.data_hora ASC
    ''', ['$dataString%']);
    
    return result.map((json) => Agendamento.fromMap(json)).toList();
  }

  Future<Map<String, dynamic>> getDadosFinanceiros({String? dataPrefixo, String? dataInicio, String? dataFim}) async {
    final db = await instance.database;
    String sql = '''
      SELECT COUNT(DISTINCT a.id) as qtd, SUM(a_s.preco_cobrado) as faturamento
      FROM agendamentos a
      LEFT JOIN agendamento_servicos a_s ON a.id = a_s.agendamento_id
      WHERE a.status = 'Concluído'
    ''';
    List<dynamic> args = [];
    if (dataPrefixo != null) {
      sql += ' AND a.data_hora LIKE ?';
      args.add('$dataPrefixo%');
    } else if (dataInicio != null && dataFim != null) {
      sql += ' AND a.data_hora >= ? AND a.data_hora <= ?';
      args.add(dataInicio);
      args.add(dataFim);
    }
    final result = await db.rawQuery(sql, args);
    if (result.isNotEmpty) {
      final row = result.first;
      return {
        'qtd': row['qtd'] as int? ?? 0,
        'faturamento': (row['faturamento'] as num?)?.toDouble() ?? 0.0,
      };
    }
    return {'qtd': 0, 'faturamento': 0.0};
  }

  Future<List<Map<String, dynamic>>> getFaturamentoPorServico({String? dataPrefixo, String? dataInicio, String? dataFim}) async {
    final db = await instance.database;
    String sql = '''
      SELECT s.nome, COUNT(a_s.id) as quantidade, SUM(a_s.preco_cobrado) as total
      FROM agendamento_servicos a_s
      INNER JOIN servicos s ON a_s.servico_id = s.id
      INNER JOIN agendamentos a ON a_s.agendamento_id = a.id
      WHERE a.status = 'Concluído'
    ''';
    List<dynamic> args = [];
    if (dataPrefixo != null) {
      sql += ' AND a.data_hora LIKE ?';
      args.add('$dataPrefixo%');
    } else if (dataInicio != null && dataFim != null) {
      sql += ' AND a.data_hora >= ? AND a.data_hora <= ?';
      args.add(dataInicio);
      args.add(dataFim);
    }
    sql += ' GROUP BY s.id, s.nome ORDER BY total DESC';
    return await db.rawQuery(sql, args);
  }

  Future<List<Map<String, dynamic>>> getRelatorioAgendamentosPeriodo({String? dataPrefixo, String? dataInicio, String? dataFim}) async {
    final db = await instance.database;
    String sql = '''
      SELECT a.id, a.data_hora, c.nome as cliente_nome,
             (SELECT GROUP_CONCAT(s.nome, ' | ') FROM agendamento_servicos a_s INNER JOIN servicos s ON a_s.servico_id = s.id WHERE a_s.agendamento_id = a.id) as servicos,
             (SELECT SUM(a_s2.preco_cobrado) FROM agendamento_servicos a_s2 WHERE a_s2.agendamento_id = a.id) as valor_total
      FROM agendamentos a
      INNER JOIN clientes c ON a.cliente_id = c.id
      WHERE a.status = 'Concluído'
    ''';
    List<dynamic> args = [];
    if (dataPrefixo != null) {
      sql += ' AND a.data_hora LIKE ?';
      args.add('$dataPrefixo%');
    } else if (dataInicio != null && dataFim != null) {
      sql += ' AND a.data_hora >= ? AND a.data_hora <= ?';
      args.add(dataInicio);
      args.add(dataFim);
    }
    sql += ' ORDER BY a.data_hora ASC';
    return await db.rawQuery(sql, args);
  }

  Future<Map<int, double>> getFaturamentoMensalPorAno(int ano) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT SUBSTR(data_hora, 6, 2) as mes, SUM(a_s.preco_cobrado) as total
      FROM agendamento_servicos a_s
      INNER JOIN agendamentos a ON a.id = a_s.agendamento_id
      WHERE a.status = 'Concluído' AND a.data_hora LIKE ?
      GROUP BY mes
    ''', ['$ano-%']);
    
    final Map<int, double> faturamentoMensal = {
      for (int i = 1; i <= 12; i++) i: 0.0
    };
    
    for (var row in result) {
      final mesStr = row['mes'] as String?;
      if (mesStr != null) {
        final mes = int.tryParse(mesStr) ?? 0;
        final total = (row['total'] as num?)?.toDouble() ?? 0.0;
        if (mes >= 1 && mes <= 12) {
          faturamentoMensal[mes] = total;
        }
      }
    }
    return faturamentoMensal;
  }

  // --- Operações de Configurações ---
  Future<String> getConfig(String chave, String valorPadrao) async {
    try {
      final db = await instance.database;
      final result = await db.query(
        'configuracoes',
        where: 'chave = ?',
        whereArgs: [chave],
      );
      if (result.isNotEmpty) {
        return result.first['valor'] as String;
      }
    } catch (_) {}
    return valorPadrao;
  }

  Future<int> setConfig(String chave, String valor) async {
    final db = await instance.database;
    return await db.insert(
      'configuracoes',
      {'chave': chave, 'valor': valor},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Operações de Estoque ---
  Future<int> insertEstoqueItem(EstoqueItem item) async {
    final db = await instance.database;
    return await db.insert('estoque', item.toMap());
  }

  Future<List<EstoqueItem>> getEstoqueItems() async {
    final db = await instance.database;
    final result = await db.query('estoque', orderBy: 'nome ASC');
    return result.map((json) => EstoqueItem.fromMap(json)).toList();
  }

  Future<int> updateEstoqueItem(EstoqueItem item) async {
    final db = await instance.database;
    return await db.update(
      'estoque',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteEstoqueItem(int id) async {
    final db = await instance.database;
    return await db.delete(
      'estoque',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Consulta de Calendário ---
  Future<List<String>> getDiasComAgendamentos(DateTime dataReferencia) async {
    final db = await instance.database;
    final mesAnoString = DateFormat('yyyy-MM').format(dataReferencia);
    final result = await db.rawQuery('''
      SELECT DISTINCT SUBSTR(data_hora, 1, 10) as data
      FROM agendamentos
      WHERE status != 'Cancelado' AND data_hora LIKE ?
    ''', ['$mesAnoString%']);
    
    return result.map((row) => row['data'] as String).toList();
  }

  Future close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
