import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:local_auth/local_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'institutions_data.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(QersheenApp(prefs: prefs));
}

class AppStrings {
  static Map<String, Map<String, String>> t = {
    'ar': {
      'wallet': 'المحفظة', 'obligations': 'الالتزامات', 'budgets': 'الميزانيات', 'settings': 'الإعدادات',
      'total': 'الإجمالي:', 'sync': 'مزامنة الرسائل', 'add_cash': 'إضافة كاش', 'auth_msg': 'قم بتأكيد هويتك لفتح المحفظة'
    },
    'en': {
      'wallet': 'Wallet', 'obligations': 'Obligations', 'budgets': 'Budgets', 'settings': 'Settings',
      'total': 'Total:', 'sync': 'Sync SMS', 'add_cash': 'Add Cash', 'auth_msg': 'Authenticate to open Wallet'
    }
  };
  static String get(String lang, String key) => t[lang]?[key] ?? key;
}

class InstallmentModel {
  final String id, title, provider;
  double monthlyAmount;
  int totalMonths, paidMonths, dueDayOfMonth;
  InstallmentModel({required this.id, required this.title, required this.provider, required this.monthlyAmount, required this.totalMonths, required this.paidMonths, required this.dueDayOfMonth});
  double get progress => totalMonths > 0 ? (paidMonths / totalMonths).clamp(0.0, 1.0) : 0.0;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'provider': provider, 'monthlyAmount': monthlyAmount, 'totalMonths': totalMonths, 'paidMonths': paidMonths, 'dueDayOfMonth': dueDayOfMonth};
  factory InstallmentModel.fromJson(Map<String, dynamic> j) => InstallmentModel(id: j['id'], title: j['title'], provider: j['provider'] ?? 'عام', monthlyAmount: (j['monthlyAmount'] as num).toDouble(), totalMonths: j['totalMonths'] ?? 1, paidMonths: j['paidMonths'] ?? 0, dueDayOfMonth: j['dueDayOfMonth'] ?? 1);
}

class SubscriptionModel {
  final String id, title;
  double amount;
  int dueDayOfMonth;
  SubscriptionModel({required this.id, required this.title, required this.amount, required this.dueDayOfMonth});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'amount': amount, 'dueDayOfMonth': dueDayOfMonth};
  factory SubscriptionModel.fromJson(Map<String, dynamic> j) => SubscriptionModel(id: j['id'], title: j['title'], amount: (j['amount'] as num).toDouble(), dueDayOfMonth: j['dueDayOfMonth'] ?? 1);
}

class AppData extends ChangeNotifier {
  final SharedPreferences prefs;
  bool isDarkMode, isBiometricEnabled, isAuthenticated = false;
  String language;
  List<UserCardModel> userCards = [];
  List<InstallmentModel> installments = [];
  List<SubscriptionModel> subscriptions = [];
  Map<String, double> categoryBudgets = {};
  Set<String> processedMessageFingerprints = {};
  final LocalAuthentication _auth = LocalAuthentication();

  AppData(this.prefs)
      : isDarkMode = prefs.getBool('isDark') ?? true,
        isBiometricEnabled = prefs.getBool('isBioEnabled') ?? false,
        language = prefs.getString('app_lang') ?? 'ar' {
    _loadAll();
    _checkInitialAuth();
  }

  void _checkInitialAuth() { if (!isBiometricEnabled) isAuthenticated = true; }
  void toggleLanguage() { language = language == 'ar' ? 'en' : 'ar'; prefs.setString('app_lang', language); notifyListeners(); }
  void toggleTheme() { isDarkMode = !isDarkMode; prefs.setBool('isDark', isDarkMode); notifyListeners(); }
  
  void toggleBiometric(bool val) {
    isBiometricEnabled = val;
    prefs.setBool('isBioEnabled', val);
    if (!val) isAuthenticated = true;
    notifyListeners();
  }

  Future<bool> authenticateUser() async {
    try {
      if (!isBiometricEnabled) { isAuthenticated = true; notifyListeners(); return true; }
      if (!(await _auth.canCheckBiometrics || await _auth.isDeviceSupported())) { isAuthenticated = true; notifyListeners(); return true; }
      final didAuth = await _auth.authenticate(localizedReason: AppStrings.get(language, 'auth_msg'));
      isAuthenticated = didAuth; notifyListeners(); return didAuth;
    } catch (_) { isAuthenticated = true; notifyListeners(); return true; }
  }

  Future<void> initializePermissions() async {
    if (!(await Permission.sms.isGranted)) await Permission.sms.request();
    if (await Permission.sms.isGranted) autoDetectChronological();
  }

  void _loadAll() {
    final cJson = prefs.getString('cardsData_v34') ?? prefs.getString('cardsData_v33');
    if (cJson != null && cJson.isNotEmpty) userCards = (jsonDecode(cJson) as List).map((e) => UserCardModel.fromJson(e)).toList();
    else { userCards = [UserCardModel(id: 'cash_wallet_main', bankId: 'cash', cardIdentifier: language == 'ar' ? 'محفظة النقود السائلة' : 'Cash Wallet', balance: 0.0, transactions: [])]; saveCards(); }
    
    final iJson = prefs.getString('installments_v34') ?? prefs.getString('installments_v33');
    if (iJson != null && iJson.isNotEmpty) installments = (jsonDecode(iJson) as List).map((e) => InstallmentModel.fromJson(e)).toList();

    final sJson = prefs.getString('subscriptions_v34');
    if (sJson != null && sJson.isNotEmpty) subscriptions = (jsonDecode(sJson) as List).map((e) => SubscriptionModel.fromJson(e)).toList();
    
    final bJson = prefs.getString('catBudgets_v34') ?? prefs.getString('catBudgets_v33');
    if (bJson != null && bJson.isNotEmpty) categoryBudgets = (jsonDecode(bJson) as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    else { categoryBudgets = {'فواتير ومشتريات': 3000.0, 'سوبرماركت': 4000.0, 'مواصلات': 1500.0, 'عام': 2000.0}; saveCategoryBudgets(); }
    
    final fps = prefs.getStringList('processed_fps_v34') ?? prefs.getStringList('processed_fps_v33');
    if (fps != null) processedMessageFingerprints = fps.toSet();
  }

  void saveCards() { prefs.setString('cardsData_v34', jsonEncode(userCards.map((c) => c.toJson()).toList())); prefs.setStringList('processed_fps_v34', processedMessageFingerprints.toList()); notifyListeners(); }
  void saveInstallments() { prefs.setString('installments_v34', jsonEncode(installments.map((i) => i.toJson()).toList())); notifyListeners(); }
  void saveSubscriptions() { prefs.setString('subscriptions_v34', jsonEncode(subscriptions.map((i) => i.toJson()).toList())); notifyListeners(); }
  void saveCategoryBudgets() { prefs.setString('catBudgets_v34', jsonEncode(categoryBudgets)); notifyListeners(); }

  void addInstallment(String title, String provider, double monthly, int months, int dueDay) { installments.add(InstallmentModel(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title, provider: provider, monthlyAmount: monthly, totalMonths: months, paidMonths: 0, dueDayOfMonth: dueDay)); saveInstallments(); }
  void markInstallmentPaid(String id) { final inst = installments.firstWhere((i) => i.id == id); if (inst.paidMonths < inst.totalMonths) { inst.paidMonths++; saveInstallments(); } }
  void deleteInstallment(String id) { installments.removeWhere((i) => i.id == id); saveInstallments(); }
  
  void addSubscription(String title, double amount, int dueDay) { subscriptions.add(SubscriptionModel(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title, amount: amount, dueDayOfMonth: dueDay)); saveSubscriptions(); }
  void deleteSubscription(String id) { subscriptions.removeWhere((i) => i.id == id); saveSubscriptions(); }

  void editCardName(String cardId, String newName) { userCards.firstWhere((c) => c.id == cardId).cardIdentifier = newName; saveCards(); }
  void deleteCard(String cardId) { if (cardId != 'cash_wallet_main') { userCards.removeWhere((c) => c.id == cardId); saveCards(); } }
  
  void setCategoryBudget(String category, double limit) { categoryBudgets[category] = limit; saveCategoryBudgets(); }
  void deleteCategoryBudget(String category) { categoryBudgets.remove(category); saveCategoryBudgets(); }

  void addManualCashTx({required String title, required double amount, required bool isIncome, required String category}) {
    final cashCard = userCards.firstWhere((c) => c.bankId == 'cash');
    if (isIncome) cashCard.balance += amount; else cashCard.balance -= amount;
    final timeStr = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
    cashCard.transactions.insert(0, TransactionItem(name: title, subtitle: 'إدخال يدوي', date: timeStr, amount: amount, isIncome: isIncome, category: category, txFingerprint: 'cash_${DateTime.now().millisecondsSinceEpoch}'));
    saveCards();
  }

  double getTotalBalance() { double total = 0.0; for (var c in userCards) total += c.balance; return total; }
  double getCategoryMonthlySpent(String cat) { double total = 0.0; final mStr = '/${DateTime.now().month}/${DateTime.now().year}'; for (var c in userCards) { for (var tx in c.transactions) { if (!tx.isIncome && (tx.category == cat || tx.date.contains(mStr))) total += tx.amount; } } return total; }

  Future<void> autoDetectChronological() async {
    try {
      if (!(await Permission.sms.request().isGranted)) return;
      final msgs = await SmsQuery().querySms(kinds: [SmsQueryKind.inbox]);
      msgs.sort((a, b) => (a.date ?? DateTime.now()).compareTo(b.date ?? DateTime.now()));
      for (var msg in msgs) {
        final bank = EgyptInstitutions.matchSender(msg.address ?? '');
        if (bank != null) _processMessage(bank, msg.body ?? '', msg.date ?? DateTime.now(), msg.id.toString());
      }
      notifyListeners();
    } catch (_) {}
  }

  void _processMessage(BankEntity bank, String rawText, DateTime timestamp, String? uniqueId) {
    final text = rawText.replaceAll('\n', ' ').trim();
    final fingerprint = uniqueId ?? '${bank.id}_${timestamp.millisecondsSinceEpoch}_${text.hashCode}';
    String? phone = RegExp(r'(01[0125][0-9]{8})').firstMatch(text)?.group(1);
    String? acc = RegExp(r'(?:\*+)?(\d{4})').firstMatch(text)?.group(1);
    String? subDetails = phone ?? acc;
    
    if (!userCards.any((c) => c.bankId == bank.id)) { userCards.insert(0, UserCardModel(id: '${bank.id}_${DateTime.now().millisecondsSinceEpoch}', bankId: bank.id, cardIdentifier: phone ?? (acc != null ? '•••• $acc' : '•••• 0000'), balance: 0.0, transactions: [])); }
    final card = userCards.firstWhere((c) => c.bankId == bank.id);

    final balMatch = RegExp(r'(?:رصيد|balance).*?(\d+(?:\.\d{1,2})?)', caseSensitive: false).firstMatch(text);
    bool hasExplicitBalance = false;
    if (balMatch != null) { card.balance = double.tryParse(balMatch.group(1)!) ?? card.balance; hasExplicitBalance = true; }
    if (processedMessageFingerprints.contains(fingerprint)) return;

    bool isIncome = RegExp(r'(إيداع|استلام|وارد|تحويل من|received|credited|added)').hasMatch(text);
    bool isExpense = RegExp(r'(خصم|شراء|سداد|دفع|سحب|تحويل إلى|paid|debited|purchase)').hasMatch(text);
    if (!isIncome && !isExpense) return;

    String extractedName = 'معاملة مالية';
    final nameMatch = RegExp(r'(?:لـ|إلى|من|لدى|في|حساب|رقم|to|from)\s+([A-Za-z\u0621-\u064A0-9\s\.\-]{3,25})', caseSensitive: false).firstMatch(text);
    if (nameMatch != null) {
      String rawName = nameMatch.group(1)!;
      rawName = rawName.replaceAll(RegExp(r'(محفظة|كاش|فودافون|رصيد|مبلغ|جنية|جنيه|EGP|LE|رقم|حساب|هو|عمليه|شراء|واكسب)'), '');
      extractedName = rawName.trim();
      if (extractedName.length < 2) extractedName = 'معاملة مالية';
    }

    String title = isIncome ? 'استلام من $extractedName' : 'دفع لـ $extractedName';
    
    // التصنيف التلقائي الذكي للمتاجر
    String category = isIncome ? 'تحويلات' : 'فواتير ومشتريات';
    final lowerName = extractedName.toLowerCase();
    if (!isIncome) {
      if (RegExp(r'(uber|careem|indrive|ديدي|اوبر|كريم|مواصلات|قطار)').hasMatch(lowerName)) {
        category = 'مواصلات';
        if (!categoryBudgets.containsKey('مواصلات')) setCategoryBudget('مواصلات', 1500.0);
      } else if (RegExp(r'(carrefour|kazyon|spinneys|hyper|بيم|كارفور|كازيون|سوبرماركت|خير زمان)').hasMatch(lowerName)) {
        category = 'سوبرماركت';
        if (!categoryBudgets.containsKey('سوبرماركت')) setCategoryBudget('سوبرماركت', 4000.0);
      } else if (RegExp(r'(vodafone|orange|etisalat|we|فودافون|اورانج|اتصالات|فاتورة|انترنت)').hasMatch(lowerName)) {
        category = 'فواتير ومشتريات';
      }
    }

    final amtMatch = RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:جنية|جنيه|EGP|LE)').firstMatch(text) ?? RegExp(r'(?:مبلغ|قيمة)\s*(\d+(?:\.\d{1,2})?)').firstMatch(text);
    
    if (amtMatch != null) {
      final amt = double.tryParse(amtMatch.group(1)!);
      if (amt != null && amt > 0) {
        if (!hasExplicitBalance) { if (isIncome) card.balance += amt; else card.balance -= amt; }
        card.transactions.insert(0, TransactionItem(name: title, subtitle: subDetails, date: '${timestamp.day}/${timestamp.month}/${timestamp.year}', amount: amt, isIncome: isIncome, category: category, txFingerprint: fingerprint));
        processedMessageFingerprints.add(fingerprint);
        saveCards();
      }
    }
  }

  Future<void> exportCsvReport() async {
    final StringBuffer buffer = StringBuffer(); buffer.writeln('\uFEFFاسم الحساب,اسم المعاملة,التصنيف,المبلغ,النوع,التاريخ');
    for (var c in userCards) { for (var tx in c.transactions) { buffer.writeln('"${c.bank.name}","${tx.name}","${tx.category}",${tx.amount},"${tx.isIncome ? 'دخل' : 'مصروف'}","${tx.date}"'); } }
    final file = File('${Directory.systemTemp.path}/qersheen_report.csv'); await file.writeAsString(buffer.toString(), encoding: utf8); await Share.shareXFiles([XFile(file.path)], text: 'تقرير معاملات قرشين');
  }

  Future<void> exportPdfReport({String? cardId}) async {
    final pdf = pw.Document(); 
    final fontRegular = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    double totalIn = 0.0, totalOut = 0.0;
    
    final cardsToExport = cardId == null ? userCards : userCards.where((c) => c.id == cardId).toList();
    String reportTitle = cardId == null ? 'كشف حساب شامل لجميع المحافظ' : 'كشف حساب: ${cardsToExport.first.bank.name}';

    for (var c in cardsToExport) { 
      for (var t in c.transactions) { 
        if (t.isIncome) totalIn += t.amount; else totalOut += t.amount; 
      } 
    }
    
    final tableData = cardsToExport.expand((c) => c.transactions.map((t) => [t.name, '${t.isIncome ? '+' : '-'}${t.amount}', t.date])).toList();

    pdf.addPage(pw.MultiPage(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold), 
      textDirection: pw.TextDirection.rtl,
      build: (pw.Context context) => [
        pw.Text(reportTitle, style: pw.TextStyle(font: fontBold, fontSize: 24)), 
        pw.SizedBox(height: 20),
        pw.Text('الدخل: $totalIn | المصروفات: $totalOut', style: pw.TextStyle(font: fontRegular, fontSize: 16)), 
        pw.SizedBox(height: 20),
        if (tableData.isNotEmpty)
          pw.Table.fromTextArray(
            headers: ['المعاملة', 'المبلغ', 'التاريخ'], 
            data: tableData,
            cellStyle: pw.TextStyle(font: fontRegular),
            headerStyle: pw.TextStyle(font: fontBold),
            cellAlignment: pw.Alignment.centerRight,
          )
        else
          pw.Text('لا توجد معاملات في هذا الحساب.', style: pw.TextStyle(font: fontRegular)),
      ],
    ));
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'qersheen_statement.pdf');
  }

  Future<void> exportSecureBackup() async {
    try {
      final allData = {
        'cards': prefs.getString('cardsData_v34'),
        'installments': prefs.getString('installments_v34'),
        'subscriptions': prefs.getString('subscriptions_v34'),
        'budgets': prefs.getString('catBudgets_v34'),
        'fingerprints': prefs.getStringList('processed_fps_v34'),
      };
      final jsonStr = jsonEncode(allData);
      final bytes = utf8.encode(jsonStr);
      final encrypted = base64Encode(bytes);
      
      final file = File('${Directory.systemTemp.path}/qersheen_secure_backup.bak');
      await file.writeAsString(encrypted);
      await Share.shareXFiles([XFile(file.path)], text: 'نسخ احتياطي مشفر لتطبيق قرشين');
    } catch (_) {}
  }

  Future<void> importSecureBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['bak']);
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final encrypted = await file.readAsString();
        final bytes = base64Decode(encrypted);
        final jsonStr = utf8.decode(bytes);
        final Map<String, dynamic> data = jsonDecode(jsonStr);

        if (data.containsKey('cards') && data['cards'] != null) prefs.setString('cardsData_v34', data['cards']);
        if (data.containsKey('installments') && data['installments'] != null) prefs.setString('installments_v34', data['installments']);
        if (data.containsKey('subscriptions') && data['subscriptions'] != null) prefs.setString('subscriptions_v34', data['subscriptions']);
        if (data.containsKey('budgets') && data['budgets'] != null) prefs.setString('catBudgets_v34', data['budgets']);
        if (data.containsKey('fingerprints') && data['fingerprints'] != null) prefs.setStringList('processed_fps_v34', List<String>.from(data['fingerprints']));
        
        _loadAll();
      }
    } catch (_) {}
  }
}

class UserCardModel {
  final String id, bankId; String cardIdentifier; double balance; final List<TransactionItem> transactions;
  UserCardModel({required this.id, required this.bankId, required this.cardIdentifier, required this.balance, required this.transactions});
  
  BankEntity get bank {
    if (bankId == 'cash') {
      return const BankEntity(id: 'cash', name: 'النقود السائلة', type: 'محفظة', acronym: 'CASH', entityType: EntityType.wallet, network: PaymentNetwork.walletInternal, exactSenders: [], gradientColors: [Color(0xFF2C5364), Color(0xFF203A43), Color(0xFF0F2027)], textColor: Colors.white, cardTypeBadge: 'WALLET', logoPath: '');
    }
    return EgyptInstitutions.all.firstWhere((b) => b.id == bankId, orElse: () => EgyptInstitutions.all.first);
  }

  Map<String, dynamic> toJson() => {'id': id, 'bankId': bankId, 'cardIdentifier': cardIdentifier, 'balance': balance, 'transactions': transactions.map((t) => t.toJson()).toList()};
  factory UserCardModel.fromJson(Map<String, dynamic> j) => UserCardModel(id: j['id'], bankId: j['bankId'], cardIdentifier: j['cardIdentifier'], balance: (j['balance'] as num).toDouble(), transactions: (j['transactions'] as List).map((t) => TransactionItem.fromJson(t)).toList());
}

class TransactionItem {
  final String name, date, category; final String? subtitle, txFingerprint; final double amount; final bool isIncome;
  TransactionItem({required this.name, this.subtitle, required this.date, required this.amount, required this.isIncome, required this.category, this.txFingerprint});
  Map<String, dynamic> toJson() => {'name': name, 'date': date, 'amount': amount, 'isIncome': isIncome, 'category': category, 'txFingerprint': txFingerprint, 'subtitle': subtitle};
  factory TransactionItem.fromJson(Map<String, dynamic> j) => TransactionItem(name: j['name'], date: j['date'], amount: (j['amount'] as num).toDouble(), isIncome: j['isIncome'], category: j['category'] ?? 'عام', txFingerprint: j['txFingerprint'], subtitle: j['subtitle']);
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
        themeMode: appData.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFF8F9FA)),
        darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF09090B)),
        builder: (context, child) => Directionality(textDirection: appData.language == 'ar' ? TextDirection.rtl : TextDirection.ltr, child: child!),
        home: appData.isBiometricEnabled && !appData.isAuthenticated ? AuthLockScreen(appData: appData) : MainLayoutScreen(appData: appData),
      ),
    );
  }
}

class AuthLockScreen extends StatelessWidget {
  final AppData appData; const AuthLockScreen({super.key, required this.appData});
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.fingerprint, size: 80, color: Color(0xFF10B981)), const SizedBox(height: 24), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: () => appData.authenticateUser(), child: Text(AppStrings.get(appData.language, 'auth_msg'), style: const TextStyle(color: Colors.white)))])));
}

class MainLayoutScreen extends StatefulWidget {
  final AppData appData; const MainLayoutScreen({super.key, required this.appData});
  @override State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _tab = 0;
  bool _hasCheckedReminders = false;

  @override void initState() { 
    super.initState(); 
    WidgetsBinding.instance.addPostFrameCallback((_) { 
      widget.appData.initializePermissions(); 
      _checkReminders();
    }); 
  }

  void _checkReminders() {
    if (_hasCheckedReminders) return;
    _hasCheckedReminders = true;
    final today = DateTime.now().day;
    
    final dueInstallments = widget.appData.installments.where((i) => i.paidMonths < i.totalMonths && (i.dueDayOfMonth - today).abs() <= 3).toList();
    final dueSubs = widget.appData.subscriptions.where((s) => (s.dueDayOfMonth - today).abs() <= 3).toList();
    
    final totalDue = dueInstallments.length + dueSubs.length;
    if (totalDue > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تنبيه: لديك $totalDue التزامات مالية (أقساط/اشتراكات) يقترب موعد سدادها!'),
          backgroundColor: Colors.amber.shade800,
          duration: const Duration(seconds: 5),
        )
      );
    }
  }

  @override Widget build(BuildContext context) {
    final pages = [AppleWalletScreen(appData: widget.appData), ObligationsView(appData: widget.appData), CategoryBudgetsView(appData: widget.appData), SettingsTabView(appData: widget.appData)];
    final lang = widget.appData.language;
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab, onTap: (i) => setState(() => _tab = i), type: BottomNavigationBarType.fixed, selectedItemColor: const Color(0xFF10B981), unselectedItemColor: Colors.grey, backgroundColor: widget.appData.isDarkMode ? const Color(0xFF121212) : Colors.white, elevation: 10,
        items: [BottomNavigationBarItem(icon: const Icon(Icons.account_balance_wallet_rounded), label: AppStrings.get(lang, 'wallet')), BottomNavigationBarItem(icon: const Icon(Icons.event_note_rounded), label: AppStrings.get(lang, 'obligations')), BottomNavigationBarItem(icon: const Icon(Icons.pie_chart_rounded), label: AppStrings.get(lang, 'budgets')), BottomNavigationBarItem(icon: const Icon(Icons.settings_rounded), label: AppStrings.get(lang, 'settings'))],
      ),
      floatingActionButton: _tab == 0 ? FloatingActionButton.extended(backgroundColor: const Color(0xFF10B981), icon: const Icon(Icons.add_rounded, color: Colors.white), label: Text(AppStrings.get(lang, 'add_cash'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), onPressed: () => _showManualCashSheet(context)) : null,
    );
  }

  void _showManualCashSheet(BuildContext ctx) {
    final titleCtrl = TextEditingController(); final amtCtrl = TextEditingController(); bool isExpense = true;
    String selectedCat = widget.appData.categoryBudgets.keys.first;

    showModalBottomSheet(context: ctx, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (bCtx) => StatefulBuilder(builder: (c, setS) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(bCtx).viewInsets.bottom, top: 20, left: 20, right: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [Row(children: [ChoiceChip(label: const Text('مصروف (-)'), selected: isExpense, onSelected: (_) => setS(() => isExpense = true), selectedColor: Colors.redAccent.withOpacity(0.3)), const SizedBox(width: 8), ChoiceChip(label: const Text('دخل (+)'), selected: !isExpense, onSelected: (_) => setS(() => isExpense = false), selectedColor: Colors.green.withOpacity(0.3))]), const SizedBox(height: 12), TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder())), const SizedBox(height: 12), TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder())), const SizedBox(height: 12), DropdownButtonFormField<String>(value: selectedCat, items: widget.appData.categoryBudgets.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(), onChanged: (v) => setS(() => selectedCat = v!), decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder())), const SizedBox(height: 16), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: () { final a = double.tryParse(amtCtrl.text); if (a != null && a > 0 && titleCtrl.text.isNotEmpty) { widget.appData.addManualCashTx(title: titleCtrl.text, amount: a, isIncome: !isExpense, category: selectedCat); Navigator.pop(bCtx); } }, child: const Text('حفظ', style: TextStyle(color: Colors.white))), const SizedBox(height: 20)]))));
  }
}

// ---------------- شاشة التحليلات التاريخية المقارنة ----------------
class HistoricalAnalyticsScreen extends StatelessWidget {
  final AppData appData;
  const HistoricalAnalyticsScreen({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    final isDark = appData.isDarkMode;
    
    // حساب المصروفات لآخر 6 شهور
    final now = DateTime.now();
    List<Map<String, dynamic>> monthlyData = [];
    double maxAmount = 0.0;

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthStr = '${monthDate.month}/${monthDate.year}';
      final monthLabel = DateFormat('MMM').format(monthDate);
      
      double monthTotal = 0.0;
      for (var c in appData.userCards) {
        for (var tx in c.transactions) {
          if (!tx.isIncome && tx.date.contains('/$monthStr') || tx.date.endsWith(monthStr)) {
            monthTotal += tx.amount;
          }
        }
      }
      if (monthTotal > maxAmount) maxAmount = monthTotal;
      monthlyData.add({'label': monthLabel, 'total': monthTotal});
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('التحليلات والمقارنات', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        titleTextStyle: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إجمالي المصروفات (آخر 6 أشهر)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxAmount == 0 ? 100 : maxAmount * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem('${rod.toY.toStringAsFixed(0)} EGP', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(monthlyData[value.toInt()]['label'])),
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: monthlyData.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [BarChartRodData(toY: e.value['total'], color: const Color(0xFF10B981), width: 20, borderRadius: BorderRadius.circular(4))],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('نصيحة ذكية:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const SizedBox(height: 8),
            Text('الرسم البياني يساعدك في اكتشاف الشهور التي زادت فيها مصاريفك عن المعدل الطبيعي لتتمكن من ضبط ميزانيتك في المستقبل.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class SearchTransactionsScreen extends StatefulWidget {
  final AppData appData;
  const SearchTransactionsScreen({super.key, required this.appData});
  @override State<SearchTransactionsScreen> createState() => _SearchTransactionsScreenState();
}

class _SearchTransactionsScreenState extends State<SearchTransactionsScreen> {
  String _query = ''; DateTime? _startDate; DateTime? _endDate;
  DateTime? _parseDate(String dateStr) { try { final match = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(dateStr); if (match != null) return DateTime(int.parse(match.group(3)!), int.parse(match.group(2)!), int.parse(match.group(1)!)); } catch (_) {} return null; }
  @override Widget build(BuildContext context) {
    final isDark = widget.appData.isDarkMode;
    final allTxs = widget.appData.userCards.expand((c) => c.transactions.map((t) => {'card': c, 'tx': t})).toList();
    final filtered = allTxs.where((item) {
      final tx = item['tx'] as TransactionItem;
      bool matchesQuery = _query.isEmpty || tx.name.toLowerCase().contains(_query.toLowerCase()) || tx.category.toLowerCase().contains(_query.toLowerCase()) || (tx.subtitle != null && tx.subtitle!.toLowerCase().contains(_query.toLowerCase()));
      bool matchesDate = true;
      if (_startDate != null && _endDate != null) { final d = _parseDate(tx.date); if (d != null) { matchesDate = d.isAfter(_startDate!.subtract(const Duration(days: 1))) && d.isBefore(_endDate!.add(const Duration(days: 1))); } else { matchesDate = false; } }
      return matchesQuery && matchesDate;
    }).toList();
    return Scaffold(appBar: AppBar(backgroundColor: isDark ? const Color(0xFF121212) : Colors.white, elevation: 0, iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black), title: TextField(autofocus: true, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: const InputDecoration(hintText: 'ابحث عن متجر، شخص، أو تصنيف...', hintStyle: TextStyle(color: Colors.grey, fontSize: 14), border: InputBorder.none), onChanged: (v) => setState(() => _query = v)), actions: [IconButton(icon: Icon(Icons.date_range_rounded, color: _startDate != null ? const Color(0xFF10B981) : Colors.grey), onPressed: () async { final res = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2030), builder: (ctx, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF10B981))), child: child!)); if (res != null) setState(() { _startDate = res.start; _endDate = res.end; }); }), if (_startDate != null) IconButton(icon: const Icon(Icons.clear, color: Colors.redAccent), onPressed: () => setState(() { _startDate = null; _endDate = null; }))]), body: filtered.isEmpty ? const Center(child: Text('لا توجد معاملات مطابقة للبحث', style: TextStyle(color: Colors.grey))) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: filtered.length, itemBuilder: (ctx, i) { final tx = filtered[i]['tx'] as TransactionItem; final card = filtered[i]['card'] as UserCardModel; return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tx.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), if (tx.subtitle != null && tx.subtitle!.isNotEmpty) ...[const SizedBox(height: 2), Text(tx.subtitle!, style: TextStyle(color: Colors.blueAccent.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500))], const SizedBox(height: 2), Text('${tx.category} • ${tx.date} • ${card.bank.name}', style: const TextStyle(color: Colors.grey, fontSize: 11))])), Text('${tx.isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)}', style: TextStyle(color: tx.isIncome ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16))])); }));
  }
}

class AppleWalletScreen extends StatefulWidget {
  final AppData appData; const AppleWalletScreen({super.key, required this.appData});
  @override State<AppleWalletScreen> createState() => _AppleWalletScreenState();
}

class _AppleWalletScreenState extends State<AppleWalletScreen> {
  int? _expandedIndex;
  void _showCardOptions(UserCardModel card) {
    final ctrl = TextEditingController(text: card.cardIdentifier);
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24), child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'الاسم أو رقم الحساب', border: OutlineInputBorder())), const SizedBox(height: 16), ElevatedButton(onPressed: () { widget.appData.editCardName(card.id, ctrl.text); Navigator.pop(ctx); }, child: const Text('حفظ التعديل')), TextButton(onPressed: () { widget.appData.deleteCard(card.id); setState((){ _expandedIndex = null; }); Navigator.pop(ctx); }, child: const Text('حذف الكارت', style: TextStyle(color: Colors.redAccent)))])));
  }

  @override Widget build(BuildContext context) {
    final cards = widget.appData.userCards;
    return SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppStrings.get(widget.appData.language, 'wallet'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), Text('${AppStrings.get(widget.appData.language, 'total')} ${widget.appData.getTotalBalance().toStringAsFixed(0)} EGP', style: const TextStyle(color: Colors.grey, fontSize: 14))]), 
        Row(
          children: [
            IconButton(icon: const Icon(Icons.search_rounded, color: Colors.grey, size: 28), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchTransactionsScreen(appData: widget.appData)))),
            IconButton(icon: const Icon(Icons.sync_rounded, color: Colors.blueAccent, size: 28), onPressed: () => widget.appData.autoDetectChronological()),
          ],
        )
      ])),
      Expanded(child: _expandedIndex != null ? _buildExpandedView(cards[_expandedIndex!]) : _buildStackedView(cards)),
    ]));
  }

  Widget _buildStackedView(List<UserCardModel> cards) => SingleChildScrollView(padding: const EdgeInsets.only(bottom: 40), child: SizedBox(height: 220.0 + (cards.length - 1) * 70.0, child: Stack(clipBehavior: Clip.none, children: List.generate(cards.length, (i) => Positioned(top: i * 70.0, left: 16, right: 16, child: GestureDetector(onTap: () => setState(() => _expandedIndex = i), onLongPress: () => _showCardOptions(cards[i]), child: _buildCardDesign(cards[i])))))));
  Widget _buildExpandedView(UserCardModel card) => Column(children: [Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: GestureDetector(onTap: () => setState(() => _expandedIndex = null), onLongPress: () => _showCardOptions(card), child: _buildCardDesign(card))), TextButton.icon(onPressed: () => setState(() => _expandedIndex = null), icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.grey), label: const Text('طي الكارت', style: TextStyle(color: Colors.grey))), Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), itemCount: card.transactions.length, itemBuilder: (ctx, idx) { final tx = card.transactions[idx]; return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tx.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), if (tx.subtitle != null && tx.subtitle!.isNotEmpty) ...[const SizedBox(height: 2), Text(tx.subtitle!, style: TextStyle(color: Colors.blueAccent.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500))], const SizedBox(height: 2), Text('${tx.category} • ${tx.date}', style: const TextStyle(color: Colors.grey, fontSize: 11))])), Text('${tx.isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)}', style: TextStyle(color: tx.isIncome ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16))])); }))]);
  Widget _buildCardDesign(UserCardModel card) {
    return Container(
      height: 220, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: LinearGradient(colors: card.bank.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: card.bank.gradientColors.last.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))]),
      child: Stack(children: [if (card.bank.logoPath.isNotEmpty) Positioned(left: 0, top: 0, child: Opacity(opacity: 0.15, child: Image.asset(card.bank.logoPath, width: 120, height: 120, fit: BoxFit.contain, errorBuilder: (c, e, s) => const SizedBox()))), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(card.bank.name, style: TextStyle(color: card.bank.textColor, fontSize: 18, fontWeight: FontWeight.bold)), if (card.bank.logoPath.isNotEmpty) Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Image.asset(card.bank.logoPath, width: 30, height: 30, fit: BoxFit.contain, errorBuilder: (c, e, s) => Icon(Icons.account_balance, color: card.bank.gradientColors.first)))]), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('الرصيد المتاح', style: TextStyle(color: card.bank.textColor.withOpacity(0.8), fontSize: 12)), Text('${card.balance.toStringAsFixed(2)} EGP', style: TextStyle(color: card.bank.textColor, fontSize: 28, fontWeight: FontWeight.w900))]), Text(card.cardIdentifier, style: TextStyle(color: card.bank.textColor.withOpacity(0.9), fontSize: 16, letterSpacing: 2))])]),
    );
  }
}

// ---------------- واجهة الالتزامات (الأقساط + الاشتراكات) ----------------
class ObligationsView extends StatefulWidget {
  final AppData appData; const ObligationsView({super.key, required this.appData});
  @override State<ObligationsView> createState() => _ObligationsViewState();
}

class _ObligationsViewState extends State<ObligationsView> {
  bool _showInstallments = true;

  void _showAddInstallmentSheet() {
    final titleCtrl = TextEditingController(); final provCtrl = TextEditingController(); final amtCtrl = TextEditingController(); final monthsCtrl = TextEditingController(); final dueDayCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24), child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'اسم السلعة/القسط', border: OutlineInputBorder())), const SizedBox(height: 12), TextField(controller: provCtrl, decoration: const InputDecoration(labelText: 'جهة التقسيط', border: OutlineInputBorder())), const SizedBox(height: 12), Row(children: [Expanded(child: TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'القسط الشهري', border: OutlineInputBorder()))), const SizedBox(width: 12), Expanded(child: TextField(controller: monthsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد الشهور', border: OutlineInputBorder())))]), const SizedBox(height: 12), TextField(controller: dueDayCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'يوم الاستحقاق (من 1 إلى 31)', border: OutlineInputBorder())), const SizedBox(height: 20), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: () { final amt = double.tryParse(amtCtrl.text); final m = int.tryParse(monthsCtrl.text); final d = int.tryParse(dueDayCtrl.text) ?? 1; if (amt != null && m != null && titleCtrl.text.isNotEmpty) { widget.appData.addInstallment(titleCtrl.text, provCtrl.text.isEmpty ? 'جهة تقسيط' : provCtrl.text, amt, m, d); Navigator.pop(ctx); } }, child: const Text('حفظ القسط', style: TextStyle(color: Colors.white))), const SizedBox(height: 20)])));
  }

  void _showAddSubscriptionSheet() {
    final titleCtrl = TextEditingController(); final amtCtrl = TextEditingController(); final dueDayCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24), child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'اسم الاشتراك (مثال: جيم، إنترنت)', border: OutlineInputBorder())), const SizedBox(height: 12), TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ الشهري', border: OutlineInputBorder())), const SizedBox(height: 12), TextField(controller: dueDayCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'يوم التجديد (من 1 إلى 31)', border: OutlineInputBorder())), const SizedBox(height: 20), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: () { final amt = double.tryParse(amtCtrl.text); final d = int.tryParse(dueDayCtrl.text) ?? 1; if (amt != null && titleCtrl.text.isNotEmpty) { widget.appData.addSubscription(titleCtrl.text, amt, d); Navigator.pop(ctx); } }, child: const Text('حفظ الاشتراك', style: TextStyle(color: Colors.white))), const SizedBox(height: 20)])));
  }

  @override Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      Padding(
        padding: const EdgeInsets.all(20), 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            Text('الالتزامات', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), 
            IconButton(icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF10B981), size: 32), onPressed: _showInstallments ? _showAddInstallmentSheet : _showAddSubscriptionSheet)
          ]
        )
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ChoiceChip(label: const Text('الأقساط'), selected: _showInstallments, onSelected: (v) => setState(() => _showInstallments = true), selectedColor: const Color(0xFF10B981).withOpacity(0.2)),
          const SizedBox(width: 12),
          ChoiceChip(label: const Text('الاشتراكات المتكررة'), selected: !_showInstallments, onSelected: (v) => setState(() => _showInstallments = false), selectedColor: const Color(0xFF10B981).withOpacity(0.2)),
        ],
      ),
      const SizedBox(height: 10),
      Expanded(
        child: _showInstallments 
        ? (widget.appData.installments.isEmpty ? const Center(child: Text('لا توجد أقساط مسجلة حالياً', style: TextStyle(color: Colors.grey))) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: widget.appData.installments.length, itemBuilder: (ctx, i) {
            final inst = widget.appData.installments[i]; final isDone = inst.paidMonths >= inst.totalMonths;
            return Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(inst.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text('${inst.provider} • ${inst.monthlyAmount.toStringAsFixed(0)} ج.م / شهر (يوم ${inst.dueDayOfMonth})', style: const TextStyle(color: Colors.grey, fontSize: 13))]), IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => widget.appData.deleteInstallment(inst.id))]), const SizedBox(height: 16), LinearProgressIndicator(value: inst.progress, minHeight: 8, backgroundColor: Colors.grey.withOpacity(0.2), valueColor: AlwaysStoppedAnimation(isDone ? Colors.green : const Color(0xFF10B981))), const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('تم سداد: ${inst.paidMonths} / ${inst.totalMonths} شهر', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), if (!isDone) ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: () => widget.appData.markInstallmentPaid(inst.id), child: const Text('دفع قسط', style: TextStyle(color: Colors.white, fontSize: 12))) else const Text('مكتمل', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))])]));
          }))
        : (widget.appData.subscriptions.isEmpty ? const Center(child: Text('لا توجد اشتراكات مسجلة حالياً', style: TextStyle(color: Colors.grey))) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: widget.appData.subscriptions.length, itemBuilder: (ctx, i) {
            final sub = widget.appData.subscriptions[i];
            return Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(sub.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 4), Text('${sub.amount.toStringAsFixed(0)} ج.م / شهرياً • يتجدد يوم ${sub.dueDayOfMonth}', style: const TextStyle(color: Colors.grey, fontSize: 13))]), IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => widget.appData.deleteSubscription(sub.id))]));
          }))
      )
    ]));
  }
}

class CategoryBudgetsView extends StatelessWidget {
  final AppData appData; const CategoryBudgetsView({super.key, required this.appData});

  void _showAddCategorySheet(BuildContext context) {
    final nameCtrl = TextEditingController(); final limitCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('إضافة تصنيف جديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 16), TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم التصنيف', border: OutlineInputBorder())), const SizedBox(height: 16), TextField(controller: limitCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الحد الأقصى للميزانية (ج.م)', border: OutlineInputBorder())), const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.all(14)), onPressed: () { final newLimit = double.tryParse(limitCtrl.text); if (newLimit != null && newLimit >= 0 && nameCtrl.text.isNotEmpty) { appData.setCategoryBudget(nameCtrl.text, newLimit); Navigator.pop(ctx); } }, child: const Text('حفظ التصنيف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))), const SizedBox(height: 20)])));
  }

  void _showEditBudgetSheet(BuildContext context, String category, double currentLimit) {
    final ctrl = TextEditingController(text: currentLimit.toStringAsFixed(0));
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('تعديل ميزانية: $category', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 16), TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الحد الأقصى الجديد (ج.م)', border: OutlineInputBorder())), const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.all(14)), onPressed: () { final newLimit = double.tryParse(ctrl.text); if (newLimit != null && newLimit >= 0) { appData.setCategoryBudget(category, newLimit); Navigator.pop(ctx); } }, child: const Text('حفظ التعديل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))), const SizedBox(height: 8), SizedBox(width: double.infinity, child: TextButton(onPressed: () { appData.deleteCategoryBudget(category); Navigator.pop(ctx); }, child: const Text('حذف هذا التصنيف', style: TextStyle(color: Colors.redAccent)))), const SizedBox(height: 20)])));
  }

  @override Widget build(BuildContext context) {
    List<PieChartSectionData> chartSections = [];
    final colors = [Colors.blue, Colors.redAccent, Colors.amber, Colors.green, Colors.purple, Colors.orange];
    int colorIndex = 0;
    
    appData.categoryBudgets.forEach((key, value) {
      final spent = appData.getCategoryMonthlySpent(key);
      if (spent > 0) {
        chartSections.add(PieChartSectionData(color: colors[colorIndex % colors.length], value: spent, title: key, radius: 50, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)));
        colorIndex++;
      }
    });

    return SafeArea(child: Scaffold(
      floatingActionButton: FloatingActionButton.extended(backgroundColor: const Color(0xFF10B981), icon: const Icon(Icons.add, color: Colors.white), label: const Text('تصنيف جديد', style: TextStyle(color: Colors.white)), onPressed: () => _showAddCategorySheet(context)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(icon: const Icon(Icons.bar_chart_rounded, color: Colors.blueAccent, size: 30), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoricalAnalyticsScreen(appData: appData)))),
          Text(AppStrings.get(appData.language, 'budgets'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ])),
        if (chartSections.isNotEmpty) 
          SizedBox(height: 180, child: PieChart(PieChartData(sections: chartSections, centerSpaceRadius: 40, sectionsSpace: 2))),
        if (chartSections.isNotEmpty) const SizedBox(height: 20),
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), children: appData.categoryBudgets.entries.map((e) {
          final spent = appData.getCategoryMonthlySpent(e.key); final limit = e.value; final pct = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0; final isExceeded = spent > limit;
          return GestureDetector(
            onTap: () => _showEditBudgetSheet(context, e.key, limit),
            child: Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(20), border: isExceeded ? Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5) : null), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, color: isExceeded ? Colors.redAccent : const Color(0xFF10B981)))]), const SizedBox(height: 12), LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.grey.withOpacity(0.2), valueColor: AlwaysStoppedAnimation(isExceeded ? Colors.redAccent : const Color(0xFF10B981))), const SizedBox(height: 12), Text('الاستهلاك: ${spent.toStringAsFixed(0)} من أصل ${limit.toStringAsFixed(0)} ج.م', style: const TextStyle(fontSize: 12, color: Colors.grey))])),
          );
        }).toList()))
      ]),
    ));
  }
}

class SettingsTabView extends StatelessWidget {
  final AppData appData; const SettingsTabView({super.key, required this.appData});

  void _showPdfExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختر الحساب لتصدير التقرير', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF10B981)),
              title: const Text('جميع الحسابات والمحافظ'),
              onTap: () { Navigator.pop(ctx); appData.exportPdfReport(); },
            ),
            const Divider(),
            ...appData.userCards.map((card) => ListTile(
              leading: Icon(Icons.credit_card_rounded, color: card.bank.gradientColors.first),
              title: Text(card.bank.name),
              subtitle: Text(card.cardIdentifier),
              onTap: () { Navigator.pop(ctx); appData.exportPdfReport(cardId: card.id); },
            )).toList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final lang = appData.language;
    return SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      Text(AppStrings.get(lang, 'settings'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
      ListTile(leading: const Icon(Icons.table_chart_rounded, color: Colors.green, size: 28), title: Text(AppStrings.get(lang, 'export_csv')), onTap: () => appData.exportCsvReport()), const Divider(),
      ListTile(leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 28), title: Text(AppStrings.get(lang, 'export_pdf')), onTap: () => _showPdfExportOptions(context)), const Divider(),
      ListTile(leading: const Icon(Icons.lock_reset_rounded, color: Colors.amber, size: 28), title: const Text('نسخ احتياطي مشفر (Backup)'), subtitle: const Text('تصدير ملف بيانات آمن ومحمي'), onTap: () => appData.exportSecureBackup()), const Divider(),
      ListTile(leading: const Icon(Icons.restore_rounded, color: Colors.teal, size: 28), title: const Text('استعادة البيانات (Restore)'), subtitle: const Text('استرجاع بياناتك من ملف النسخ الاحتياطي'), onTap: () => appData.importSecureBackup()), const Divider(),
      SwitchListTile(secondary: const Icon(Icons.language_rounded, color: Colors.blue, size: 28), title: const Text('English / العربية'), value: lang == 'en', onChanged: (_) => appData.toggleLanguage()),
      SwitchListTile(secondary: const Icon(Icons.fingerprint_rounded, color: Color(0xFF10B981), size: 28), title: const Text('البصمة / Biometrics'), activeColor: const Color(0xFF10B981), value: appData.isBiometricEnabled, onChanged: (v) => appData.toggleBiometric(v)),
      SwitchListTile(secondary: const Icon(Icons.dark_mode_rounded, size: 28), title: const Text('الوضع الداكن / Dark Mode'), activeColor: const Color(0xFF10B981), value: appData.isDarkMode, onChanged: (v) => appData.toggleTheme()),
    ]));
  }
}
