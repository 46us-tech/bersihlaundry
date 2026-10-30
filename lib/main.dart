import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/* ===================== WARNA ===================== */
const kBlue = Color(0xFF1565E8);
const kBlue2 = Color(0xFF3D8BFF);
const kBlueL = Color(0xFFEAF3FF);
const kBg = Color(0xFFF5F9FF);
const kText = Color(0xFF12305C);
const kMut = Color(0xFF6B82A6);
const kOk = Color(0xFF12B886);
const kWarn = Color(0xFFFF9F1A);
const kBad = Color(0xFFF0476B);

/* ===================== HELPER ===================== */
String two(int n) => n.toString().padLeft(2, '0');
String iso(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
String today() => iso(DateTime.now());
DateTime parseD(String s) => DateTime.parse(s);
String addDays(String s, int n) {
  final d = parseD(s);
  return iso(DateTime(d.year, d.month, d.day + n));
}

const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
String tgl(String s) {
  if (s.isEmpty || s.startsWith('0000') || s.startsWith('9999')) return '-';
  final d = parseD(s);
  return '${d.day} ${_bulan[d.month - 1]} ${d.year}';
}

String rp(num n) {
  final v = n.round();
  final neg = v < 0;
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return (neg ? '-' : '') + 'Rp' + b.toString();
}

String qf(double v) {
  final r = (v * 100).round() / 100;
  return r == r.roundToDouble() ? r.round().toString() : r.toString();
}

int toInt(String s) => (double.tryParse(s.trim().replaceAll(',', '.')) ?? 0).round();
double toD(String s) => double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;
String uid() => DateTime.now().microsecondsSinceEpoch.toRadixString(36) + math.Random().nextInt(99999).toRadixString(36);

String normPhone(String s) {
  var d = s.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return '';
  if (d.startsWith('0')) {
    d = '62' + d.substring(1);
  } else if (d.startsWith('8')) {
    d = '62' + d;
  }
  return d;
}

bool inR(String d, List<String> r) => d.compareTo(r[0]) >= 0 && d.compareTo(r[1]) <= 0;

List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    ((v ?? []) as List).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();

/* ===================== MODEL ===================== */
class Settings {
  String name, address, phone, bank, footer;
  Settings({
    this.name = 'BERSIH LAUNDRY',
    this.address = '',
    this.phone = '',
    this.bank = '',
    this.footer = 'Terima kasih sudah mempercayakan cucian Anda kepada kami 🙏',
  });
  Map<String, dynamic> toJson() => {'name': name, 'address': address, 'phone': phone, 'bank': bank, 'footer': footer};
  factory Settings.fromJson(Map<String, dynamic> j) {
    final d = Settings();
    return Settings(
      name: (j['name'] ?? d.name) as String,
      address: (j['address'] ?? '') as String,
      phone: (j['phone'] ?? '') as String,
      bank: (j['bank'] ?? '') as String,
      footer: (j['footer'] ?? d.footer) as String,
    );
  }
}

class Service {
  String id, name, unit;
  int price;
  Service({required this.id, required this.name, required this.unit, required this.price});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'unit': unit, 'price': price};
  factory Service.fromJson(Map<String, dynamic> j) =>
      Service(id: j['id'] as String, name: j['name'] as String, unit: j['unit'] as String, price: (j['price'] as num).round());
}

class OrderItem {
  String name, unit;
  int price;
  double qty;
  OrderItem({required this.name, required this.unit, required this.price, required this.qty});
  int get line => (price * qty).round();
  Map<String, dynamic> toJson() => {'name': name, 'unit': unit, 'price': price, 'qty': qty};
  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
      name: j['name'] as String, unit: j['unit'] as String, price: (j['price'] as num).round(), qty: (j['qty'] as num).toDouble());
}

class Payment {
  String date;
  int amount;
  Payment({required this.date, required this.amount});
  Map<String, dynamic> toJson() => {'date': date, 'amount': amount};
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(date: j['date'] as String, amount: (j['amount'] as num).round());
}

class LaundryOrder {
  String id, no, date, customer, phone, status, eta, note;
  int ts, discount;
  List<OrderItem> items;
  List<Payment> payments;
  LaundryOrder({
    required this.id,
    required this.no,
    required this.ts,
    required this.date,
    required this.customer,
    required this.phone,
    required this.items,
    required this.discount,
    required this.payments,
    required this.status,
    required this.eta,
    required this.note,
  });
  int get sub => items.fold(0, (a, i) => a + i.line);
  int get total => math.max(0, sub - discount);
  int get paid => payments.fold(0, (a, p) => a + p.amount);
  int get due => math.max(0, total - paid);
  Map<String, dynamic> toJson() => {
        'id': id,
        'no': no,
        'ts': ts,
        'date': date,
        'customer': customer,
        'phone': phone,
        'items': items.map((e) => e.toJson()).toList(),
        'discount': discount,
        'payments': payments.map((e) => e.toJson()).toList(),
        'status': status,
        'eta': eta,
        'note': note,
      };
  factory LaundryOrder.fromJson(Map<String, dynamic> j) => LaundryOrder(
        id: j['id'] as String,
        no: j['no'] as String,
        ts: (j['ts'] ?? 0) as int,
        date: j['date'] as String,
        customer: j['customer'] as String,
        phone: (j['phone'] ?? '') as String,
        items: _list(j['items'], OrderItem.fromJson),
        discount: ((j['discount'] ?? 0) as num).round(),
        payments: _list(j['payments'], Payment.fromJson),
        status: (j['status'] ?? 'proses') as String,
        eta: (j['eta'] ?? '') as String,
        note: (j['note'] ?? '') as String,
      );
}

class Expense {
  String id, date, category, note;
  int amount;
  Expense({required this.id, required this.date, required this.category, required this.amount, required this.note});
  Map<String, dynamic> toJson() => {'id': id, 'date': date, 'category': category, 'amount': amount, 'note': note};
  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
      id: j['id'] as String,
      date: j['date'] as String,
      category: j['category'] as String,
      amount: (j['amount'] as num).round(),
      note: (j['note'] ?? '') as String);
}

class Employee {
  String id, name, unit;
  int rate;
  Employee({required this.id, required this.name, required this.unit, required this.rate});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'unit': unit, 'rate': rate};
  factory Employee.fromJson(Map<String, dynamic> j) =>
      Employee(id: j['id'] as String, name: j['name'] as String, unit: j['unit'] as String, rate: (j['rate'] as num).round());
}

class IronEntry {
  String id, date, empId, note, paidDate;
  int ts, rate;
  double qty;
  bool paid;
  IronEntry({
    required this.id,
    required this.ts,
    required this.date,
    required this.empId,
    required this.qty,
    required this.rate,
    required this.note,
    this.paid = false,
    this.paidDate = '',
  });
  int get amount => (qty * rate).round();
  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': ts,
        'date': date,
        'empId': empId,
        'qty': qty,
        'rate': rate,
        'note': note,
        'paid': paid,
        'paidDate': paidDate,
      };
  factory IronEntry.fromJson(Map<String, dynamic> j) => IronEntry(
        id: j['id'] as String,
        ts: (j['ts'] ?? 0) as int,
        date: j['date'] as String,
        empId: j['empId'] as String,
        qty: (j['qty'] as num).toDouble(),
        rate: (j['rate'] as num).round(),
        note: (j['note'] ?? '') as String,
        paid: (j['paid'] ?? false) as bool,
        paidDate: (j['paidDate'] ?? '') as String,
      );
}

/* ===================== PENYIMPANAN ===================== */
class Store extends ChangeNotifier {
  Settings settings = Settings();
  List<Service> services = [];
  List<LaundryOrder> orders = [];
  List<Expense> expenses = [];
  List<Employee> employees = [];
  List<IronEntry> iron = [];
  String seqDate = '';
  int seqN = 0;
  SharedPreferences? _p;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    final s = _p!.getString('db_v1');
    if (s == null) {
      seed();
    } else {
      try {
        fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        seed();
      }
    }
  }

  void seed() {
    settings = Settings();
    services = [
      Service(id: uid(), name: 'Cuci Kiloan', unit: 'Kg', price: 7000),
      Service(id: uid(), name: 'Cuci + Setrika', unit: 'Kg', price: 9000),
      Service(id: uid(), name: 'Setrika Saja', unit: 'Kg', price: 5000),
      Service(id: uid(), name: 'Bedcover', unit: 'Pcs', price: 25000),
      Service(id: uid(), name: 'Selimut', unit: 'Pcs', price: 20000),
      Service(id: uid(), name: 'Sepatu', unit: 'Pasang', price: 30000),
      Service(id: uid(), name: 'Jas / Gaun (Dry Clean)', unit: 'Pcs', price: 35000),
    ];
    orders = [];
    expenses = [];
    employees = [];
    iron = [];
    seqDate = '';
    seqN = 0;
  }

  Map<String, dynamic> toJson() => {
        'settings': settings.toJson(),
        'services': services.map((e) => e.toJson()).toList(),
        'orders': orders.map((e) => e.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'employees': employees.map((e) => e.toJson()).toList(),
        'iron': iron.map((e) => e.toJson()).toList(),
        'seqDate': seqDate,
        'seqN': seqN,
      };

  void fromJson(Map<String, dynamic> j) {
    settings = Settings.fromJson(Map<String, dynamic>.from((j['settings'] ?? {}) as Map));
    services = _list(j['services'], Service.fromJson);
    orders = _list(j['orders'], LaundryOrder.fromJson);
    expenses = _list(j['expenses'], Expense.fromJson);
    employees = _list(j['employees'], Employee.fromJson);
    iron = _list(j['iron'], IronEntry.fromJson);
    seqDate = (j['seqDate'] ?? '') as String;
    seqN = ((j['seqN'] ?? 0) as num).round();
  }

  void save() {
    _p?.setString('db_v1', jsonEncode(toJson()));
    notifyListeners();
  }

  String nextNo() {
    final t = today();
    if (seqDate != t) {
      seqDate = t;
      seqN = 0;
    }
    seqN++;
    final ymd = t.substring(2).replaceAll('-', '');
    final n = seqN.toString().padLeft(3, '0');
    return 'BL$ymd-$n';
  }

  int incomeOn(String d) {
    var s = 0;
    for (final o in orders) {
      for (final p in o.payments) {
        if (p.date == d) s += p.amount;
      }
    }
    return s;
  }

  int incomeIn(List<String> r) {
    var s = 0;
    for (final o in orders) {
      for (final p in o.payments) {
        if (inR(p.date, r)) s += p.amount;
      }
    }
    return s;
  }

  int get piutang => orders.fold(0, (a, o) => a + o.due);

  void payWage(Employee m, List<String> r) {
    final es = iron.where((e) => e.empId == m.id && !e.paid && inR(e.date, r)).toList();
    final t = es.fold<int>(0, (a, e) => a + e.amount);
    for (final e in es) {
      e.paid = true;
      e.paidDate = today();
    }
    expenses.add(Expense(id: uid(), date: today(), category: 'Upah Setrika', amount: t, note: 'Upah ${m.name}'));
    save();
  }
}

final store = Store();

/* ===================== PERIODE ===================== */
enum PK { today, week, month, last, all, custom }

class Period {
  PK k = PK.month;
  String from = '';
  String to = '';
  List<String> range() {
    final n = DateTime.now();
    final t = today();
    if (k == PK.today) return [t, t];
    if (k == PK.week) {
      final s = DateTime(n.year, n.month, n.day - (n.weekday - 1));
      final e = DateTime(s.year, s.month, s.day + 6);
      return [iso(s), iso(e)];
    }
    if (k == PK.month) return [iso(DateTime(n.year, n.month, 1)), iso(DateTime(n.year, n.month + 1, 0))];
    if (k == PK.last) return [iso(DateTime(n.year, n.month - 1, 1)), iso(DateTime(n.year, n.month, 0))];
    if (k == PK.all) return ['0000-00-00', '9999-99-99'];
    return [from.isEmpty ? '0000-00-00' : from, to.isEmpty ? '9999-99-99' : to];
  }

  String label() {
    final r = range();
    if (k == PK.all) return 'Semua waktu';
    return '${tgl(r[0])} s/d ${tgl(r[1])}';
  }
}

/* ===================== UI HELPER ===================== */
void snack(BuildContext c, String m) {
  ScaffoldMessenger.of(c).hideCurrentSnackBar();
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
}

Widget box(Widget child, {VoidCallback? onTap, bool hot = false, Color? color, EdgeInsets pad = const EdgeInsets.all(15)}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: hot ? null : (color ?? Colors.white),
      gradient: hot ? const LinearGradient(colors: [kBlue, kBlue2], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: kBlue.withOpacity(.12), blurRadius: 16, offset: const Offset(0, 6))],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(padding: pad, child: child),
      ),
    ),
  );
}

Widget stat(String l, String v, String e, {bool hot = false, Color? vc}) {
  return box(
    Stack(children: [
      Positioned(right: 0, top: 0, child: Text(e, style: const TextStyle(fontSize: 26))),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hot ? Colors.white : kMut)),
        const SizedBox(height: 4),
        Text(v, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: hot ? Colors.white : (vc ?? kBlue))),
      ]),
    ]),
    hot: hot,
  );
}

Widget badge(String t, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
    );

Widget payBadge(LaundryOrder o) {
  if (o.due <= 0) return badge('LUNAS', const Color(0xFFD3F9E9), const Color(0xFF08805C));
  if (o.paid > 0) return badge('DP • kurang ${rp(o.due)}', const Color(0xFFFFF0D6), const Color(0xFFB36B00));
  return badge('BELUM BAYAR', const Color(0xFFFFE0E8), const Color(0xFFC0204A));
}

const stLabel = {'proses': 'Diproses', 'selesai': 'Siap Diambil', 'diambil': 'Diambil'};
Widget stBadge(LaundryOrder o) {
  final lbl = stLabel[o.status] ?? o.status;
  if (o.status == 'diambil') return badge(lbl, const Color(0xFFD3F9E9), const Color(0xFF08805C));
  if (o.status == 'selesai') return badge(lbl, const Color(0xFFFFF0D6), const Color(0xFFB36B00));
  return badge(lbl, kBlueL, kBlue);
}

Widget title(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
      child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kText)),
    );

Widget empty(String emoji, String msg) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
          child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 44)),
        const SizedBox(height: 6),
        Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: kMut)),
      ])),
    );

Widget tf(String label, TextEditingController c,
    {TextInputType? kb, String? hint, int lines = 1, ValueChanged<String>? onChanged}) {
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: c,
      keyboardType: kb,
      maxLines: lines,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );
}

const numKb = TextInputType.numberWithOptions(decimal: true);

Widget bigBtn(String t, VoidCallback f, {Color color = kBlue, bool outline = false, Color? fg}) {
  final style = outline
      ? OutlinedButton.styleFrom(
          foregroundColor: kBlue,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: kBlue2, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))
      : ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: fg ?? Colors.white,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)));
  final child = Text(t, style: const TextStyle(fontWeight: FontWeight.w800));
  return outline ? OutlinedButton(onPressed: f, style: style, child: child) : ElevatedButton(onPressed: f, style: style, child: child);
}

Future<T?> openSheet<T>(BuildContext c, Widget w) {
  return showModalBottomSheet<T>(
    context: c,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 22), child: w),
    ),
  );
}

Future<String?> askText(BuildContext c, String ttl, {String initial = '', String? hint, TextInputType? kb, int lines = 1}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(ttl),
      content: TextField(controller: ctl, keyboardType: kb, maxLines: lines, autofocus: true, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('OK')),
      ],
    ),
  );
}

Future<bool> confirmDlg(BuildContext c, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya')),
      ],
    ),
  );
  return r == true;
}

Future<String?> pickDate(BuildContext c, String init) async {
  final i = init.isEmpty || init.startsWith('0000') || init.startsWith('9999') ? DateTime.now() : parseD(init);
  final d = await showDatePicker(context: c, initialDate: i, firstDate: DateTime(2020), lastDate: DateTime(2100));
  return d == null ? null : iso(d);
}

/* ===================== WHATSAPP & INVOICE ===================== */
String invoiceText(LaundryOrder o) {
  final s = store.settings;
  final L = <String>[];
  L.add('*${s.name.toUpperCase()}*');
  if (s.address.isNotEmpty) L.add(s.address);
  if (s.phone.isNotEmpty) L.add('Telp/WA: ${s.phone}');
  L.add('━━━━━━━━━━━━━━');
  L.add('*INVOICE ${o.no}*');
  L.add('Tanggal : ${tgl(o.date)}');
  if (o.eta.isNotEmpty) L.add('Estimasi: ${tgl(o.eta)}');
  L.add('Pelanggan: ${o.customer}');
  L.add('━━━━━━━━━━━━━━');
  for (var k = 0; k < o.items.length; k++) {
    final i = o.items[k];
    L.add('${k + 1}. ${i.name}\n    ${qf(i.qty)} ${i.unit} x ${rp(i.price)} = ${rp(i.line)}');
  }
  L.add('━━━━━━━━━━━━━━');
  if (o.discount > 0) {
    L.add('Subtotal: ${rp(o.sub)}');
    L.add('Diskon  : -${rp(o.discount)}');
  }
  L.add('*TOTAL   : ${rp(o.total)}*');
  L.add('Dibayar : ${rp(o.paid)}');
  if (o.due > 0) {
    L.add('*Sisa tagihan: ${rp(o.due)}*');
    if (s.bank.isNotEmpty) L.add('\nPembayaran ke:\n${s.bank}');
  } else {
    L.add('*Status: LUNAS ✅*');
  }
  if (o.note.isNotEmpty) L.add('\nCatatan: ${o.note}');
  L.add('\n${s.footer}');
  return L.join('\n');
}

Future<void> launchWA(BuildContext c, String ph, String text) async {
  final u = Uri.parse('https://wa.me/$ph?text=${Uri.encodeComponent(text)}');
  bool ok = false;
  try {
    ok = await launchUrl(u, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && c.mounted) snack(c, 'WhatsApp tidak dapat dibuka');
}

Future<void> openWA(BuildContext c, LaundryOrder o, String text) async {
  var ph = o.phone;
  if (ph.isEmpty) {
    final v = await askText(c, 'Nomor WhatsApp pelanggan', hint: '08123456789', kb: TextInputType.phone);
    if (v == null) return;
    ph = normPhone(v);
    if (ph.isEmpty) {
      if (c.mounted) snack(c, 'Nomor tidak valid');
      return;
    }
    o.phone = ph;
    store.save();
  }
  if (!c.mounted) return;
  await launchWA(c, ph, text);
}

/* ===================== APP ===================== */
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.init();
  runApp(const BersihApp());
}

class BersihApp extends StatelessWidget {
  const BersihApp({super.key});
  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD6E6FF), width: 2));
    return MaterialApp(
      title: 'Bersih Laundry',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kBlue, brightness: Brightness.light),
        scaffoldBackgroundColor: kBg,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: border,
          enabledBorder: border,
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBlue2, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[const HomePage(), const OrdersPage(), const ServicesPage(), const IronPage(), const ReportPage()];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          child: Container(
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [kBlue, kBlue2], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Stack(children: [
              Positioned(right: -30, top: -40, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.14)))),
              Positioned(right: 90, bottom: -24, child: Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.14)))),
            ]),
          ),
        ),
        title: ListenableBuilder(
          listenable: store,
          builder: (c, _) => Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
              child: const Text('🫧', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(store.settings.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                const Text('Cepat • Wangi • Rapi', style: TextStyle(fontSize: 11, color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: IndexedStack(index: tab, children: pages),
      floatingActionButton: (tab == 0 || tab == 1)
          ? FloatingActionButton.extended(
              backgroundColor: kBlue,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewOrderPage())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nota Baru', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        backgroundColor: Colors.white,
        indicatorColor: kBlueL,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: kBlue), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded, color: kBlue), label: 'Nota'),
          NavigationDestination(icon: Icon(Icons.sell_outlined), selectedIcon: Icon(Icons.sell_rounded, color: kBlue), label: 'Layanan'),
          NavigationDestination(icon: Icon(Icons.iron_outlined), selectedIcon: Icon(Icons.iron_rounded, color: kBlue), label: 'Setrika'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded, color: kBlue), label: 'Laporan'),
        ],
      ),
    );
  }
}

/* ===================== BERANDA ===================== */
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final t = today();
        final inc = store.incomeOn(t);
        final cnt = store.orders.where((o) => o.date == t).length;
        final proses = store.orders.where((o) => o.status == 'proses').length;
        final siap = store.orders.where((o) => o.status == 'selesai').length;
        final days = <String>[for (var i = 6; i >= 0; i--) addDays(t, -i)];
        final vals = days.map(store.incomeOn).toList();
        final mx = math.max(1, vals.fold<int>(0, math.max));
        const dn = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
        final act = store.orders.where((o) => o.status != 'diambil').toList()..sort((a, b) => a.eta.compareTo(b.eta));
        return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
          Text(tgl(t), style: const TextStyle(color: kMut, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: stat('Pemasukan hari ini', rp(inc), '💰', hot: true)),
            const SizedBox(width: 12),
            Expanded(child: stat('Nota hari ini', '$cnt', '🧾')),
          ]),
          Row(children: [
            Expanded(child: stat('Sedang diproses', '$proses', '🫧')),
            const SizedBox(width: 12),
            Expanded(child: stat('Siap diambil', '$siap', '📦')),
          ]),
          stat('Piutang (belum dibayar)', rp(store.piutang), '⏳', vc: kWarn),
          title('Pemasukan 7 hari terakhir'),
          box(SizedBox(
            height: 120,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(vals[i] > 0 ? '${(vals[i] / 1000).round()}k' : '', style: const TextStyle(fontSize: 10, color: kMut, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: math.max(4.0, vals[i] / mx * 70),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [kBlue2, kBlue], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(dn[parseD(days[i]).weekday - 1], style: const TextStyle(fontSize: 10, color: kMut, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          )),
          title('Cucian yang perlu diurus'),
          if (act.isEmpty) empty('✨', 'Belum ada cucian aktif') else ...act.take(6).map((o) => OrderTile(o)),
        ]);
      },
    );
  }
}

/* ===================== NOTA ===================== */
class OrderTile extends StatelessWidget {
  final LaundryOrder o;
  const OrderTile(this.o, {super.key});
  @override
  Widget build(BuildContext context) {
    return box(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.customer, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text('${o.no} • ${tgl(o.date)}${o.eta.isNotEmpty ? ' • Est. ${tgl(o.eta)}' : ''}', style: const TextStyle(fontSize: 12, color: kMut)),
            ]),
          ),
          Text(rp(o.total), style: const TextStyle(fontWeight: FontWeight.w800, color: kBlue)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [stBadge(o), payBadge(o)]),
      ]),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(o.id))),
    );
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String q = '';
  String f = 'all';
  @override
  Widget build(BuildContext context) {
    const fs = {'all': 'Semua', 'proses': 'Diproses', 'selesai': 'Siap Diambil', 'diambil': 'Diambil', 'hutang': 'Belum Lunas'};
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        var L = store.orders.where((o) {
          final s = q.toLowerCase();
          return s.isEmpty || o.customer.toLowerCase().contains(s) || o.no.toLowerCase().contains(s) || o.phone.contains(s);
        }).toList();
        if (f == 'hutang') {
          L = L.where((o) => o.due > 0).toList();
        } else if (f != 'all') {
          L = L.where((o) => o.status == f).toList();
        }
        L.sort((a, b) => b.ts.compareTo(a.ts));
        return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
          TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(hintText: 'Cari nama / no. nota', prefixIcon: Icon(Icons.search_rounded)),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final e in fs.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(e.value), selected: f == e.key, onSelected: (_) => setState(() => f = e.key)),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          if (L.isEmpty) empty('🧺', 'Belum ada nota.\nTekan tombol "Nota Baru" untuk membuat nota.') else ...L.map((o) => OrderTile(o)),
        ]);
      },
    );
  }
}

class NewOrderPage extends StatefulWidget {
  const NewOrderPage({super.key});
  @override
  State<NewOrderPage> createState() => _NewOrderPageState();
}

class _NewOrderPageState extends State<NewOrderPage> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final qty = TextEditingController();
  final disc = TextEditingController();
  final pay = TextEditingController();
  final note = TextEditingController();
  String? sid;
  String eta = addDays(today(), 2);
  final items = <OrderItem>[];

  @override
  void initState() {
    super.initState();
    if (store.services.isNotEmpty) sid = store.services.first.id;
  }

  @override
  void dispose() {
    for (final c in [name, phone, qty, disc, pay, note]) {
      c.dispose();
    }
    super.dispose();
  }

  int get sub => items.fold(0, (a, i) => a + i.line);
  int get discount => math.min(toInt(disc.text), sub);
  int get total => math.max(0, sub - discount);

  void addItem() {
    final s = store.services.where((x) => x.id == sid).firstOrNull;
    final q = toD(qty.text);
    if (s == null) {
      snack(context, 'Belum ada layanan');
      return;
    }
    if (q <= 0) {
      snack(context, 'Isi jumlah dulu');
      return;
    }
    final ex = items.where((i) => i.name == s.name && i.unit == s.unit && i.price == s.price).firstOrNull;
    setState(() {
      if (ex != null) {
        ex.qty = (ex.qty + q);
      } else {
        items.add(OrderItem(name: s.name, unit: s.unit, price: s.price, qty: q));
      }
      qty.clear();
    });
  }

  void saveOrder() {
    if (name.text.trim().isEmpty) {
      snack(context, 'Nama pelanggan harus diisi');
      return;
    }
    if (items.isEmpty) {
      snack(context, 'Tambahkan minimal 1 layanan');
      return;
    }
    final o = LaundryOrder(
      id: uid(),
      no: store.nextNo(),
      ts: DateTime.now().millisecondsSinceEpoch,
      date: today(),
      customer: name.text.trim(),
      phone: normPhone(phone.text),
      items: List.of(items),
      discount: discount,
      payments: [],
      status: 'proses',
      eta: eta,
      note: note.text.trim(),
    );
    final p = math.min(toInt(pay.text), o.total);
    if (p > 0) o.payments.add(Payment(date: today(), amount: p));
    store.orders.add(o);
    store.save();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderDetailPage(o.id)));
  }

  @override
  Widget build(BuildContext context) {
    final recent = <LaundryOrder>[];
    for (final o in store.orders.reversed) {
      if (!recent.any((r) => r.customer.toLowerCase() == o.customer.toLowerCase())) recent.add(o);
      if (recent.length >= 6) break;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Nota Baru', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (recent.isNotEmpty) ...[
          const Text('Pelanggan terakhir', style: TextStyle(fontSize: 12, color: kMut, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final r in recent)
              ActionChip(
                label: Text(r.customer),
                onPressed: () => setState(() {
                  name.text = r.customer;
                  phone.text = r.phone.isEmpty ? '' : '0${r.phone.substring(2)}';
                }),
              ),
          ]),
        ],
        tf('Nama pelanggan', name, kb: TextInputType.name),
        tf('No. WhatsApp', phone, kb: TextInputType.phone, hint: '08123456789'),
        const SizedBox(height: 16),
        const Text('Pilih layanan', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: sid,
              isExpanded: true,
              items: [for (final s in store.services) DropdownMenuItem(value: s.id, child: Text('${s.name} — ${rp(s.price)}/${s.unit}', overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => sid = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: qty, keyboardType: numKb, decoration: const InputDecoration(hintText: 'Jml'))),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(onPressed: addItem, icon: const Icon(Icons.add_rounded), label: const Text('Tambahkan ke nota')),
        ),
        if (items.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              for (var k = 0; k < items.length; k++)
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(items[k].name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('${qf(items[k].qty)} ${items[k].unit} × ${rp(items[k].price)}', style: const TextStyle(fontSize: 12, color: kMut)),
                    ]),
                  ),
                  Text(rp(items[k].line), style: const TextStyle(fontWeight: FontWeight.w800, color: kBlue)),
                  IconButton(icon: const Icon(Icons.close_rounded, color: kBad), onPressed: () => setState(() => items.removeAt(k))),
                ]),
            ]),
          ),
        Row(children: [
          Expanded(child: tf('Diskon (Rp)', disc, kb: TextInputType.number, onChanged: (_) => setState(() {}))),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () async {
                  final d = await pickDate(context, eta);
                  if (d != null) setState(() => eta = d);
                },
                icon: const Icon(Icons.event_rounded),
                label: Text('Est. ${tgl(eta)}', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ]),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: tf('Dibayar sekarang (Rp)', pay, kb: TextInputType.number, onChanged: (_) => setState(() {}))),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(80, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => setState(() => pay.text = total.toString()),
              child: const Text('Lunas'),
            ),
          ),
        ]),
        tf('Catatan', note, hint: 'mis. pakaian putih dipisah'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kBlueL, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            _tr('Subtotal', rp(sub)),
            if (discount > 0) _tr('Diskon', '-${rp(discount)}'),
            _tr('TOTAL', rp(total), big: true),
            _tr('Dibayar', rp(math.min(toInt(pay.text), total))),
            _tr('Sisa', rp(math.max(0, total - toInt(pay.text)))),
          ]),
        ),
        const SizedBox(height: 14),
        bigBtn('Simpan Nota', saveOrder),
        const SizedBox(height: 30),
      ]),
    );
  }
}

Widget _tr(String a, String b, {bool big = false, Color? vc}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(a, style: TextStyle(fontWeight: big ? FontWeight.w800 : FontWeight.w500, fontSize: big ? 17 : 14, color: big ? kBlue : kText)),
        Text(b, style: TextStyle(fontWeight: FontWeight.w800, fontSize: big ? 17 : 14, color: vc ?? (big ? kBlue : kText))),
      ]),
    );

class OrderDetailPage extends StatelessWidget {
  final String id;
  const OrderDetailPage(this.id, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final o = store.orders.where((x) => x.id == id).firstOrNull;
        if (o == null) return const Scaffold(body: Center(child: Text('Nota tidak ditemukan')));
        return Scaffold(
          appBar: AppBar(title: Text(o.no, style: const TextStyle(fontWeight: FontWeight.w800))),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [stBadge(o), const SizedBox(width: 6), payBadge(o)]),
            const SizedBox(height: 4),
            Text('${tgl(o.date)}${o.eta.isNotEmpty ? ' • Estimasi ${tgl(o.eta)}' : ''}', style: const TextStyle(color: kMut, fontSize: 13)),
            const SizedBox(height: 10),
            box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.customer, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              Text(o.phone.isEmpty ? 'Belum ada nomor WhatsApp' : '📱 +${o.phone}', style: const TextStyle(color: kMut)),
              const Divider(height: 22),
              for (final i in o.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(i.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${qf(i.qty)} ${i.unit} × ${rp(i.price)}', style: const TextStyle(fontSize: 12, color: kMut)),
                      ]),
                    ),
                    Text(rp(i.line), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                ),
              if (o.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('📝 ${o.note}', style: const TextStyle(color: kMut, fontSize: 13))),
            ])),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: kBlueL, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                _tr('Subtotal', rp(o.sub)),
                if (o.discount > 0) _tr('Diskon', '-${rp(o.discount)}'),
                _tr('TOTAL', rp(o.total), big: true),
                _tr('Sudah dibayar', rp(o.paid)),
                _tr('Sisa tagihan', rp(o.due), vc: o.due > 0 ? kBad : kOk),
              ]),
            ),
            if (o.payments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Riwayat bayar: ${o.payments.map((p) => '${tgl(p.date)} ${rp(p.amount)}').join(' • ')}', style: const TextStyle(fontSize: 12, color: kMut)),
              ),
            const SizedBox(height: 14),
            const Text('Status cucian', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final e in stLabel.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: o.status == e.key,
                  onSelected: (_) {
                    o.status = e.key;
                    store.save();
                  },
                ),
            ]),
            const SizedBox(height: 16),
            bigBtn('💬  Kirim Invoice via WhatsApp', () => openWA(c, o, invoiceText(o)), color: const Color(0xFF25D366)),
            if (o.status == 'selesai') ...[
              const SizedBox(height: 8),
              bigBtn('🔔  Kabari: Cucian Sudah Selesai', () {
                final s = store.settings;
                var t = 'Halo kak *${o.customer}* 👋\nCucian Anda dengan nota *${o.no}* sudah *SELESAI* dan siap diambil ✨\n';
                t += o.due > 0 ? 'Sisa pembayaran: *${rp(o.due)}*\n' : 'Pembayaran sudah *LUNAS* ✅\n';
                t += '\nTerima kasih,\n*${s.name}*';
                openWA(c, o, t);
              }, color: const Color(0xFF25D366)),
            ],
            if (o.due > 0) ...[
              const SizedBox(height: 8),
              bigBtn('💵  Catat Pembayaran', () async {
                final v = await askText(c, 'Jumlah dibayar (Rp)', initial: o.due.toString(), kb: TextInputType.number);
                if (v == null) return;
                final a = math.min(toInt(v), o.due);
                if (a <= 0) return;
                o.payments.add(Payment(date: today(), amount: a));
                store.save();
                if (c.mounted) snack(c, 'Pembayaran dicatat ✅');
              }),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: bigBtn('📋 Salin Teks', () {
                  Clipboard.setData(ClipboardData(text: invoiceText(o)));
                  snack(c, 'Teks invoice disalin');
                }, outline: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: bigBtn('📱 Ubah No. WA', () async {
                  final v = await askText(c, 'Nomor WhatsApp', initial: o.phone.isEmpty ? '' : '0${o.phone.substring(2)}', kb: TextInputType.phone);
                  if (v == null) return;
                  o.phone = normPhone(v);
                  store.save();
                }, outline: true),
              ),
            ]),
            const SizedBox(height: 8),
            bigBtn('🗑️  Hapus Nota', () async {
              if (!await confirmDlg(c, 'Hapus nota ini? Pemasukannya juga hilang dari laporan.')) return;
              store.orders.removeWhere((x) => x.id == o.id);
              store.save();
              if (c.mounted) Navigator.pop(c);
            }, color: kBad),
            const SizedBox(height: 30),
          ]),
        );
      },
    );
  }
}

/* ===================== LAYANAN ===================== */
class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
        Row(children: [
          const Expanded(child: Text('Jenis Layanan & Harga', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          FilledButton.icon(onPressed: () => openSheet(c, const ServiceSheet()), icon: const Icon(Icons.add_rounded), label: const Text('Tambah')),
        ]),
        const SizedBox(height: 6),
        const Text('Ketuk layanan untuk mengubah nama, satuan atau harga.', style: TextStyle(fontSize: 12, color: kMut)),
        const SizedBox(height: 12),
        if (store.services.isEmpty) empty('🏷️', 'Belum ada layanan'),
        for (final s in store.services)
          box(
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('per ${s.unit}', style: const TextStyle(fontSize: 12, color: kMut)),
                ]),
              ),
              Text(rp(s.price), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: kBlue)),
              const SizedBox(width: 6),
              const Icon(Icons.edit_rounded, size: 18, color: kMut),
            ]),
            onTap: () => openSheet(c, ServiceSheet(s: s)),
          ),
      ]),
    );
  }
}

class ServiceSheet extends StatefulWidget {
  final Service? s;
  const ServiceSheet({super.key, this.s});
  @override
  State<ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends State<ServiceSheet> {
  late final name = TextEditingController(text: widget.s?.name ?? '');
  late final unit = TextEditingController(text: widget.s?.unit ?? 'Kg');
  late final price = TextEditingController(text: widget.s == null ? '' : widget.s!.price.toString());

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.s == null ? 'Layanan Baru' : 'Ubah Layanan', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBlue)),
      tf('Nama layanan', name, hint: 'mis. Cuci Kiloan'),
      tf('Satuan', unit, hint: 'Kg / Pcs / Pasang / Meter'),
      Wrap(spacing: 8, children: [
        for (final u in ['Kg', 'Pcs', 'Pasang', 'Meter', 'Paket'])
          ActionChip(label: Text(u), onPressed: () => setState(() => unit.text = u)),
      ]),
      tf('Harga per satuan (Rp)', price, kb: TextInputType.number),
      const SizedBox(height: 6),
      const Text('Perubahan harga hanya berlaku untuk nota baru. Nota lama tetap memakai harga saat dibuat.', style: TextStyle(fontSize: 12, color: kMut)),
      const SizedBox(height: 14),
      bigBtn('Simpan', () {
        final n = name.text.trim();
        if (n.isEmpty) {
          snack(context, 'Nama layanan harus diisi');
          return;
        }
        final u = unit.text.trim().isEmpty ? 'Pcs' : unit.text.trim();
        final p = toInt(price.text);
        if (widget.s != null) {
          widget.s!.name = n;
          widget.s!.unit = u;
          widget.s!.price = p;
        } else {
          store.services.add(Service(id: uid(), name: n, unit: u, price: p));
        }
        store.save();
        Navigator.pop(context);
      }),
      if (widget.s != null) ...[
        const SizedBox(height: 8),
        bigBtn('Hapus Layanan', () async {
          if (!await confirmDlg(context, 'Hapus layanan ini? Nota lama tidak terpengaruh.')) return;
          store.services.removeWhere((x) => x.id == widget.s!.id);
          store.save();
          if (context.mounted) Navigator.pop(context);
        }, color: kBad),
      ],
    ]);
  }
}

/* ===================== SETRIKA BORONGAN ===================== */
class PeriodBar extends StatelessWidget {
  final Period p;
  final VoidCallback onChange;
  const PeriodBar({super.key, required this.p, required this.onChange});
  @override
  Widget build(BuildContext context) {
    const opts = {PK.today: 'Hari ini', PK.week: 'Minggu ini', PK.month: 'Bulan ini', PK.last: 'Bulan lalu', PK.all: 'Semua', PK.custom: 'Pilih tanggal'};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final e in opts.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(e.value),
                selected: p.k == e.key,
                onSelected: (_) {
                  p.k = e.key;
                  onChange();
                },
              ),
            ),
        ]),
      ),
      if (p.k == PK.custom)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final d = await pickDate(context, p.from);
                  if (d != null) {
                    p.from = d;
                    onChange();
                  }
                },
                child: Text(p.from.isEmpty ? 'Dari tanggal' : tgl(p.from)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final d = await pickDate(context, p.to);
                  if (d != null) {
                    p.to = d;
                    onChange();
                  }
                },
                child: Text(p.to.isEmpty ? 'Sampai tanggal' : tgl(p.to)),
              ),
            ),
          ]),
        ),
      const SizedBox(height: 8),
    ]);
  }
}

class IronPage extends StatefulWidget {
  const IronPage({super.key});
  @override
  State<IronPage> createState() => _IronPageState();
}

class _IronPageState extends State<IronPage> {
  final p = Period();
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final r = p.range();
        final E = store.iron.where((e) => inR(e.date, r)).toList()
          ..sort((a, b) {
            final x = b.date.compareTo(a.date);
            return x != 0 ? x : b.ts.compareTo(a.ts);
          });
        final tot = E.fold<int>(0, (a, e) => a + e.amount);
        final unp = E.where((e) => !e.paid).fold<int>(0, (a, e) => a + e.amount);
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
          Row(children: [
            const Expanded(child: Text('Upah Setrika Borongan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const EmployeesPage())),
              icon: const Icon(Icons.group_rounded),
              label: const Text('Karyawan'),
            ),
          ]),
          const SizedBox(height: 10),
          PeriodBar(p: p, onChange: () => setState(() {})),
          Row(children: [
            Expanded(child: stat('Total upah', rp(tot), '👔', hot: true)),
            const SizedBox(width: 12),
            Expanded(child: stat('Belum dibayar', rp(unp), '⏳', vc: kBad)),
          ]),
          bigBtn('➕  Catat Hasil Setrika', () {
            if (store.employees.isEmpty) {
              snack(c, 'Tambahkan karyawan dulu');
              Navigator.push(c, MaterialPageRoute(builder: (_) => const EmployeesPage()));
              return;
            }
            openSheet(c, const IronSheet());
          }),
          title('Rekap per karyawan'),
          if (store.employees.isEmpty) empty('👔', 'Belum ada karyawan.\nTekan tombol "Karyawan" untuk menambah.'),
          for (final m in store.employees)
            Builder(builder: (_) {
              final es = E.where((e) => e.empId == m.id).toList();
              final q = es.fold<double>(0, (a, e) => a + e.qty);
              final t = es.fold<int>(0, (a, e) => a + e.amount);
              final u = es.where((e) => !e.paid).fold<int>(0, (a, e) => a + e.amount);
              return box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('👤 ${m.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('Tarif ${rp(m.rate)}/${m.unit} • ${es.length} catatan', style: const TextStyle(fontSize: 12, color: kMut)),
                    ]),
                  ),
                  Text(rp(t), style: const TextStyle(fontWeight: FontWeight.w800, color: kBlue)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: Text('Total ${qf(q)} ${m.unit} • belum dibayar ${rp(u)}', style: TextStyle(fontSize: 12, color: u > 0 ? kBad : kOk, fontWeight: FontWeight.w700)),
                  ),
                  if (u > 0)
                    FilledButton(
                      onPressed: () async {
                        if (!await confirmDlg(c, 'Bayar upah ${m.name} sebesar ${rp(u)}?\n(Otomatis tercatat sebagai pengeluaran di laporan)')) return;
                        store.payWage(m, r);
                        if (c.mounted) snack(c, 'Upah dibayar & dicatat ✅');
                      },
                      child: const Text('Bayar Upah'),
                    )
                  else
                    badge('LUNAS', const Color(0xFFD3F9E9), const Color(0xFF08805C)),
                ]),
              ]));
            }),
          title('Riwayat catatan'),
          if (E.isEmpty) empty('📝', 'Belum ada catatan pada periode ini'),
          for (final e in E)
            Builder(builder: (_) {
              final m = store.employees.where((x) => x.id == e.empId).firstOrNull;
              return box(
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(m?.name ?? '(dihapus)', style: const TextStyle(fontWeight: FontWeight.w800))),
                        const SizedBox(width: 6),
                        e.paid ? badge('dibayar', const Color(0xFFD3F9E9), const Color(0xFF08805C)) : badge('belum', const Color(0xFFFFF0D6), const Color(0xFFB36B00)),
                      ]),
                      Text('${tgl(e.date)} • ${qf(e.qty)} ${m?.unit ?? ''} × ${rp(e.rate)}${e.note.isNotEmpty ? ' • ${e.note}' : ''}', style: const TextStyle(fontSize: 12, color: kMut)),
                    ]),
                  ),
                  Text(rp(e.amount), style: const TextStyle(fontWeight: FontWeight.w800, color: kBlue)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: kBad),
                    onPressed: () async {
                      if (!await confirmDlg(c, 'Hapus catatan ini?')) return;
                      store.iron.removeWhere((x) => x.id == e.id);
                      store.save();
                    },
                  ),
                ]),
                pad: const EdgeInsets.fromLTRB(15, 8, 4, 8),
              );
            }),
        ]);
      },
    );
  }
}

class EmployeesPage extends StatelessWidget {
  const EmployeesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Karyawan Setrika', style: TextStyle(fontWeight: FontWeight.w800))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        onPressed: () => openSheet(context, const EmployeeSheet()),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Tambah'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (c, _) => ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
          const Text('Atur nama, satuan hitung (Kg / Potong) dan tarif borongan per satuan.', style: TextStyle(fontSize: 12, color: kMut)),
          const SizedBox(height: 10),
          if (store.employees.isEmpty) empty('👥', 'Belum ada karyawan'),
          for (final m in store.employees)
            box(
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('per ${m.unit}', style: const TextStyle(fontSize: 12, color: kMut)),
                  ]),
                ),
                Text(rp(m.rate), style: const TextStyle(fontWeight: FontWeight.w800, color: kBlue)),
                const SizedBox(width: 6),
                const Icon(Icons.edit_rounded, size: 18, color: kMut),
              ]),
              onTap: () => openSheet(c, EmployeeSheet(m: m)),
            ),
        ]),
      ),
    );
  }
}

class EmployeeSheet extends StatefulWidget {
  final Employee? m;
  const EmployeeSheet({super.key, this.m});
  @override
  State<EmployeeSheet> createState() => _EmployeeSheetState();
}

class _EmployeeSheetState extends State<EmployeeSheet> {
  late final name = TextEditingController(text: widget.m?.name ?? '');
  late final rate = TextEditingController(text: widget.m == null ? '' : widget.m!.rate.toString());
  late String unit = widget.m?.unit ?? 'Kg';

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.m == null ? 'Karyawan Baru' : 'Ubah Karyawan', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBlue)),
      tf('Nama', name),
      const SizedBox(height: 12),
      const Text('Satuan hitung', style: TextStyle(fontWeight: FontWeight.w700)),
      Wrap(spacing: 8, children: [
        for (final u in ['Kg', 'Potong'])
          ChoiceChip(label: Text(u), selected: unit == u, onSelected: (_) => setState(() => unit = u)),
      ]),
      tf('Tarif borongan per satuan (Rp)', rate, kb: TextInputType.number, hint: 'mis. 1500'),
      const SizedBox(height: 14),
      bigBtn('Simpan', () {
        final n = name.text.trim();
        if (n.isEmpty) {
          snack(context, 'Nama harus diisi');
          return;
        }
        final r = toInt(rate.text);
        if (widget.m != null) {
          widget.m!.name = n;
          widget.m!.unit = unit;
          widget.m!.rate = r;
        } else {
          store.employees.add(Employee(id: uid(), name: n, unit: unit, rate: r));
        }
        store.save();
        Navigator.pop(context);
      }),
      if (widget.m != null) ...[
        const SizedBox(height: 8),
        bigBtn('Hapus Karyawan', () async {
          if (!await confirmDlg(context, 'Hapus karyawan ini? Catatan setrikanya tetap tersimpan.')) return;
          store.employees.removeWhere((x) => x.id == widget.m!.id);
          store.save();
          if (context.mounted) Navigator.pop(context);
        }, color: kBad),
      ],
    ]);
  }
}

class IronSheet extends StatefulWidget {
  const IronSheet({super.key});
  @override
  State<IronSheet> createState() => _IronSheetState();
}

class _IronSheetState extends State<IronSheet> {
  late String empId = store.employees.first.id;
  String date = today();
  final qty = TextEditingController();
  final note = TextEditingController();
  late final rate = TextEditingController(text: store.employees.first.rate.toString());

  Employee get emp => store.employees.firstWhere((e) => e.id == empId);

  @override
  Widget build(BuildContext context) {
    final total = (toD(qty.text) * toInt(rate.text)).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Catat Hasil Setrika', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBlue)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: empId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Karyawan'),
        items: [for (final e in store.employees) DropdownMenuItem(value: e.id, child: Text(e.name))],
        onChanged: (v) => setState(() {
          empId = v ?? empId;
          rate.text = emp.rate.toString();
        }),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: () async {
          final d = await pickDate(context, date);
          if (d != null) setState(() => date = d);
        },
        icon: const Icon(Icons.event_rounded),
        label: Text('Tanggal: ${tgl(date)}'),
      ),
      Row(children: [
        Expanded(child: tf('Jumlah (${emp.unit})', qty, kb: numKb, onChanged: (_) => setState(() {}))),
        const SizedBox(width: 10),
        Expanded(child: tf('Tarif / satuan (Rp)', rate, kb: TextInputType.number, onChanged: (_) => setState(() {}))),
      ]),
      tf('Catatan (opsional)', note, hint: 'mis. cucian pak Budi'),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kBlueL, borderRadius: BorderRadius.circular(16)),
        child: _tr('Upah', rp(total), big: true),
      ),
      const SizedBox(height: 14),
      bigBtn('Simpan', () {
        final q = toD(qty.text);
        if (q <= 0) {
          snack(context, 'Isi jumlah dulu');
          return;
        }
        store.iron.add(IronEntry(id: uid(), ts: DateTime.now().millisecondsSinceEpoch, date: date, empId: empId, qty: q, rate: toInt(rate.text), note: note.text.trim()));
        store.save();
        Navigator.pop(context);
      }),
    ]);
  }
}

/* ===================== LAPORAN ===================== */
class ReportPage extends StatefulWidget {
  const ReportPage({super.key});
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final p = Period();
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final r = p.range();
        final income = store.incomeIn(r);
        final dayInc = <String, int>{};
        for (final o in store.orders) {
          for (final pay in o.payments) {
            if (inR(pay.date, r)) dayInc[pay.date] = (dayInc[pay.date] ?? 0) + pay.amount;
          }
        }
        final O = store.orders.where((o) => inR(o.date, r)).toList();
        final omzet = O.fold<int>(0, (a, o) => a + o.total);
        final X = store.expenses.where((e) => inR(e.date, r)).toList()..sort((a, b) => b.date.compareTo(a.date));
        final exp = X.fold<int>(0, (a, e) => a + e.amount);
        final laba = income - exp;
        final bySvc = <String, List<dynamic>>{};
        for (final o in O) {
          for (final i in o.items) {
            final k = '${i.name}|${i.unit}';
            final b = bySvc.putIfAbsent(k, () => [i.name, i.unit, 0.0, 0]);
            b[2] = (b[2] as double) + i.qty;
            b[3] = (b[3] as int) + i.line;
          }
        }
        final SV = bySvc.values.toList()..sort((a, b) => (b[3] as int).compareTo(a[3] as int));
        final byCat = <String, int>{};
        for (final e in X) {
          byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
        }
        final days = dayInc.keys.toList()..sort((a, b) => b.compareTo(a));
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
          const Text('Laporan Keuangan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          PeriodBar(p: p, onChange: () => setState(() {})),
          Row(children: [
            Expanded(child: stat('Pemasukan (kas)', rp(income), '📥', hot: true)),
            const SizedBox(width: 12),
            Expanded(child: stat('Pengeluaran', rp(exp), '📤', vc: kBad)),
          ]),
          stat('Laba bersih (pemasukan − pengeluaran)', rp(laba), laba >= 0 ? '😄' : '😟', vc: laba >= 0 ? kOk : kBad),
          Row(children: [
            Expanded(child: stat('Omzet nota (${O.length})', rp(omzet), '🧾')),
            const SizedBox(width: 12),
            Expanded(child: stat('Total piutang', rp(store.piutang), '⏳', vc: kWarn)),
          ]),
          Row(children: [
            Expanded(
              child: bigBtn('💬 Kirim ke WA', () {
                final s = store.settings;
                final t = '*LAPORAN KEUANGAN ${s.name.toUpperCase()}*\nPeriode: ${p.label()}\n━━━━━━━━━━━━━━\nPemasukan : ${rp(income)}\nPengeluaran: ${rp(exp)}\n*Laba bersih: ${rp(laba)}*\n━━━━━━━━━━━━━━\nJumlah nota: ${O.length}\nOmzet nota : ${rp(omzet)}\nPiutang    : ${rp(store.piutang)}';
                launchWA(c, '', t);
              }, outline: true),
            ),
            const SizedBox(width: 8),
            Expanded(child: bigBtn('➕ Pengeluaran', () => openSheet(c, const ExpenseSheet()))),
          ]),
          title('Pendapatan per layanan'),
          if (SV.isEmpty) empty('📊', 'Belum ada data') else box(Column(children: [
            for (final s in SV)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s[0] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('${qf(s[2] as double)} ${s[1]}', style: const TextStyle(fontSize: 12, color: kMut)),
                    ]),
                  ),
                  Text(rp(s[3] as int), style: const TextStyle(fontWeight: FontWeight.w800, color: kBlue)),
                ]),
              ),
          ])),
          title('Pemasukan harian'),
          if (days.isEmpty) empty('💰', 'Belum ada pemasukan') else box(Column(children: [
            for (final d in days)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(tgl(d)),
                  Text(rp(dayInc[d] ?? 0), style: const TextStyle(fontWeight: FontWeight.w800, color: kBlue)),
                ]),
              ),
          ])),
          title('Pengeluaran'),
          if (X.isEmpty) empty('🧾', 'Belum ada pengeluaran') else box(Column(children: [
            for (final e in byCat.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  badge(e.key, kBlueL, kBlue),
                  Text(rp(e.value), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              ),
            const Divider(height: 22),
            for (final e in X)
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.category, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${tgl(e.date)}${e.note.isNotEmpty ? ' • ${e.note}' : ''}', style: const TextStyle(fontSize: 12, color: kMut)),
                  ]),
                ),
                Text(rp(e.amount), style: const TextStyle(fontWeight: FontWeight.w800, color: kBad)),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: kBad),
                  onPressed: () async {
                    if (!await confirmDlg(c, 'Hapus pengeluaran ini?')) return;
                    store.expenses.removeWhere((x) => x.id == e.id);
                    store.save();
                  },
                ),
              ]),
          ])),
        ]);
      },
    );
  }
}

class ExpenseSheet extends StatefulWidget {
  const ExpenseSheet({super.key});
  @override
  State<ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<ExpenseSheet> {
  String date = today();
  final cat = TextEditingController();
  final amt = TextEditingController();
  final note = TextEditingController();
  static const cats = ['Deterjen & Pewangi', 'Listrik & Air', 'Gaji Karyawan', 'Sewa Tempat', 'Plastik & Kemasan', 'Perawatan Mesin', 'Gas / BBM', 'Lainnya'];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Catat Pengeluaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBlue)),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: () async {
          final d = await pickDate(context, date);
          if (d != null) setState(() => date = d);
        },
        icon: const Icon(Icons.event_rounded),
        label: Text('Tanggal: ${tgl(date)}'),
      ),
      tf('Kategori', cat, hint: 'Pilih di bawah / ketik sendiri'),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: [
        for (final k in cats) ActionChip(label: Text(k), onPressed: () => setState(() => cat.text = k)),
      ]),
      tf('Nominal (Rp)', amt, kb: TextInputType.number),
      tf('Catatan (opsional)', note),
      const SizedBox(height: 14),
      bigBtn('Simpan', () {
        final a = toInt(amt.text);
        if (a <= 0) {
          snack(context, 'Nominal harus diisi');
          return;
        }
        final k = cat.text.trim().isEmpty ? 'Lainnya' : cat.text.trim();
        store.expenses.add(Expense(id: uid(), date: date, category: k, amount: a, note: note.text.trim()));
        store.save();
        Navigator.pop(context);
      }),
    ]);
  }
}

/* ===================== PENGATURAN ===================== */
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final name = TextEditingController(text: store.settings.name);
  late final address = TextEditingController(text: store.settings.address);
  late final phone = TextEditingController(text: store.settings.phone);
  late final bank = TextEditingController(text: store.settings.bank);
  late final footer = TextEditingController(text: store.settings.footer);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Usaha', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        tf('Nama usaha', name),
        tf('Alamat', address, hint: 'Alamat laundry'),
        tf('No. Telp / WA usaha', phone, kb: TextInputType.phone),
        tf('Info rekening (tampil di invoice bila ada tagihan)', bank, lines: 2, hint: 'mis. BCA 1234567890 a.n. Bersih Laundry'),
        tf('Pesan penutup invoice', footer, lines: 2),
        const SizedBox(height: 14),
        bigBtn('Simpan', () {
          store.settings = Settings(
            name: name.text.trim().isEmpty ? 'BERSIH LAUNDRY' : name.text.trim(),
            address: address.text.trim(),
            phone: phone.text.trim(),
            bank: bank.text.trim(),
            footer: footer.text.trim(),
          );
          store.save();
          Navigator.pop(context);
        }),
        const Divider(height: 36),
        const Text('Cadangan Data', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('Data tersimpan di HP ini. Salin cadangan lalu tempel/simpan di tempat aman (mis. WhatsApp ke diri sendiri atau catatan), agar data aman bila HP hilang atau aplikasi terhapus.', style: TextStyle(fontSize: 12, color: kMut)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: bigBtn('Salin Cadangan', () {
              Clipboard.setData(ClipboardData(text: jsonEncode(store.toJson())));
              snack(context, 'Cadangan disalin ke clipboard');
            }, outline: true),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: bigBtn('Pulihkan', () async {
              final v = await askText(context, 'Tempel teks cadangan di sini', lines: 4);
              if (v == null || v.trim().isEmpty) return;
              try {
                final d = jsonDecode(v.trim()) as Map<String, dynamic>;
                if (d['services'] == null || d['orders'] == null) throw 'x';
                if (!context.mounted) return;
                if (!await confirmDlg(context, 'Pulihkan data dari cadangan? Data saat ini akan diganti.')) return;
                store.fromJson(d);
                store.save();
                if (context.mounted) snack(context, 'Data dipulihkan ✅');
              } catch (_) {
                if (context.mounted) snack(context, 'Teks cadangan tidak valid');
              }
            }, outline: true),
          ),
        ]),
        const SizedBox(height: 14),
        bigBtn('Hapus Semua Data', () async {
          if (!await confirmDlg(context, 'Yakin hapus SEMUA data? Tidak bisa dibatalkan.')) return;
          if (!context.mounted) return;
          if (!await confirmDlg(context, 'Sekali lagi: semua nota, laporan, dan karyawan akan hilang.')) return;
          store.seed();
          store.save();
          if (context.mounted) snack(context, 'Data direset');
        }, color: kBad),
        const SizedBox(height: 16),
        const Center(child: Text('Bersih Laundry v1.0', style: TextStyle(fontSize: 12, color: kMut))),
      ]),
    );
  }
}
