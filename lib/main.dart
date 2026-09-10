import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'institutions_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(QersheenApp(prefs: prefs));
}

// ================= نماذج الأقساط والميزانيات =================
class InstallmentModel {
  final String id;
  String title;
  String provider; // مثلا: فاليو، أمان، بنك مصر
  double monthlyAmount;
  int totalMonths;
  int paidMonths;
  int dueDayOfMonth;

  InstallmentModel({
    required this.id,
    required this.title,
    required this.provider,
    required this.monthlyAmount,
    required this.totalMonths,
    required this.paidMonths,
    required this.dueDayOfMonth,
  });

  double get remainingAmount => monthlyAmount * (totalMonths - paidMonths);
  double get progress => totalMonths > 0 ? (paidMonths / totalMonths).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'provider': provider,
    'monthlyAmount': monthlyAmount, 'totalMonths': totalMonths,
    'paidMonths': paidMonths, 'dueDayOfMonth': dueDayOfMonth,
  };

  factory InstallmentModel.fromJson(Map<String, dynamic> j) => InstallmentModel(
    id: j['id'], title: j['title'], provider: j['provider'] ?? 'عام',
    monthlyAmount: (j['monthlyAmount'] as num).toDouble(),
    totalMonths: j['totalMonths'] ?? 1,
    paidMonths: j['paidMonths'] ?? 0,
    dueDayOfMonth: j['dueDayOfMonth'] ?? 1,
  );
}

class CategoryBudget {
  final String category;
  double monthlyLimit;

  CategoryBudget({required this.category, required this.monthlyLimit});

  Map<String, dynamic> toJson() => {'category': category, 'monthlyLimit': monthlyLimit};
  factory CategoryBudget.fromJson(Map<String, dynamic> j) => CategoryBudget(
    category: j['category'],
    monthlyLimit: (j['monthlyLimit'] as num).toDouble(),
  );
}

class AppData extends ChangeNotifier {
  final SharedPreferences prefs;
  bool isDarkMode;
  bool isBiometricEnabled;
  bool isAuthenticated = false;
  double dailyBudgetLimit;
  List<UserCardModel> userCards = [];
  List<InstallmentModel> installments = [];
  Map<String, double> categoryBudgets = {};
  Set<String> processedMessageFingerprints = {};
  final LocalAuthentication _auth = LocalAuthentication();

  AppData(this.prefs)
      : isDarkMode = prefs.getBool('isDark') ?? true,
        isBiometricEnabled = prefs.getBool('isBioEnabled') ?? false,
        dailyBudgetLimit = prefs.getDouble('dailyLimit') ?? 600.0 {
    _loadAll();
    _startNotificationListener();
    _checkInitialAuth();
  }

  void _checkInitialAuth() {
    if (!isBiometricEnabled) isAuthenticated = true;
  }

  Future<bool> authenticateUser() async {
    try {
      final canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) {
        isAuthenticated = true;
        notifyListeners();
        return true;
      }
      final didAuth = await _auth.authenticate(
        localizedReason: 'يرجى تأكيد هويتك لفتح محفظة قرشين بأمان',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
      isAuthenticated = didAuth;
      notifyListeners();
      return didAuth;
    } catch (_) {
      isAuthenticated = true;
      notifyListeners();
      return true;
    }
  }

  void toggleBiometric(bool val) {
    isBiometricEnabled = val;
    prefs.setBool('isBioEnabled', val);
    notifyListeners();
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    prefs.setBool('isDark', isDarkMode);
    notifyListeners();
  }

  void updateDailyLimit(double limit) {
    dailyBudgetLimit = limit;
    prefs.setDouble('dailyLimit', limit);
    notifyListeners();
  }

  void _loadAll() {
    // 1. البطاقات
    final String? cardsJson = prefs.getString('cardsData_v20');
    if (cardsJson != null && cardsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(cardsJson);
      userCards = decoded.map((e) => UserCardModel.fromJson(e)).toList();
    } else {
      userCards = [
        UserCardModel(
          id: 'cash_wallet_main', bankId: 'cash',
          cardIdentifier: 'محفظة النقود اليدوية', balance: 0.0, transactions: [],
        )
      ];
      saveCards();
    }

    // 2. الأقساط
    final String? instJson = prefs.getString('installments_v20');
    if (instJson != null && instJson.isNotEmpty) {
      final List<dynamic> decInst = jsonDecode(instJson);
      installments = decInst.map((e) => InstallmentModel.fromJson(e)).toList();
    }

    // 3. ميزانيات التصنيفات
    final String? budJson = prefs.getString('catBudgets_v20');
    if (budJson != null && budJson.isNotEmpty) {
      final Map<String, dynamic> decBud = jsonDecode(budJson);
      categoryBudgets = decBud.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } else {
      categoryBudgets = {
        'فواتير ومشتريات': 3000.0,
        'سوبرماركت ومأكولات': 4000.0,
        'تحويلات': 2000.0,
        'سحب كاش': 5000.0,
        'عام': 1500.0,
      };
      saveCategoryBudgets();
    }

    final List<String>? fps = prefs.getStringList('processed_fps_v20');
    if (fps != null) processedMessageFingerprints = fps.toSet();
  }

  void saveCards() {
    prefs.setString('cardsData_v20', jsonEncode(userCards.map((c) => c.toJson()).toList()));
    prefs.setStringList('processed_fps_v20', processedMessageFingerprints.toList());
    notifyListeners();
  }

  void saveInstallments() {
    prefs.setString('installments_v20', jsonEncode(installments.map((i) => i.toJson()).toList()));
    notifyListeners();
  }

  void saveCategoryBudgets() {
    prefs.setString('catBudgets_v20', jsonEncode(categoryBudgets));
    notifyListeners();
  }

  void addInstallment(String title, String provider, double monthly, int months, int dueDay) {
    installments.add(InstallmentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      provider: provider,
      monthlyAmount: monthly,
      totalMonths: months,
      paidMonths: 0,
      dueDayOfMonth: dueDay,
    ));
    saveInstallments();
  }

  void markInstallmentPaid(String id) {
    final inst = installments.firstWhere((i) => i.id == id);
    if (inst.paidMonths < inst.totalMonths) {
      inst.paidMonths++;
      saveInstallments();
    }
  }

  void setCategoryBudget(String category, double limit) {
    categoryBudgets[category] = limit;
    saveCategoryBudgets();
  }

  double getCategoryMonthlySpent(String category) {
    double total = 0.0;
    final now = DateTime.now();
    final monthStr = '/${now.month}/${now.year}';
    for (var card in userCards) {
      for (var tx in card.transactions) {
        if (!tx.isIncome && (tx.category == category || (category == 'عام' && tx.category.isEmpty)) && tx.date.contains(monthStr)) {
          total += tx.amount;
        }
      }
    }
    return total;
  }

  void addNewCard(BankEntity entity, {String? customId}) {
    if (userCards.any((c) => c.bankId == entity.id)) return;
    String idStr = entity.entityType == EntityType.wallet 
        ? (customId ?? '010XXXXXXXX') 
        : (customId ?? '•••• ${(1000 + (DateTime.now().microsecond % 9000))}');

    userCards.insert(0, UserCardModel(
      id: '${entity.id}_${DateTime.now().millisecondsSinceEpoch}',
      bankId: entity.id, cardIdentifier: idStr, balance: 0.0, transactions: [],
    ));
    saveCards();
  }

  void addManualCashTx({required String title, required double amount, required bool isIncome, required String category}) {
    final cashCard = userCards.firstWhere((c) => c.bankId == 'cash', orElse: () {
      final c = UserCardModel(id: 'cash_wallet_main', bankId: 'cash', cardIdentifier: 'محفظة النقود اليدوية', balance: 0.0, transactions: []);
      userCards.add(c);
      return c;
    });

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} • ${now.day}/${now.month}/${now.year}';

    if (isIncome) {
      cashCard.balance += amount;
    } else {
      cashCard.balance -= amount;
    }

    cashCard.transactions.insert(0, TransactionItem(
      name: title, subtitle: 'نقدي (كاش)', date: timeStr, amount: amount, isIncome: isIncome, category: category, txFingerprint: 'cash_${now.millisecondsSinceEpoch}',
    ));
    saveCards();
  }

  void editTransaction(String cardId, int txIndex, {required String newName, required double newAmount, required String newCategory}) {
    final card = userCards.firstWhere((c) => c.id == cardId);
    final oldTx = card.transactions[txIndex];
    final diff = newAmount - oldTx.amount;
    if (diff != 0) {
      if (oldTx.isIncome) {
        card.balance += diff;
      } else {
        card.balance -= diff;
      }
    }

    card.transactions[txIndex] = TransactionItem(
      name: newName, subtitle: oldTx.subtitle, date: oldTx.date, amount: newAmount, isIncome: oldTx.isIncome, category: newCategory, txFingerprint: oldTx.txFingerprint,
    );
    saveCards();
  }

  double getTotalBalance() {
    double total = 0.0;
    for (var c in userCards) total += c.balance;
    return total;
  }

  double getTodayExpenses() {
    double sum = 0.0;
    final now = DateTime.now();
    final todayStr = '${now.day}/${now.month}/${now.year}';
    for (var card in userCards) {
      for (var tx in card.transactions) {
        if (!tx.isIncome && tx.date.contains(todayStr)) sum += tx.amount;
      }
    }
    return sum;
  }

  // ================= تصدير كشف حساب PDF رسومي =================
  Future<void> exportPdfReport() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    double totalIn = 0.0;
    double totalOut = 0.0;
    for (var c in userCards) {
      for (var t in c.transactions) {
        if (t.isIncome) totalIn += t.amount; else totalOut += t.amount;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('تقرير المعاملات المالية - تطبيق قرشين', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                pw.Text('${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [pw.Text('إجمالي الدخل', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)), pw.Text('+${totalIn.toStringAsFixed(0)} ج.م', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800))]),
                pw.Column(children: [pw.Text('إجمالي المصروفات', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)), pw.Text('-${totalOut.toStringAsFixed(0)} ج.م', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red800))]),
                pw.Column(children: [pw.Text('صافي الرصيد', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)), pw.Text('${(totalIn - totalOut).toStringAsFixed(0)} ج.م', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800))]),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text('سجل المعاملات والعمليات:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['الحساب', 'المعاملة', 'التصنيف', 'المبلغ', 'التاريخ'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
            cellAlignment: pw.Alignment.centerRight,
            data: userCards.expand((c) => c.transactions.take(30).map((t) => [
              c.bank.name,
              t.name,
              t.category,
              '${t.isIncome ? '+' : '-'}${t.amount.toStringAsFixed(0)} ج.م',
              t.date,
            ])).toList(),
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'qersheen_financial_statement.pdf');
  }

  void clearAll() {
    userCards.clear();
    processedMessageFingerprints.clear();
    installments.clear();
    userCards.add(UserCardModel(id: 'cash_wallet_main', bankId: 'cash', cardIdentifier: 'محفظة النقود اليدوية', balance: 0.0, transactions: []));
    saveCards();
    saveInstallments();
  }

  void _startNotificationListener() {
    try {
      NotificationListenerService.notificationsStream.listen((event) {
        final title = event.title ?? '';
        final content = event.content ?? '';
        final bank = EgyptInstitutions.matchSender(title);
        if (bank != null) {
          _processMessage(bank, '$title $content', DateTime.now(), null);
        }
      });
    } catch (_) {}
  }

  Future<void> requestBatteryOptimizationIgnore() async {
    await Permission.ignoreBatteryOptimizations.request();
  }

  Future<int> autoDetectChronological() async {
    int count = 0;
    try {
      final status = await Permission.sms.request();
      if (!status.isGranted) return -1;

      final rawMessages = await SmsQuery().querySms(kinds: [SmsQueryKind.inbox]);
      rawMessages.sort((a, b) => (a.date ?? DateTime.now()).compareTo(b.date ?? DateTime.now()));

      List<_StitchedSMS> stitched = [];
      _StitchedSMS? current;

      for (var msg in rawMessages) {
        final sender = msg.address ?? '';
        final body = msg.body ?? '';
        final date = msg.date ?? DateTime.now();

        if (current != null && current.sender == sender && date.difference(current.date).inSeconds.abs() <= 3) {
          current.body += ' $body';
          current.ids.add(msg.id.toString());
        } else {
          if (current != null) stitched.add(current);
          current = _StitchedSMS(sender: sender, body: body, date: date, ids: [msg.id.toString()]);
        }
      }
      if (current != null) stitched.add(current);

      for (var s in stitched) {
        final bank = EgyptInstitutions.matchSender(s.sender);
        if (bank != null) {
          _processMessage(bank, s.body, s.date, s.ids.join('_'));
          count++;
        }
      }
    } catch (_) {}
    return count;
  }

  void _processMessage(BankEntity bank, String rawText, DateTime timestamp, String? uniqueSmsId) {
    final text = rawText.replaceAll('\n', ' ').trim();
    final fingerprint = uniqueSmsId ?? '${bank.id}_${timestamp.millisecondsSinceEpoch}_${text.hashCode}';

    String? phone;
    if (bank.entityType == EntityType.wallet) {
      final p = RegExp(r'(?:محفظتك|لرقم|على رقم)?\s*(01[0125][0-9]{8})').firstMatch(text);
      if (p != null) phone = p.group(1);
    }
    String? acc;
    if (bank.entityType == EntityType.bank) {
      final a = RegExp(r'(?:حسابك المنتهي بـ|بطاقتك المنتهية بـ)\s*(?:\*+)?(\d{4})').firstMatch(text);
      if (a != null) acc = '•••• ${a.group(1)}';
    }

    if (!userCards.any((c) => c.bankId == bank.id)) {
      addNewCard(bank, customId: phone ?? acc);
    }
    final card = userCards.firstWhere((c) => c.bankId == bank.id);

    if (phone != null && card.cardIdentifier.contains('X')) {
      card.cardIdentifier = phone;
      saveCards();
    } else if (acc != null && card.cardIdentifier.startsWith('•••• 0')) {
      card.cardIdentifier = acc;
      saveCards();
    }

    final balMatch = RegExp(
      r'(?:رصيد(?:ك| حسابك)? (?:الحالي|المتاح)|رصيد محفظتك الحالي|current .*?balance is|balance is)\s*[:=]?\s*(\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);

    bool hasExplicitBalance = false;
    if (balMatch != null) {
      final bVal = double.tryParse(balMatch.group(1)!);
      if (bVal != null) {
        card.balance = bVal;
        hasExplicitBalance = true;
        saveCards();
      }
    }

    final isInquiry = (text.contains('balance is') && !text.contains('transferred')) ||
        (text.startsWith('رصيد حسابك') && !text.contains('تم دفع') && !text.contains('تم تحويل') && !text.contains('تم استلام'));
    if (isInquiry) return;

    if (processedMessageFingerprints.contains(fingerprint)) return;

    String title = 'معاملة مالية';
    String? sub;
    bool isIncome = false;
    String category = 'عام';

    if (text.contains('تم سحب') || text.contains('سحب نقدي') || text.contains('Cash withdrawal')) {
      title = 'سحب نقدي ATM';
      category = 'سحب كاش';
      isIncome = false;
    } else if (text.contains('تم استلام') || text.contains('تحويل وارد') || text.contains('تحويل لحظي')) {
      isIncome = true;
      category = 'تحويلات';
      final name = RegExp(r'المسجل بإسم\s+([A-Za-z\u0621-\u064A\s]+?)(?:\s+على رقم|\s+رصيدك|\s+بتاريخ|\.)').firstMatch(text) ??
          RegExp(r'من\s+([A-Za-z\u0621-\u064A\s]+?)(?:\s+برقم مرجعي|\s+على رقم|\s+لحسابك|\s+بتاريخ|\.)').firstMatch(text);
      final pNum = RegExp(r'من رقم\s*(01[0125][0-9]{8})').firstMatch(text);
      if (name != null) {
        title = 'استلام من ${name.group(1)!.trim()}';
        if (pNum != null) sub = pNum.group(1);
      } else if (pNum != null) {
        title = 'استلام من ${pNum.group(1)}';
      } else {
        title = 'تحويل وارد';
      }
    } else if (text.contains('تم دفع') || text.contains('دفع مبلغ') || text.contains('شراء')) {
      isIncome = false;
      category = 'فواتير ومشتريات';
      final m = RegExp(r'لـ?([A-Za-z0-9_\-\u0621-\u064A\s]+?)(?:\.|\s+رصيد|\s+رقم|\s+بمبلغ)').firstMatch(text);
      title = m != null ? 'دفع لـ ${m.group(1)!.trim()}' : 'سداد مشتريات';
    } else if (text.contains('تم تحويل') || text.contains('transferred to') || text.contains('تحويل إلى')) {
      isIncome = false;
      category = 'تحويلات';
      final tNum = RegExp(r'(?:لرقم|to|إلى)\s*(01[0125][0-9]{8})').firstMatch(text);
      title = tNum != null ? 'تحويل إلى ${tNum.group(1)}' : 'تحويل صادر';
    }

    final amtMatch = RegExp(r'(?:مبلغ|سحب|تحويل|transferred)\s*[:=]?\s*(\d+(?:\.\d{1,2})?)\s*(?:جنية|جنيه|ج\.م|L\.E|LE|EGP)?', caseSensitive: false).firstMatch(text) ??
        RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:L\.E|LE|EGP|جنية|جنيه|ج\.م)').firstMatch(text);

    if (amtMatch != null) {
      final amt = double.tryParse(amtMatch.group(1)!);
      if (amt != null && amt > 0) {
        final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')} • ${timestamp.day}/${timestamp.month}/${timestamp.year}';
        
        if (!hasExplicitBalance) {
          if (isIncome) card.balance += amt; else card.balance -= amt;
        }

        card.transactions.insert(0, TransactionItem(
          name: title, subtitle: sub, date: timeStr, amount: amt, isIncome: isIncome, category: category, txFingerprint: fingerprint,
        ));
        processedMessageFingerprints.add(fingerprint);
        saveCards();
      }
    }
  }
}

class _StitchedSMS {
  final String sender;
  String body;
  final DateTime date;
  final List<String> ids;
  _StitchedSMS({required this.sender, required this.body, required this.date, required this.ids});
}

class UserCardModel {
  final String id, bankId;
  String cardIdentifier;
  double balance;
  final List<TransactionItem> transactions;

  UserCardModel({required this.id, required this.bankId, required this.cardIdentifier, required this.balance, required this.transactions});
  
  BankEntity get bank {
    if (bankId == 'cash') {
      return const BankEntity(
        id: 'cash', name: 'النقود السائلة (كاش)', type: 'محفظة المصروفات اليدوية', acronym: 'CASH',
        entityType: EntityType.wallet, network: PaymentNetwork.walletInternal, exactSenders: [],
        gradientColors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        textColor: Colors.white, cardTypeBadge: 'CASH WALLET', logoPath: 'cash.png',
      );
    }
    return EgyptInstitutions.all.firstWhere((b) => b.id == bankId, orElse: () => EgyptInstitutions.all.first);
  }

  Map<String, dynamic> toJson() => {'id': id, 'bankId': bankId, 'cardIdentifier': cardIdentifier, 'balance': balance, 'transactions': transactions.map((t) => t.toJson()).toList()};
  factory UserCardModel.fromJson(Map<String, dynamic> j) => UserCardModel(
    id: j['id'], bankId: j['bankId'], cardIdentifier: j['cardIdentifier'] ?? '•••• 0000', balance: (j['balance'] as num).toDouble(),
    transactions: (j['transactions'] as List).map((t) => TransactionItem.fromJson(t)).toList(),
  );
}

class TransactionItem {
  final String name;
  final String? subtitle;
  final String date;
  final double amount;
  final bool isIncome;
  final String category;
  final String? txFingerprint;

  TransactionItem({required this.name, this.subtitle, required this.date, required this.amount, required this.isIncome, this.category = 'عام', this.txFingerprint});
  Map<String, dynamic> toJson() => {'name': name, 'subtitle': subtitle, 'date': date, 'amount': amount, 'isIncome': isIncome, 'category': category, 'txFingerprint': txFingerprint};
  factory TransactionItem.fromJson(Map<String, dynamic> j) => TransactionItem(
    name: j['name'], subtitle: j['subtitle'], date: j['date'], amount: (j['amount'] as num).toDouble(), isIncome: j['isIncome'], category: j['category'] ?? 'عام', txFingerprint: j['txFingerprint'],
  );
}

class QersheenApp extends StatelessWidget {
  final SharedPreferences prefs;
  const QersheenApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    final appData = AppData(prefs);
    return ListenableBuilder(
      listenable: appData,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'قرشين',
        themeMode: appData.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFF2F4F7), fontFamily: 'sans-serif'),
        darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.black, fontFamily: 'sans-serif'),
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: appData.isBiometricEnabled && !appData.isAuthenticated
            ? AuthLockScreen(appData: appData)
            : MainLayoutScreen(appData: appData),
      ),
    );
  }
}

class AuthLockScreen extends StatelessWidget {
  final AppData appData;
  const AuthLockScreen({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.fingerprint_rounded, size: 80, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 24),
            const Text('قرشين محمية بأمان', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('يرجى تأكيد هويتك للوصول لبياناتك المالية', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
              icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
              label: const Text('إلغاء القفل بالبصمة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => appData.authenticateUser(),
            ),
          ],
        ),
      ),
    );
  }
}

class MainLayoutScreen extends StatefulWidget {
  final AppData appData;
  const MainLayoutScreen({super.key, required this.appData});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.appData.isDarkMode;
    final pages = [
      AppleWalletScreen(appData: widget.appData),
      InstallmentsView(appData: widget.appData),
      CategoryBudgetsView(appData: widget.appData),
      SettingsTabView(appData: widget.appData)
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _barItem(0, Icons.wallet_rounded, 'المحفظة'),
            _barItem(1, Icons.credit_score_rounded, 'الأقساط'),
            _barItem(2, Icons.pie_chart_rounded, 'الميزانيات'),
            _barItem(3, Icons.tune_rounded, 'الإعدادات والـ PDF'),
          ],
        ),
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF10B981),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('مصروف كاش', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => _showManualCashSheet(context),
            )
          : null,
    );
  }

  Widget _barItem(int idx, IconData icon, String label) {
    final sel = _tab == idx;
    final c = sel ? const Color(0xFF10B981) : Colors.grey;
    return InkWell(
      onTap: () => setState(() => _tab = idx),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c, size: 22),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showManualCashSheet(BuildContext ctx) {
    final titleCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    bool isExpense = true;
    String category = 'سوبرماركت ومأكولات';

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bCtx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(bCtx).viewInsets.bottom, top: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تسجيل معاملة كاش يدوية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Row(
                children: [
                  ChoiceChip(label: const Text('مصروف (-)'), selected: isExpense, onSelected: (_) => setSheetState(() => isExpense = true), selectedColor: Colors.redAccent.withOpacity(0.3)),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('دخل (+)'), selected: !isExpense, onSelected: (_) => setSheetState(() => isExpense = false), selectedColor: Colors.green.withOpacity(0.3)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'اسم البند / المتجر', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ بالجنيه', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.all(14)),
                  onPressed: () {
                    final a = double.tryParse(amtCtrl.text);
                    if (a != null && a > 0 && titleCtrl.text.isNotEmpty) {
                      widget.appData.addManualCashTx(title: titleCtrl.text, amount: a, isIncome: !isExpense, category: category);
                      Navigator.pop(bCtx);
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تمت إضافة المعاملة بنجاح إلى محفظة الكاش')));
                    }
                  },
                  child: const Text('حفظ المعاملة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= شاشة المحفظة الرئيسية =================
class AppleWalletScreen extends StatefulWidget {
  final AppData appData;
  const AppleWalletScreen({super.key, required this.appData});

  @override
  State<AppleWalletScreen> createState() => _AppleWalletScreenState();
}

class _AppleWalletScreenState extends State<AppleWalletScreen> {
  int? _expandedIndex;
  String searchQuery = '';

  void _showEditSheet(UserCardModel card, int txIndex, TransactionItem tx) {
    final titleCtrl = TextEditingController(text: tx.name);
    final amtCtrl = TextEditingController(text: tx.amount.toStringAsFixed(0));
    String selectedCategory = tx.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تعديل تفاصيل المعاملة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'اسم المعاملة / المتجر', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.all(14)),
                onPressed: () {
                  final newAmt = double.tryParse(amtCtrl.text);
                  if (newAmt != null && newAmt > 0 && titleCtrl.text.isNotEmpty) {
                    widget.appData.editTransaction(card.id, txIndex, newName: titleCtrl.text, newAmount: newAmt, newCategory: selectedCategory);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات بنجاح')));
                  }
                },
                child: const Text('حفظ التعديل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.appData.userCards;
    final isDark = widget.appData.isDarkMode;
    final todaySpent = widget.appData.getTodayExpenses();
    final isBudgetExceeded = todaySpent > widget.appData.dailyBudgetLimit;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المحفظة', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    Text('إجمالي الأرصدة: ${widget.appData.getTotalBalance().toStringAsFixed(0)} ج.م', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.sync_rounded, color: Colors.blueAccent, size: 28),
                  tooltip: 'مزامنة دقيقة',
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مزامنة تسلسلية وتحديث للأرصدة...')));
                    await widget.appData.autoDetectChronological();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت مزامنة الرسائل بدقة')));
                    }
                  },
                ),
              ],
            ),
          ),
          if (isBudgetExceeded)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تنبيه: تجاوزت سقف الميزانية اليومي! (${todaySpent.toStringAsFixed(0)} / ${widget.appData.dailyBudgetLimit.toStringAsFixed(0)} ج.م)',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن اسم شخص، متجر، أو مبلغ...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              ),
              onChanged: (val) => setState(() => searchQuery = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildAppleStack(cards)),
                  if (_expandedIndex != null && _expandedIndex! < cards.length) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: () => setState(() => _expandedIndex = null),
                      icon: const Icon(Icons.close_fullscreen_rounded, size: 16),
                      label: const Text('طي البطاقة'),
                    ),
                    const SizedBox(height: 16),
                    _buildFilteredTransactions(cards[_expandedIndex!], isDark),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleStack(List<UserCardModel> cards) {
    const double cardH = 220.0;
    const double peekH = 68.0;
    final double totalH = _expandedIndex == null ? (cardH + (cards.length - 1) * peekH) : (cardH + 20);

    return SizedBox(
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(cards.length, (i) {
          final card = cards[i];
          final isSelected = _expandedIndex == i;
          final top = _expandedIndex == null ? (i * peekH) : (isSelected ? 0.0 : (cardH + 30));
          final opacity = _expandedIndex == null ? 1.0 : (isSelected ? 1.0 : 0.0);

          return AnimatedPositioned(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            top: top, left: 0, right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: opacity,
              child: GestureDetector(
                onTap: () => setState(() => _expandedIndex = _expandedIndex == i ? null : i),
                child: _buildRealAppleCard(card),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRealAppleCard(UserCardModel card) {
    final bank = card.bank;
    final isWallet = bank.entityType == EntityType.wallet;

    return Container(
      height: 220,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: bank.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))],
        border: Border.all(color: Colors.white.withOpacity(0.16), width: 1.2),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40, right: -40,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Colors.white.withOpacity(0.12), Colors.transparent]),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(bank.cardTypeBadge, style: TextStyle(color: bank.textColor.withOpacity(0.75), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  bank.buildBrandLogo(height: 32),
                ],
              ),
              Row(
                children: [
                  if (!isWallet) ...[
                    Container(
                      width: 44, height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFAA8010), Color(0xFFF9E8A2)]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Container(width: 30, height: 20, decoration: BoxDecoration(border: Border.all(color: Colors.black45, width: 0.8), borderRadius: BorderRadius.circular(3))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Transform.rotate(angle: 1.5708, child: Icon(Icons.wifi, size: 22, color: bank.textColor.withOpacity(0.7))),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Colors.white70), const SizedBox(width: 4), Text(card.bankId == 'cash' ? 'كاش يدوي' : 'محفظة', style: const TextStyle(color: Colors.white70, fontSize: 11))]),
                    ),
                  ],
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('الرصيد الفعلي', style: TextStyle(color: bank.textColor.withOpacity(0.7), fontSize: 10)),
                      Text('${card.balance.toStringAsFixed(2)} ج.م', style: TextStyle(color: bank.textColor, fontSize: 24, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(card.cardIdentifier, style: TextStyle(color: bank.textColor, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const Text('ACTIVE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredTransactions(UserCardModel card, bool isDark) {
    final filtered = <MapEntry<int, TransactionItem>>[];
    for (int i = 0; i < card.transactions.length; i++) {
      final tx = card.transactions[i];
      if (searchQuery.isEmpty ||
          tx.name.toLowerCase().contains(searchQuery) ||
          (tx.subtitle != null && tx.subtitle!.toLowerCase().contains(searchQuery)) ||
          tx.amount.toString().contains(searchQuery)) {
        filtered.add(MapEntry(i, tx));
      }
    }

    if (filtered.isEmpty) {
      return const Padding(padding: EdgeInsets.all(20), child: Text('لا توجد معاملات مطابقة للبحث', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: filtered.length,
      itemBuilder: (ctx, idx) {
        final originalIndex = filtered[idx].key;
        final tx = filtered[idx].value;
        return InkWell(
          onLongPress: () => _showEditSheet(card, originalIndex, tx),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(tx.isIncome ? Icons.south_west_rounded : Icons.north_east_rounded, color: tx.isIncome ? Colors.green : Colors.redAccent, size: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (tx.subtitle != null) Text(tx.subtitle!, style: const TextStyle(color: Colors.blueAccent, fontSize: 11)),
                        Text('${tx.category} • ${tx.date}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                Text('${tx.isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)} ج.م', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: tx.isIncome ? Colors.green : Colors.redAccent)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ================= شاشة الأقساط والـ BNPL =================
class InstallmentsView extends StatelessWidget {
  final AppData appData;
  const InstallmentsView({super.key, required this.appData});

  void _showAddInstallmentDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final provCtrl = TextEditingController();
    final monthlyCtrl = TextEditingController();
    final monthsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة قسط جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'السلعة / الغرض (مثل: موبايل iPhone)')),
            TextField(controller: provCtrl, decoration: const InputDecoration(labelText: 'جهة التقسيط (مثل: فاليو، أمان، بنك مصر)')),
            TextField(controller: monthlyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'القسط الشهري (ج.م)')),
            TextField(controller: monthsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'إجمالي عدد الشهور')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () {
              final mAmt = double.tryParse(monthlyCtrl.text);
              final mCount = int.tryParse(monthsCtrl.text);
              if (mAmt != null && mCount != null && titleCtrl.text.isNotEmpty) {
                appData.addInstallment(titleCtrl.text, provCtrl.text.isEmpty ? 'جهة تقسيط' : provCtrl.text, mAmt, mCount, 1);
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appData.isDarkMode;
    final list = appData.installments;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('إدارة الأقساط والـ BNPL', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF10B981), size: 30), onPressed: () => _showAddInstallmentDialog(context)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('متابعة دقيقة لأقساط فاليو، أمان، والبطاقات الائتمانية البنكية', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('لا توجد أقساط مسجلة حالياً، اضغط + لإضافة قسط جديد', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (ctx, i) {
                        final inst = list[i];
                        final isFinished = inst.paidMonths >= inst.totalMonths;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(inst.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text('${inst.provider} • القسط: ${inst.monthlyAmount.toStringAsFixed(0)} ج.م شهرياً', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    ],
                                  ),
                                  if (!isFinished)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                                      onPressed: () => appData.markInstallmentPaid(inst.id),
                                      child: const Text('سداد قسط', style: TextStyle(color: Colors.white, fontSize: 11)),
                                    )
                                  else
                                    const Text('مكتمل السداد', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(value: inst.progress, minHeight: 6, backgroundColor: Colors.grey.withOpacity(0.2), valueColor: AlwaysStoppedAnimation(isFinished ? Colors.green : const Color(0xFF10B981))),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('تم سداد: ${inst.paidMonths} من ${inst.totalMonths} شهر', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  Text('المتبقي: ${inst.remainingAmount.toStringAsFixed(0)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
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

// ================= شاشة ميزانيات التصنيفات =================
class CategoryBudgetsView extends StatelessWidget {
  final AppData appData;
  const CategoryBudgetsView({super.key, required this.appData});

  void _showSetLimitDialog(BuildContext context, String cat, double current) {
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل ميزانية: $cat'),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الحد الشهري الأقصى (ج.م)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null && val > 0) {
                appData.setCategoryBudget(cat, val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appData.isDarkMode;
    final budgets = appData.categoryBudgets;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أسقف ميزانية التصنيفات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('تحكم شهري محدد لكل بند ومتابعة نسبة الاستهلاك', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: budgets.entries.map((entry) {
                  final cat = entry.key;
                  final limit = entry.value;
                  final spent = appData.getCategoryMonthlySpent(cat);
                  final pct = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
                  final isExceeded = spent > limit;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: isExceeded ? Border.all(color: Colors.redAccent.withOpacity(0.5)) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            IconButton(icon: const Icon(Icons.edit, size: 16, color: Colors.grey), onPressed: () => _showSetLimitDialog(context, cat, limit)),
                          ],
                        ),
                        Text('${spent.toStringAsFixed(0)} من أصل ${limit.toStringAsFixed(0)} ج.م (${(pct * 100).toStringAsFixed(0)}%)', style: TextStyle(color: isExceeded ? Colors.redAccent : Colors.grey, fontSize: 12, fontWeight: isExceeded ? FontWeight.bold : FontWeight.normal)),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: pct,
                          minHeight: 7,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation(pct >= 1.0 ? Colors.redAccent : (pct >= 0.8 ? Colors.amber : const Color(0xFF10B981))),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= شاشة الإعدادات والتقارير والـ PDF =================
class SettingsTabView extends StatelessWidget {
  final AppData appData;
  const SettingsTabView({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('الإعدادات والتقارير الرسمية', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 28),
            title: const Text('تصدير كشف حساب PDF رسمي'),
            subtitle: const Text('ملف ملون ومنسق بجميع الحركات والإجماليات جاهز للطباعة'),
            onTap: () async {
              await appData.exportPdfReport();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.fingerprint_rounded, color: Color(0xFF10B981)),
            title: const Text('قفل التطبيق بالبصمة (Biometrics)'),
            subtitle: const Text('طلب البصمة أو الرمز عند فتح المحفظة'),
            trailing: Switch(
              value: appData.isBiometricEnabled,
              activeColor: const Color(0xFF10B981),
              onChanged: (val) => appData.toggleBiometric(val),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.battery_saver_rounded, color: Colors.green),
            title: const Text('استثناء من قيود البطارية (خلفية)'),
            onTap: () => appData.requestBatteryOptimizationIgnore(),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('المظهر الداكن'),
            trailing: Switch(value: appData.isDarkMode, onChanged: (_) => appData.toggleTheme(), activeColor: const Color(0xFF10B981)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
            title: const Text('تصفير كل البطاقات والبيانات'),
            onTap: () {
              appData.clearAll();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصفير البيانات بنجاح')));
            },
          ),
        ],
      ),
    );
  }
}
