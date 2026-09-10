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

// ================= نظام الترجمة والثنائية (Localization) =================
class AppStrings {
  static Map<String, Map<String, String>> translations = {
    'ar': {
      'app_title': 'قرشين',
      'wallet': 'المحفظة',
      'installments': 'الأقساط',
      'budgets': 'الميزانيات',
      'settings': 'الإعدادات',
      'total_balance': 'إجمالي الأرصدة',
      'sync': 'مزامنة دقيقة',
      'search_hint': 'ابحث عن اسم شخص، متجر، أو مبلغ...',
      'fold_card': 'طي البطاقة',
      'no_transactions': 'لا توجد معاملات مسجلة على هذا الحساب بعد',
      'add_cash': 'مصروف كاش',
      'manual_cash_title': 'تسجيل معاملة كاش يدوية',
      'expense': 'مصروف (-)',
      'income': 'دخل (+)',
      'item_name': 'اسم البند / المتجر',
      'amount_egp': 'المبلغ بالجنيه',
      'save': 'حفظ',
      'biometric_lock': 'قفل التطبيق بالبصمة (Biometrics)',
      'biometric_sub': 'طلب البصمة أو الرمز عند فتح المحفظة',
      'export_pdf': 'تصدير كشف حساب PDF رسمي',
      'export_pdf_sub': 'ملف ملون ومنسق بجميع الحركات والإجماليات',
      'battery_opt': 'استثناء من قيود البطارية (خلفية)',
      'dark_mode': 'المظهر الداكن',
      'clear_all': 'تصفير كل البطاقات والبيانات',
      'language': 'لغة التطبيق / Language',
      'lang_name': 'English / العربية',
    },
    'en': {
      'app_title': 'Qersheen',
      'wallet': 'Wallet',
      'installments': 'Installments',
      'budgets': 'Budgets',
      'settings': 'Settings',
      'total_balance': 'Total Balance',
      'sync': 'Sync SMS',
      'search_hint': 'Search person, store, or amount...',
      'fold_card': 'Fold Card',
      'no_transactions': 'No transactions recorded yet',
      'add_cash': 'Cash Expense',
      'manual_cash_title': 'Add Manual Cash Transaction',
      'expense': 'Expense (-)',
      'income': 'Income (+)',
      'item_name': 'Store / Item Name',
      'amount_egp': 'Amount in EGP',
      'save': 'Save',
      'biometric_lock': 'Biometric Lock',
      'biometric_sub': 'Require fingerprint when opening wallet',
      'export_pdf': 'Export Official PDF Statement',
      'export_pdf_sub': 'Formatted summary ready for print/share',
      'battery_opt': 'Battery Optimization Exemption',
      'dark_mode': 'Dark Mode',
      'clear_all': 'Clear All Data & Cards',
      'language': 'App Language / اللغة',
      'lang_name': 'English / العربية',
    }
  };

  static String get(String lang, String key) {
    return translations[lang]?[key] ?? translations['ar']?[key] ?? key;
  }
}

class InstallmentModel {
  final String id;
  String title;
  String provider;
  double monthlyAmount;
  int totalMonths;
  int paidMonths;
  int dueDayOfMonth;

  InstallmentModel({
    required this.id, required this.title, required this.provider,
    required this.monthlyAmount, required this.totalMonths,
    required this.paidMonths, required this.dueDayOfMonth,
  });

  double get remainingAmount => monthlyAmount * (totalMonths - paidMonths);
  double get progress => totalMonths > 0 ? (paidMonths / totalMonths).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'provider': provider,
    'monthlyAmount': monthlyAmount, 'totalMonths': totalMonths,
    'paidMonths': paidMonths, 'dueDayOfMonth': dueDayOfMonth,
  };

  factory InstallmentModel.fromJson(Map<String, dynamic> j) => InstallmentModel(
    id: j['id'], title: j['title'], provider: j['provider'] ?? 'General',
    monthlyAmount: (j['monthlyAmount'] as num).toDouble(),
    totalMonths: j['totalMonths'] ?? 1, paidMonths: j['paidMonths'] ?? 0, dueDayOfMonth: j['dueDayOfMonth'] ?? 1,
  );
}

class AppData extends ChangeNotifier {
  final SharedPreferences prefs;
  bool isDarkMode;
  bool isBiometricEnabled;
  bool isAuthenticated = false;
  String language; // 'ar' أو 'en'
  double dailyBudgetLimit;
  List<UserCardModel> userCards = [];
  List<InstallmentModel> installments = [];
  Map<String, double> categoryBudgets = {};
  Set<String> processedMessageFingerprints = {};
  final LocalAuthentication _auth = LocalAuthentication();

  AppData(this.prefs)
      : isDarkMode = prefs.getBool('isDark') ?? true,
        isBiometricEnabled = prefs.getBool('isBioEnabled') ?? false,
        language = prefs.getString('app_lang') ?? 'ar',
        dailyBudgetLimit = prefs.getDouble('dailyLimit') ?? 600.0 {
    _loadAll();
    _startNotificationListener();
    _checkInitialAuth();
  }

  void _checkInitialAuth() {
    if (!isBiometricEnabled) isAuthenticated = true;
  }

  void toggleLanguage() {
    language = language == 'ar' ? 'en' : 'ar';
    prefs.setString('app_lang', language);
    notifyListeners();
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
        localizedReason: language == 'ar' ? 'يرجى تأكيد هويتك لفتح محفظة قرشين بأمان' : 'Please authenticate to open Qersheen',
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
    final String? cardsJson = prefs.getString('cardsData_v22');
    if (cardsJson != null && cardsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(cardsJson);
      userCards = decoded.map((e) => UserCardModel.fromJson(e)).toList();
    } else {
      userCards = [
        UserCardModel(
          id: 'cash_wallet_main', bankId: 'cash',
          cardIdentifier: language == 'ar' ? 'محفظة النقود اليدوية' : 'Manual Cash Wallet', balance: 0.0, transactions: [],
        )
      ];
      saveCards();
    }

    final String? instJson = prefs.getString('installments_v22');
    if (instJson != null && instJson.isNotEmpty) {
      final List<dynamic> decInst = jsonDecode(instJson);
      installments = decInst.map((e) => InstallmentModel.fromJson(e)).toList();
    }

    final String? budJson = prefs.getString('catBudgets_v22');
    if (budJson != null && budJson.isNotEmpty) {
      final Map<String, dynamic> decBud = jsonDecode(budJson);
      categoryBudgets = decBud.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } else {
      categoryBudgets = {
        'Bills & Shopping': 3000.0,
        'Supermarket & Food': 4000.0,
        'Transfers': 2000.0,
        'ATM Cash': 5000.0,
        'General': 1500.0,
      };
      saveCategoryBudgets();
    }

    final List<String>? fps = prefs.getStringList('processed_fps_v22');
    if (fps != null) processedMessageFingerprints = fps.toSet();
  }

  void saveCards() {
    prefs.setString('cardsData_v22', jsonEncode(userCards.map((c) => c.toJson()).toList()));
    prefs.setStringList('processed_fps_v22', processedMessageFingerprints.toList());
    notifyListeners();
  }

  void saveInstallments() {
    prefs.setString('installments_v22', jsonEncode(installments.map((i) => i.toJson()).toList()));
    notifyListeners();
  }

  void saveCategoryBudgets() {
    prefs.setString('catBudgets_v22', jsonEncode(categoryBudgets));
    notifyListeners();
  }

  void addInstallment(String title, String provider, double monthly, int months, int dueDay) {
    installments.add(InstallmentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title, provider: provider, monthlyAmount: monthly,
      totalMonths: months, paidMonths: 0, dueDayOfMonth: dueDay,
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
        if (!tx.isIncome && (tx.category == category || tx.date.contains(monthStr))) {
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
      final c = UserCardModel(id: 'cash_wallet_main', bankId: 'cash', cardIdentifier: language == 'ar' ? 'محفظة النقود اليدوية' : 'Manual Cash Wallet', balance: 0.0, transactions: []);
      userCards.add(c);
      return c;
    });

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} • ${now.day}/${now.month}/${now.year}';

    if (isIncome) cashCard.balance += amount; else cashCard.balance -= amount;

    cashCard.transactions.insert(0, TransactionItem(
      name: title, subtitle: language == 'ar' ? 'نقدي (كاش)' : 'Cash', date: timeStr, amount: amount, isIncome: isIncome, category: category, txFingerprint: 'cash_${now.millisecondsSinceEpoch}',
    ));
    saveCards();
  }

  void editTransaction(String cardId, int txIndex, {required String newName, required double newAmount, required String newCategory}) {
    final card = userCards.firstWhere((c) => c.id == cardId);
    final oldTx = card.transactions[txIndex];
    final diff = newAmount - oldTx.amount;
    if (diff != 0) {
      if (oldTx.isIncome) card.balance += diff; else card.balance -= diff;
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
        textDirection: language == 'ar' ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(language == 'ar' ? 'تقرير المعاملات المالية - قرشين' : 'Financial Statement - Qersheen', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
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
                pw.Column(children: [pw.Text(language == 'ar' ? 'إجمالي الدخل' : 'Total Income', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)), pw.Text('+${totalIn.toStringAsFixed(0)} EGP', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800))]),
                pw.Column(children: [pw.Text(language == 'ar' ? 'إجمالي المصروفات' : 'Total Expenses', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)), pw.Text('-${totalOut.toStringAsFixed(0)} EGP', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red800))]),
                pw.Column(children: [pw.Text(language == 'ar' ? 'صافي الرصيد' : 'Net Balance', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)), pw.Text('${(totalIn - totalOut).toStringAsFixed(0)} EGP', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800))]),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(language == 'ar' ? 'سجل المعاملات:' : 'Transactions Log:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: language == 'ar' ? ['الحساب', 'المعاملة', 'التصنيف', 'المبلغ', 'التاريخ'] : ['Account', 'Transaction', 'Category', 'Amount', 'Date'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
            cellAlignment: pw.Alignment.centerRight,
            data: userCards.expand((c) => c.transactions.take(30).map((t) => [
              c.bank.name, t.name, t.category, '${t.isIncome ? '+' : '-'}${t.amount.toStringAsFixed(0)}', t.date,
            ])).toList(),
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'qersheen_statement.pdf');
  }

  void clearAll() {
    userCards.clear();
    processedMessageFingerprints.clear();
    installments.clear();
    userCards.add(UserCardModel(id: 'cash_wallet_main', bankId: 'cash', cardIdentifier: language == 'ar' ? 'محفظة النقود اليدوية' : 'Manual Cash Wallet', balance: 0.0, transactions: []));
    saveCards();
    saveInstallments();
  }

  void _startNotificationListener() {
    try {
      NotificationListenerService.notificationsStream.listen((event) {
        final title = event.title ?? '';
        final content = event.content ?? '';
        final bank = EgyptInstitutions.matchSender(title);
        if (bank != null) _processMessage(bank, '$title $content', DateTime.now(), null);
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

      for (var msg in rawMessages) {
        final bank = EgyptInstitutions.matchSender(msg.address ?? '');
        if (bank != null) {
          _processMessage(bank, msg.body ?? '', msg.date ?? DateTime.now(), msg.id.toString());
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

    final balMatch = RegExp(r'(?:رصيد|balance is)\s*[:=]?\s*(\d+(?:\.\d{1,2})?)', caseSensitive: false).firstMatch(text);
    bool hasExplicitBalance = false;
    if (balMatch != null) {
      final bVal = double.tryParse(balMatch.group(1)!);
      if (bVal != null) {
        card.balance = bVal;
        hasExplicitBalance = true;
        saveCards();
      }
    }

    if (processedMessageFingerprints.contains(fingerprint)) return;

    bool isIncome = text.contains('استلام') || text.contains('إيداع') || text.contains('received') || text.contains('credited');
    String title = isIncome ? 'تحويل وارد' : 'معاملة شراء / خصم';
    String category = isIncome ? 'Transfers' : 'Bills & Shopping';

    final amtMatch = RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:جنية|جنيه|ج\.م|L\.E|LE|EGP)').firstMatch(text) ??
        RegExp(r'(?:مبلغ|قيمة|مبلغ وقدره)\s*[:=]?\s*(\d+(?:\.\d{1,2})?)').firstMatch(text);

    if (amtMatch != null) {
      final amt = double.tryParse(amtMatch.group(1)!);
      if (amt != null && amt > 0) {
        final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')} • ${timestamp.day}/${timestamp.month}/${timestamp.year}';
        if (!hasExplicitBalance) {
          if (isIncome) card.balance += amt; else card.balance -= amt;
        }

        card.transactions.insert(0, TransactionItem(
          name: title, date: timeStr, amount: amt, isIncome: isIncome, category: category, txFingerprint: fingerprint,
        ));
        processedMessageFingerprints.add(fingerprint);
        saveCards();
      }
    }
  }
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

  TransactionItem({required this.name, this.subtitle, required this.date, required this.amount, required this.isIncome, this.category = 'General', this.txFingerprint});
  Map<String, dynamic> toJson() => {'name': name, 'subtitle': subtitle, 'date': date, 'amount': amount, 'isIncome': isIncome, 'category': category, 'txFingerprint': txFingerprint};
  factory TransactionItem.fromJson(Map<String, dynamic> j) => TransactionItem(
    name: j['name'], subtitle: j['subtitle'], date: j['date'], amount: (j['amount'] as num).toDouble(), isIncome: j['isIncome'], category: j['category'] ?? 'General', txFingerprint: j['txFingerprint'],
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
        title: 'Qersheen / قرشين',
        themeMode: appData.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFF2F4F7), fontFamily: 'sans-serif'),
        darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.black, fontFamily: 'sans-serif'),
        builder: (context, child) => Directionality(
          textDirection: appData.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
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
            Text(appData.language == 'ar' ? 'قرشين محمية بأمان' : 'Qersheen is Secured', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(appData.language == 'ar' ? 'يرجى تأكيد هويتك للوصول لبياناتك المالية' : 'Please authenticate to access your financial data', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
              icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
              label: Text(appData.language == 'ar' ? 'إلغاء القفل بالبصمة' : 'Authenticate', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    final lang = widget.appData.language;

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
            _barItem(0, Icons.wallet_rounded, AppStrings.get(lang, 'wallet')),
            _barItem(1, Icons.credit_score_rounded, AppStrings.get(lang, 'installments')),
            _barItem(2, Icons.pie_chart_rounded, AppStrings.get(lang, 'budgets')),
            _barItem(3, Icons.tune_rounded, AppStrings.get(lang, 'settings')),
          ],
        ),
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF10B981),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(AppStrings.get(lang, 'add_cash'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    String category = 'Supermarket & Food';
    final lang = widget.appData.language;

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
              Text(AppStrings.get(lang, 'manual_cash_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Row(
                children: [
                  ChoiceChip(label: Text(AppStrings.get(lang, 'expense')), selected: isExpense, onSelected: (_) => setSheetState(() => isExpense = true), selectedColor: Colors.redAccent.withOpacity(0.3)),
                  const SizedBox(width: 8),
                  ChoiceChip(label: Text(AppStrings.get(lang, 'income')), selected: !isExpense, onSelected: (_) => setSheetState(() => isExpense = false), selectedColor: Colors.green.withOpacity(0.3)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: titleCtrl, decoration: InputDecoration(labelText: AppStrings.get(lang, 'item_name'), border: const OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: AppStrings.get(lang, 'amount_egp'), border: const OutlineInputBorder())),
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
                    }
                  },
                  child: Text(AppStrings.get(lang, 'save'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

class AppleWalletScreen extends StatefulWidget {
  final AppData appData;
  const AppleWalletScreen({super.key, required this.appData});

  @override
  State<AppleWalletScreen> createState() => _AppleWalletScreenState();
}

class _AppleWalletScreenState extends State<AppleWalletScreen> {
  int? _expandedIndex;
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final cards = widget.appData.userCards;
    final isDark = widget.appData.isDarkMode;
    final lang = widget.appData.language;

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
                    Text(AppStrings.get(lang, 'wallet'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                    Text('${AppStrings.get(lang, 'total_balance')}: ${widget.appData.getTotalBalance().toStringAsFixed(0)} EGP', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.sync_rounded, color: Colors.blueAccent, size: 28),
                  onPressed: () async => await widget.appData.autoDetectChronological(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: AppStrings.get(lang, 'search_hint'),
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
                      label: Text(AppStrings.get(lang, 'fold_card')),
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
          return AnimatedPositioned(
            duration: const Duration(milliseconds: 340),
            top: top, left: 0, right: 0,
            child: GestureDetector(
              onTap: () => setState(() => _expandedIndex = _expandedIndex == i ? null : i),
              child: _buildRealAppleCard(card),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRealAppleCard(UserCardModel card) {
    final bank = card.bank;
    return Container(
      height: 220,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: bank.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(bank.cardTypeBadge, style: TextStyle(color: bank.textColor.withOpacity(0.75), fontSize: 11, fontWeight: FontWeight.w700)),
              bank.buildBrandLogo(height: 32),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(card.cardIdentifier, style: TextStyle(color: bank.textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Balance', style: TextStyle(color: bank.textColor.withOpacity(0.7), fontSize: 10)),
                  Text('${card.balance.toStringAsFixed(2)} EGP', style: TextStyle(color: bank.textColor, fontSize: 22, fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredTransactions(UserCardModel card, bool isDark) {
    final filtered = card.transactions.where((tx) => searchQuery.isEmpty || tx.name.toLowerCase().contains(searchQuery)).toList();
    if (filtered.isEmpty) {
      return Padding(padding: const EdgeInsets.all(20), child: Text(AppStrings.get(widget.appData.language, 'no_transactions'), style: const TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: filtered.length,
      itemBuilder: (ctx, idx) {
        final tx = filtered[idx];
        return Container(
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
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tx.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${tx.category} • ${tx.date}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ]),
                ],
              ),
              Text('${tx.isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)} EGP', style: TextStyle(fontWeight: FontWeight.w900, color: tx.isIncome ? Colors.green : Colors.redAccent)),
            ],
          ),
        );
      },
    );
  }
}

class InstallmentsView extends StatelessWidget {
  final AppData appData;
  const InstallmentsView({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(child: Center(child: Text('Installments / الأقساط')));
  }
}

class CategoryBudgetsView extends StatelessWidget {
  final AppData appData;
  const CategoryBudgetsView({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(child: Center(child: Text('Budgets / الميزانيات')));
  }
}

class SettingsTabView extends StatelessWidget {
  final AppData appData;
  const SettingsTabView({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    final lang = appData.language;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(AppStrings.get(lang, 'settings'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.language_rounded, color: Colors.blueAccent, size: 28),
            title: Text(AppStrings.get(lang, 'language')),
            subtitle: Text(AppStrings.get(lang, 'lang_name')),
            trailing: Switch(
              value: lang == 'en',
              activeColor: const Color(0xFF10B981),
              onChanged: (_) => appData.toggleLanguage(),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 28),
            title: Text(AppStrings.get(lang, 'export_pdf')),
            subtitle: Text(AppStrings.get(lang, 'export_pdf_sub')),
            onTap: () async => await appData.exportPdfReport(),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint_rounded, color: Color(0xFF10B981)),
            title: Text(AppStrings.get(lang, 'biometric_lock')),
            trailing: Switch(value: appData.isBiometricEnabled, onChanged: (v) => appData.toggleBiometric(v), activeColor: const Color(0xFF10B981)),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: Text(AppStrings.get(lang, 'dark_mode')),
            trailing: Switch(value: appData.isDarkMode, onChanged: (_) => appData.toggleTheme(), activeColor: const Color(0xFF10B981)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
            title: Text(AppStrings.get(lang, 'clear_all')),
            onTap: () => appData.clearAll(),
          ),
        ],
      ),
    );
  }
}
