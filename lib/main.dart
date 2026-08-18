import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;
  runApp(const VendasApp());
}

class VendasApp extends StatelessWidget {
  const VendasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vendas de Equipamentos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const OrdersPage(),
    );
  }
}

class Order {
  final int? id;
  final String clientName;
  final String phone;
  final DateTime clientOrderDate;
  final DateTime? supplierOrderDate;
  final DateTime? supplierShipDate;
  final DateTime? homeArrivalDate;
  final DateTime? deliveredDate;
  final String articleType;
  final String teamType;
  final String teamName;
  final String kitType;
  final String size;
  final String printName;
  final String printNumber;
  final double salePrice;
  final double supplierCost;
  final bool delivered;
  final bool paid;
  final String notes;

  const Order({
    this.id,
    required this.clientName,
    required this.phone,
    required this.clientOrderDate,
    this.supplierOrderDate,
    this.supplierShipDate,
    this.homeArrivalDate,
    this.deliveredDate,
    required this.articleType,
    required this.teamType,
    required this.teamName,
    required this.kitType,
    required this.size,
    required this.printName,
    required this.printNumber,
    required this.salePrice,
    required this.supplierCost,
    required this.delivered,
    required this.paid,
    required this.notes,
  });

  double get profit => salePrice - supplierCost;
  bool get personalized => printName.trim().isNotEmpty || printNumber.trim().isNotEmpty;

  Map<String, Object?> toMap() => {
        'id': id,
        'clientName': clientName,
        'phone': phone,
        'clientOrderDate': clientOrderDate.toIso8601String(),
        'supplierOrderDate': supplierOrderDate?.toIso8601String(),
        'supplierShipDate': supplierShipDate?.toIso8601String(),
        'homeArrivalDate': homeArrivalDate?.toIso8601String(),
        'deliveredDate': deliveredDate?.toIso8601String(),
        'articleType': articleType,
        'teamType': teamType,
        'teamName': teamName,
        'kitType': kitType,
        'size': size,
        'printName': printName,
        'printNumber': printNumber,
        'salePrice': salePrice,
        'supplierCost': supplierCost,
        'delivered': delivered ? 1 : 0,
        'paid': paid ? 1 : 0,
        'notes': notes,
      };

  factory Order.fromMap(Map<String, Object?> map) => Order(
        id: map['id'] as int?,
        clientName: map['clientName'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        clientOrderDate: DateTime.parse(map['clientOrderDate'] as String),
        supplierOrderDate: _parseNullable(map['supplierOrderDate']),
        supplierShipDate: _parseNullable(map['supplierShipDate']),
        homeArrivalDate: _parseNullable(map['homeArrivalDate']),
        deliveredDate: _parseNullable(map['deliveredDate']),
        articleType: map['articleType'] as String? ?? 'Camisola',
        teamType: map['teamType'] as String? ?? 'Clube',
        teamName: map['teamName'] as String? ?? '',
        kitType: map['kitType'] as String? ?? '1.º equipamento',
        size: map['size'] as String? ?? '',
        printName: map['printName'] as String? ?? '',
        printNumber: map['printNumber'] as String? ?? '',
        salePrice: (map['salePrice'] as num?)?.toDouble() ?? 0,
        supplierCost: (map['supplierCost'] as num?)?.toDouble() ?? 0,
        delivered: (map['delivered'] as int? ?? 0) == 1,
        paid: (map['paid'] as int? ?? 0) == 1,
        notes: map['notes'] as String? ?? '',
      );

  static DateTime? _parseNullable(Object? value) {
    if (value == null) return null;
    final s = value.toString();
    return s.isEmpty ? null : DateTime.tryParse(s);
  }
}

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'vendas_camisolas.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE orders(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            clientName TEXT NOT NULL,
            phone TEXT NOT NULL,
            clientOrderDate TEXT NOT NULL,
            supplierOrderDate TEXT,
            supplierShipDate TEXT,
            homeArrivalDate TEXT,
            deliveredDate TEXT,
            articleType TEXT NOT NULL,
            teamType TEXT NOT NULL,
            teamName TEXT NOT NULL,
            kitType TEXT NOT NULL,
            size TEXT NOT NULL,
            printName TEXT NOT NULL,
            printNumber TEXT NOT NULL,
            salePrice REAL NOT NULL,
            supplierCost REAL NOT NULL,
            delivered INTEGER NOT NULL,
            paid INTEGER NOT NULL,
            notes TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  Future<List<Order>> getOrders() async {
    final db = await database;
    final rows = await db.query('orders', orderBy: 'clientOrderDate DESC, id DESC');
    return rows.map(Order.fromMap).toList();
  }

  Future<int> saveOrder(Order order) async {
    final db = await database;
    final data = order.toMap()..remove('id');
    if (order.id == null) {
      return db.insert('orders', data);
    }
    return db.update('orders', data, where: 'id = ?', whereArgs: [order.id]);
  }

  Future<void> deleteOrder(int id) async {
    final db = await database;
    await db.delete('orders', where: 'id = ?', whereArgs: [id]);
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Order> _allOrders = [];
  String _query = '';
  String _filter = 'Todas';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _allOrders = await AppDatabase.instance.getOrders();
    if (mounted) setState(() => _loading = false);
  }

  List<Order> get _orders {
    return _allOrders.where((o) {
      final q = _query.toLowerCase().trim();
      final matchesSearch = q.isEmpty ||
          o.clientName.toLowerCase().contains(q) ||
          o.teamName.toLowerCase().contains(q) ||
          o.printName.toLowerCase().contains(q) ||
          o.printNumber.toLowerCase().contains(q);
      final matchesFilter = switch (_filter) {
        'Por encomendar' => o.supplierOrderDate == null,
        'Em trânsito' => o.supplierShipDate != null && o.homeArrivalDate == null,
        'Recebidas' => o.homeArrivalDate != null && !o.delivered,
        'Por entregar' => !o.delivered,
        'Por pagar' => !o.paid,
        'Concluídas' => o.delivered && o.paid,
        _ => true,
      };
      return matchesSearch && matchesFilter;
    }).toList();
  }

  Future<void> _openEditor([Order? order]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OrderFormPage(order: order)),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    final totalSales = _allOrders.fold<double>(0, (s, o) => s + o.salePrice);
    final received = _allOrders.where((o) => o.paid).fold<double>(0, (s, o) => s + o.salePrice);
    final totalProfit = _allOrders.fold<double>(0, (s, o) => s + o.profit);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendas de Equipamentos'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Nova venda'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      Expanded(child: _SummaryCard(label: 'Vendas', value: _money(totalSales))),
                      const SizedBox(width: 8),
                      Expanded(child: _SummaryCard(label: 'Recebido', value: _money(received))),
                      const SizedBox(width: 8),
                      Expanded(child: _SummaryCard(label: 'Lucro', value: _money(totalProfit))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Pesquisar cliente, equipa, nome ou número',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: ['Todas', 'Por encomendar', 'Em trânsito', 'Recebidas', 'Por entregar', 'Por pagar', 'Concluídas']
                        .map((f) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: ChoiceChip(
                                label: Text(f),
                                selected: _filter == f,
                                onSelected: (_) => setState(() => _filter = f),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: orders.isEmpty
                      ? const Center(child: Text('Sem vendas para mostrar.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 90),
                          itemCount: orders.length,
                          itemBuilder: (_, i) {
                            final o = orders[i];
                            return Card(
                              child: ListTile(
                                onTap: () => _openEditor(o),
                                title: Text('${o.clientName} — ${o.teamName}', maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${o.articleType} • ${o.kitType} • ${o.size}${o.personalized ? ' • ${o.printNumber} ${o.printName}'.trim() : ''}'),
                                    const SizedBox(height: 3),
                                    Text('Pedido ${_date(o.clientOrderDate)} • ${_statusText(o)}'),
                                    const SizedBox(height: 3),
                                    Text('${_money(o.salePrice)}  |  Lucro ${_money(o.profit)}'),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(o.delivered ? Icons.check_circle : Icons.local_shipping_outlined,
                                        color: o.delivered ? Colors.green : null),
                                    const SizedBox(height: 4),
                                    Icon(o.paid ? Icons.euro : Icons.euro_outlined,
                                        color: o.paid ? Colors.green : null),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(children: [Text(label, style: Theme.of(context).textTheme.labelMedium), const SizedBox(height: 3), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
      ),
    );
  }
}

class OrderFormPage extends StatefulWidget {
  final Order? order;
  const OrderFormPage({super.key, this.order});

  @override
  State<OrderFormPage> createState() => _OrderFormPageState();
}

class _OrderFormPageState extends State<OrderFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController clientC;
  late final TextEditingController phoneC;
  late final TextEditingController teamC;
  late final TextEditingController sizeC;
  late final TextEditingController printNameC;
  late final TextEditingController printNumberC;
  late final TextEditingController salePriceC;
  late final TextEditingController supplierCostC;
  late final TextEditingController notesC;

  late DateTime clientOrderDate;
  DateTime? supplierOrderDate;
  DateTime? supplierShipDate;
  DateTime? homeArrivalDate;
  DateTime? deliveredDate;

  String articleType = 'Camisola';
  String teamType = 'Clube';
  String kitType = '1.º equipamento';
  bool delivered = false;
  bool paid = false;
  bool _manualPrice = false;

  final articles = ['Camisola', 'Calções', 'Fato de treino', 'Casaco', 'Conjunto', 'Vintage', 'Outro'];
  final teamTypes = ['Clube', 'Seleção'];
  final kits = ['1.º equipamento', 'Alternativo / 2.º', '3.º equipamento', 'Guarda-redes', 'Outro'];

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    clientC = TextEditingController(text: o?.clientName ?? '');
    phoneC = TextEditingController(text: o?.phone ?? '');
    teamC = TextEditingController(text: o?.teamName ?? '');
    sizeC = TextEditingController(text: o?.size ?? '');
    printNameC = TextEditingController(text: o?.printName ?? '');
    printNumberC = TextEditingController(text: o?.printNumber ?? '');
    salePriceC = TextEditingController(text: o == null ? '14.00' : o.salePrice.toStringAsFixed(2));
    supplierCostC = TextEditingController(text: o == null ? '' : o.supplierCost.toStringAsFixed(2));
    notesC = TextEditingController(text: o?.notes ?? '');

    clientOrderDate = o?.clientOrderDate ?? DateTime.now();
    supplierOrderDate = o?.supplierOrderDate;
    supplierShipDate = o?.supplierShipDate;
    homeArrivalDate = o?.homeArrivalDate;
    deliveredDate = o?.deliveredDate;
    articleType = o?.articleType ?? 'Camisola';
    teamType = o?.teamType ?? 'Clube';
    kitType = o?.kitType ?? '1.º equipamento';
    delivered = o?.delivered ?? false;
    paid = o?.paid ?? false;
    _manualPrice = o != null;

    printNameC.addListener(_updateAutoPrice);
    printNumberC.addListener(_updateAutoPrice);
  }

  @override
  void dispose() {
    for (final c in [clientC, phoneC, teamC, sizeC, printNameC, printNumberC, salePriceC, supplierCostC, notesC]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _personalized => printNameC.text.trim().isNotEmpty || printNumberC.text.trim().isNotEmpty;

  double _defaultPrice() {
    if (articleType == 'Calções') return _personalized ? 12 : 10;
    if (articleType == 'Camisola') return _personalized ? 18 : 14;
    return double.tryParse(salePriceC.text.replaceAll(',', '.')) ?? 0;
  }

  void _updateAutoPrice() {
    if (_manualPrice) return;
    if (articleType == 'Camisola' || articleType == 'Calções') {
      final p = _defaultPrice();
      final text = p.toStringAsFixed(2);
      if (salePriceC.text != text) salePriceC.text = text;
      if (mounted) setState(() {});
    }
  }

  Future<DateTime?> _pickDate(DateTime? current) async {
    return showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
  }

  Widget _dateTile(String label, DateTime? value, void Function(DateTime?) setValue, {bool required = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value == null ? 'Não definida' : _date(value)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null && !required)
            IconButton(onPressed: () => setState(() => setValue(null)), icon: const Icon(Icons.clear)),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final d = await _pickDate(value);
              if (d != null) setState(() => setValue(d));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final salePrice = double.tryParse(salePriceC.text.replaceAll(',', '.')) ?? 0;
    final cost = double.tryParse(supplierCostC.text.replaceAll(',', '.')) ?? 0;
    final order = Order(
      id: widget.order?.id,
      clientName: clientC.text.trim(),
      phone: phoneC.text.trim(),
      clientOrderDate: clientOrderDate,
      supplierOrderDate: supplierOrderDate,
      supplierShipDate: supplierShipDate,
      homeArrivalDate: homeArrivalDate,
      deliveredDate: delivered ? (deliveredDate ?? DateTime.now()) : deliveredDate,
      articleType: articleType,
      teamType: teamType,
      teamName: teamC.text.trim(),
      kitType: kitType,
      size: sizeC.text.trim(),
      printName: printNameC.text.trim(),
      printNumber: printNumberC.text.trim(),
      salePrice: salePrice,
      supplierCost: cost,
      delivered: delivered,
      paid: paid,
      notes: notesC.text.trim(),
    );
    await AppDatabase.instance.saveOrder(order);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final id = widget.order?.id;
    if (id == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar venda?'),
        content: const Text('Esta ação não pode ser anulada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (yes == true) {
      await AppDatabase.instance.deleteOrder(id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = double.tryParse(salePriceC.text.replaceAll(',', '.')) ?? 0;
    final cost = double.tryParse(supplierCostC.text.replaceAll(',', '.')) ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.order == null ? 'Nova venda' : 'Editar venda'),
        actions: [if (widget.order != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline))],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Guardar')),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Cliente', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            TextFormField(controller: clientC, decoration: const InputDecoration(labelText: 'Nome do cliente', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Indica o cliente' : null),
            const SizedBox(height: 10),
            TextFormField(controller: phoneC, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone (opcional)', border: OutlineInputBorder())),
            const SizedBox(height: 22),
            Text('Datas', style: Theme.of(context).textTheme.titleLarge),
            _dateTile('Pedido pelo cliente', clientOrderDate, (d) => clientOrderDate = d ?? clientOrderDate, required: true),
            _dateTile('Pedido ao fornecedor', supplierOrderDate, (d) => supplierOrderDate = d),
            _dateTile('Enviado pelo fornecedor', supplierShipDate, (d) => supplierShipDate = d),
            _dateTile('Recebido em casa', homeArrivalDate, (d) => homeArrivalDate = d),
            _dateTile('Entregue ao cliente', deliveredDate, (d) => deliveredDate = d),
            const SizedBox(height: 16),
            Text('Artigo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(value: articleType, decoration: const InputDecoration(labelText: 'Tipo de artigo', border: OutlineInputBorder()), items: articles.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) { if (v == null) return; setState(() { articleType = v; _manualPrice = !(v == 'Camisola' || v == 'Calções'); }); _updateAutoPrice(); }),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(value: teamType, decoration: const InputDecoration(labelText: 'Clube ou seleção', border: OutlineInputBorder()), items: teamTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => teamType = v ?? teamType)),
            const SizedBox(height: 10),
            TextFormField(controller: teamC, decoration: const InputDecoration(labelText: 'Equipa / Seleção', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Indica a equipa ou seleção' : null),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(value: kitType, decoration: const InputDecoration(labelText: 'Equipamento', border: OutlineInputBorder()), items: kits.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => kitType = v ?? kitType)),
            const SizedBox(height: 10),
            TextFormField(controller: sizeC, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Tamanho (S, M, L, XL, infantil...)', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Indica o tamanho' : null),
            const SizedBox(height: 22),
            Text('Personalização', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            TextFormField(controller: printNameC, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Nome estampado (opcional)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextFormField(controller: printNumberC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Número estampado (opcional)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Text(_personalized ? 'Com personalização' : 'Sem personalização'),
            const SizedBox(height: 22),
            Text('Valores', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            TextFormField(
              controller: salePriceC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Preço de venda (€)', border: const OutlineInputBorder(), helperText: articleType == 'Camisola' ? 'Automático: 14 € sem / 18 € com personalização' : articleType == 'Calções' ? 'Automático: 10 € sem / 12 € com personalização' : 'Valor livre'),
              onChanged: (_) => setState(() => _manualPrice = true),
            ),
            const SizedBox(height: 10),
            TextFormField(controller: supplierCostC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Custo ao fornecedor (€)', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
            const SizedBox(height: 8),
            Text('Lucro desta venda: ${_money(sale - cost)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 22),
            Text('Estado', style: Theme.of(context).textTheme.titleLarge),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: delivered, title: const Text('Entregue ao cliente'), onChanged: (v) => setState(() { delivered = v ?? false; if (delivered && deliveredDate == null) deliveredDate = DateTime.now(); })),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: paid, title: const Text('Pago'), onChanged: (v) => setState(() => paid = v ?? false)),
            const SizedBox(height: 10),
            TextFormField(controller: notesC, maxLines: 3, decoration: const InputDecoration(labelText: 'Observações', border: OutlineInputBorder())),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
String _money(double value) => '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

String _statusText(Order o) {
  if (o.delivered && o.paid) return 'Concluída';
  if (o.homeArrivalDate != null && !o.delivered) return 'Recebida / por entregar';
  if (o.supplierShipDate != null && o.homeArrivalDate == null) return 'Em trânsito';
  if (o.supplierOrderDate != null && o.supplierShipDate == null) return 'Pedida ao fornecedor';
  return 'Por encomendar';
}
