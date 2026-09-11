import 'package:file_picker/file_picker.dart';
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
import 'package:intl/intl.dart' hide TextDirection;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(QersheenApp(prefs: prefs));
}

class AppStrings {
  static Map<String, Map<String, String>> t = {
    'ar': {
      'wallet': 'المحفظة', 'obligations': 'الالتزامات', 'budgets': 'الميزانيات', 'savings': 'التحويش', 'settings': 'الإعدادات',
      'total': 'الإجمالي:', 'sync': 'مزامنة الرسائل', 'add_cash': 'إضافة معاملة', 'auth_msg': 'قم بتأكيد هويتك لفتح المحفظة'
    },
    'en': {
      'wallet': 'Wallet', 'obligations': 'Obligations', 'budgets': 'Budgets', 'savings': 'Savings', 'settings': 'Settings',
      'total': 'Total:', 'sync': 'Sync SMS', 'add_cash': 'Add Transaction', 'auth_msg': 'Authenticate to open Wallet'
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

class DebtModel {
  final String id, title, personName;
  double amount;
  bool isOwedToMe; 
  String dueDate;
  DebtModel({required this.id, required this.title, required this.personName, required this.amount, required this.isOwedToMe, required this.dueDate});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'personName': personName, 'amount': amount, 'isOwedToMe': isOwedToMe, 'dueDate': dueDate};
  factory DebtModel.fromJson(Map<String, dynamic> j) => DebtModel(id: j['id'], title: j['title'], personName: j['personName'], amount: (j['amount'] as num).toDouble(), isOwedToMe: j['isOwedToMe'], dueDate: j['dueDate']);
}

class SavingsGoalModel {
  final String id, title;
  double targetAmount, currentAmount;
  SavingsGoalModel({required this.id, required this.title, required this.targetAmount, required this.currentAmount});
  double get progress => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'targetAmount': targetAmount, 'currentAmount': currentAmount};
  factory SavingsGoalModel.fromJson(Map<String, dynamic> j) => SavingsGoalModel(id: j['id'], title: j['title'], targetAmount: (j['targetAmount'] as num).toDouble(), currentAmount: (j['currentAmount'] as num).toDouble());
}

class AppData extends ChangeNotifier {
  final SharedPreferences prefs;
  bool isDarkMode, isBiometricEnabled, isAuthenticated = false;
  String language, currency;
  List<UserCardModel> userCards = [];
  List<InstallmentModel> installments = [];
  List<SubscriptionModel> subscriptions = [];
  List<DebtModel> debts = [];
  List<SavingsGoalModel> savingsGoals = [];
  Map<String, double> categoryBudgets = {};
  Set<String> processedMessageFingerprints = {};
  final LocalAuthentication _auth = LocalAuthentication();

  AppData(this.prefs)
      : isDarkMode = prefs.getBool('isDark') ?? true,
        isBiometricEnabled = prefs.getBool('isBioEnabled') ?? false,
        language = prefs.getString('app_lang') ?? 'ar',
        currency = prefs.getString('app_currency') ?? 'EGP' {
    _loadAll();
    _checkInitialAuth();
  }

  void _checkInitialAuth() { if (!isBiometricEnabled) isAuthenticated = true; }
  void toggleLanguage() { language = language == 'ar' ? 'en' : 'ar'; prefs.setString('app_lang', language); notifyListeners(); }
  void toggleTheme() { isDarkMode = !isDarkMode; prefs.setBool('isDark', isDarkMode); notifyListeners(); }
  void setCurrency(String c) { currency = c; prefs.setString('app_currency', c); notifyListeners(); }
  
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
    final cJson = prefs.getString('cardsData_v36');
    if (cJson != null && cJson.isNotEmpty) userCards = (jsonDecode(cJson) as List).map((e) => UserCardModel.fromJson(e)).toList();
    else { userCards = [UserCardModel(id: 'cash_wallet_main', bankId: 'cash', cardIdentifier: language == 'ar' ? 'محفظة النقود السائلة' : 'Cash Wallet', balance: 0.0, transactions: [])]; saveCards(); }
    
    final iJson = prefs.getString('installments_v36');
    if (iJson != null && iJson.isNotEmpty) installments = (jsonDecode(iJson) as List).map((e) => InstallmentModel.fromJson(e)).toList();

    final sJson = prefs.getString('subscriptions_v36');
    if (sJson != null && sJson.isNotEmpty) subscriptions = (jsonDecode(sJson) as List).map((e) => SubscriptionModel.fromJson(e)).toList();

    final dJson = prefs.getString('debts_v36');
    if (dJson != null && dJson.isNotEmpty) debts = (jsonDecode(dJson) as List).map((e) => DebtModel.fromJson(e)).toList();

    final gJson = prefs.getString('savings_goals_v36');
    if (gJson != null && gJson.isNotEmpty) savingsGoals = (jsonDecode(gJson) as List).map((e) => SavingsGoalModel.fromJson(e)).toList();
    
    final bJson = prefs.getString('catBudgets_v36');
    if (bJson != null && bJson.isNotEmpty) { 
      categoryBudgets = (jsonDecode(bJson) as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    } else { 
      categoryBudgets = {'فواتير ومشتريات': 3000.0, 'سوبرماركت': 4000.0, 'مواصلات': 1500.0, 'مطاعم وأكل': 2000.0, 'وقود': 1000.0, 'تسوق': 2000.0, 'تعليم': 1500.0, 'ترفيه': 1000.0, 'عام': 2000.0}; 
      saveCategoryBudgets(); 
    }
    
    final fps = prefs.getStringList('processed_fps_v36');
    if (fps != null) processedMessageFingerprints = fps.toSet();
  }

  Future<void> wipeAllData() async {
    await prefs.clear();
    userCards = []; installments = []; subscriptions = []; debts = []; savingsGoals = []; categoryBudgets = {}; processedMessageFingerprints.clear();
    prefs.setBool('isDark', isDarkMode); prefs.setString('app_lang', language); prefs.setString('app_currency', currency); prefs.setBool('isBioEnabled', isBiometricEnabled);
    _loadAll();
    notifyListeners();
  }

  void saveCards() { prefs.setString('cardsData_v36', jsonEncode(userCards.map((c) => c.toJson()).toList())); prefs.setStringList('processed_fps_v36', processedMessageFingerprints.toList()); notifyListeners(); }
  void saveInstallments() { prefs.setString('installments_v36', jsonEncode(installments.map((i) => i.toJson()).toList())); notifyListeners(); }
  void saveSubscriptions() { prefs.setString('subscriptions_v36', jsonEncode(subscriptions.map((i) => i.toJson()).toList())); notifyListeners(); }
  void saveDebts() { prefs.setString('debts_v36', jsonEncode(debts.map((i) => i.toJson()).toList())); notifyListeners(); }
  void saveSavingsGoals() { prefs.setString('savings_goals_v36', jsonEncode(savingsGoals.map((g) => g.toJson()).toList())); notifyListeners(); }
  void saveCategoryBudgets() { prefs.setString('catBudgets_v36', jsonEncode(categoryBudgets)); notifyListeners(); }

  void addInstallment(String title, String provider, double monthly, int months, int dueDay) { installments.add(InstallmentModel(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title, provider: provider, monthlyAmount: monthly, totalMonths: months, paidMonths: 0, dueDayOfMonth: dueDay)); saveInstallments(); }
  void markInstallmentPaid(String id) { final inst = installments.firstWhere((i) => i.id == id); if (inst.paidMonths < inst.totalMonths) { inst.paidMonths++; saveInstallments(); } }
  void deleteInstallment(String id) { installments.removeWhere((i) => i.id == id); saveInstallments(); }
  
  void addSubscription(String title, double amount, int dueDay) { subscriptions.add(SubscriptionModel(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title, amount: amount, dueDayOfMonth: dueDay)); saveSubscriptions(); }
  void deleteSubscription(String id) { subscriptions.removeWhere((i) => i.id == id); saveSubscriptions(); }

  void addDebt(String title, String personName, double amount, bool isOwedToMe, String dueDate) { debts.add(DebtModel(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title, personName: personName, amount: amount, isOwedToMe: isOwedToMe, dueDate: dueDate)); saveDebts(); }
  void deleteDebt(String id) { debts.removeWhere((i) => i.id == id); saveDebts(); }

  void addSavingsGoal(String title, double target) { savingsGoals.add(SavingsGoalModel(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title, targetAmount: target, currentAmount: 0.0)); saveSavingsGoals(); }
  void depositToGoal(String id, double amount, String sourceCardId) { 
    final goal = savingsGoals.firstWhere((g) => g.id == id); 
    goal.currentAmount += amount; 
    addManualTransaction(cardId: sourceCardId, title: 'إيداع في حصالة: ${goal.title}', amount: amount, isIncome: false, category: 'تحويل داخلي');
    saveSavingsGoals(); 
  }
  void deleteSavingsGoal(String id) { savingsGoals.removeWhere((g) => g.id == id); saveSavingsGoals(); }

  void editCardName(String cardId, String newName) { userCards.firstWhere((c) => c.id == cardId).cardIdentifier = newName; saveCards(); }
  void deleteCard(String cardId) { if (cardId != 'cash_wallet_main') { userCards.removeWhere((c) => c.id == cardId); saveCards(); } }
  
  void setCategoryBudget(String category, double limit) { categoryBudgets[category] = limit; saveCategoryBudgets(); }
  void deleteCategoryBudget(String category) { categoryBudgets.remove(category); saveCategoryBudgets(); }

  void addManualTransaction({required String cardId, required String title, required double amount, required bool isIncome, required String category}) {
    final card = userCards.firstWhere((c) => c.id == cardId, orElse: () => userCards.first);
    if (isIncome) card.balance += amount; else card.balance -= amount;
    final timeStr = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
    card.transactions.insert(0, TransactionItem(name: title, subtitle: 'إدخال يدوي', date: timeStr, amount: amount, isIncome: isIncome, category: category, txFingerprint: 'manual_${DateTime.now().millisecondsSinceEpoch}'));
    saveCards();
  }

  void internalTransfer(String fromId, String toId, double amount) {
    final fromCard = userCards.firstWhere((c) => c.id == fromId);
    final toCard = userCards.firstWhere((c) => c.id == toId);
    fromCard.balance -= amount;
    toCard.balance += amount;
    final timeStr = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
    final fingerprint = 'transfer_${DateTime.now().millisecondsSinceEpoch}';
    fromCard.transactions.insert(0, TransactionItem(name: 'تحويل إلى ${toCard.bank.name}', subtitle: 'تحويل داخلي', date: timeStr, amount: amount, isIncome: false, category: 'تحويل داخلي', txFingerprint: '${fingerprint}_out'));
    toCard.transactions.insert(0, TransactionItem(name: 'تحويل من ${fromCard.bank.name}', subtitle: 'تحويل داخلي', date: timeStr, amount: amount, isIncome: true, category: 'تحويل داخلي', txFingerprint: '${fingerprint}_in'));
    saveCards();
  }

  void updateTransaction(String cardId, String txFingerprint, String newTitle, double newAmount, String newCategory) {
    final card = userCards.firstWhere((c) => c.id == cardId);
    final index = card.transactions.indexWhere((t) => t.txFingerprint == txFingerprint);
    if (index != -1) {
      final oldTx = card.transactions[index];
      if (oldTx.isIncome) card.balance -= oldTx.amount; else card.balance += oldTx.amount;
      if (oldTx.isIncome) card.balance += newAmount; else card.balance -= newAmount;
      card.transactions[index] = TransactionItem(name: newTitle, subtitle: oldTx.subtitle, date: oldTx.date, amount: newAmount, isIncome: oldTx.isIncome, category: newCategory, txFingerprint: oldTx.txFingerprint);
      saveCards();
    }
  }

  void deleteTransaction(String cardId, String txFingerprint) {
    final card = userCards.firstWhere((c) => c.id == cardId);
    final tx = card.transactions.firstWhere((t) => t.txFingerprint == txFingerprint);
    if (tx.isIncome) card.balance -= tx.amount; else card.balance += tx.amount;
    card.transactions.removeWhere((t) => t.txFingerprint == txFingerprint);
    saveCards();
  }

  double getTotalBalance() { double total = 0.0; for (var c in userCards) total += c.balance; return total; }
  double getCategoryMonthlySpent(String cat) { double total = 0.0; final mStr = '/${DateTime.now().month}/${DateTime.now().year}'; for (var c in userCards) { for (var tx in c.transactions) { if (!tx.isIncome && tx.category != 'تحويل داخلي' && (tx.category == cat || tx.date.contains(mStr))) total += tx.amount; } } return total; }

  Future<void> autoDetectChronological() async {
    try {
      if (!(await Permission.sms.isGranted)) return;
      final msgs = await SmsQuery().querySms(kinds: [SmsQueryKind.inbox], count: 50);
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
    String category = isIncome ? 'تحويلات' : 'فواتير ومشتريات';
    final lowerName = extractedName.toLowerCase();
    if (!isIncome) {
      if (RegExp(r'(uber|careem|indrive|ديدي|اوبر|كريم|مواصلات|قطار|سويفل|swvl)').hasMatch(lowerName)) { category = 'مواصلات'; } 
      else if (RegExp(r'(carrefour|kazyon|spinneys|hyper|بيم|كارفور|كازيون|سوبرماركت|خير زمان|هايبر)').hasMatch(lowerName)) { category = 'سوبرماركت'; } 
      else if (RegExp(r'(gas|fuel|station|بنزين|وقود|محطة|وطنية|chillout|chilout|mobil|shell|emarat|امارات)').hasMatch(lowerName)) { category = 'وقود'; } 
      else if (RegExp(r'(restaurant|food|kfc|mcdonalds|mac|مطعم|اكل|كشري|بيتزا|برجر|طلبات|talabat|elmenus|طعام|كافيه|cafe|coffee|starbucks)').hasMatch(lowerName)) { category = 'مطاعم وأكل'; } 
      else if (RegExp(r'(school|university|college|academy|مدرسة|جامعة|اكاديمية|كورس|تعليم|دراسة|course|مركز)').hasMatch(lowerName)) { category = 'تعليم'; } 
      else if (RegExp(r'(cinema|movie|netflix|spotify|سينما|ترفيه|نادي|اشتراك|العاب|games|play|playstation|بلايستيشن|شاهد|shahid)').hasMatch(lowerName)) { category = 'ترفيه'; } 
      else if (RegExp(r'(amazon|noon|jumia|zara|lc waikiki|hm|h&m|تسوق|ملابس|امازون|نون|جوميا|shein|lcwaikiki|defacto|nike|adidas|مول|mall)').hasMatch(lowerName)) { category = 'تسوق'; }
      if (!categoryBudgets.containsKey(category)) setCategoryBudget(category, 1500.0);
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
          pw.Table.fromTextArray(headers: ['المعاملة', 'المبلغ', 'التاريخ'], data: tableData, cellStyle: pw.TextStyle(font: fontRegular), headerStyle: pw.TextStyle(font: fontBold), cellAlignment: pw.Alignment.centerRight)
        else
          pw.Text('لا توجد معاملات في هذا الحساب.', style: pw.TextStyle(font: fontRegular)),
      ],
    ));
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'qersheen_statement.pdf');
  }

  Future<void> exportSecureBackup() async {
    try {
      final allData = {
        'cards': prefs.getString('cardsData_v36'), 'installments': prefs.getString('installments_v36'),
        'subscriptions': prefs.getString('subscriptions_v36'), 'debts': prefs.getString('debts_v36'),
        'savings': prefs.getString('savings_goals_v36'), 'budgets': prefs.getString('catBudgets_v36'), 'fingerprints': prefs.getStringList('processed_fps_v36'),
      };
      final encrypted = base64Encode(utf8.encode(jsonEncode(allData)));
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
        final Map<String, dynamic> data = jsonDecode(utf8.decode(base64Decode(encrypted)));
        if (data.containsKey('cards') && data['cards'] != null) prefs.setString('cardsData_v36', data['cards']);
        if (data.containsKey('installments') && data['installments'] != null) prefs.setString('installments_v36', data['installments']);
        if (data.containsKey('subscriptions') && data['subscriptions'] != null) prefs.setString('subscriptions_v36', data['subscriptions']);
        if (data.containsKey('debts') && data['debts'] != null) prefs.setString('debts_v36', data['debts']);
        if (data.containsKey('savings') && data['savings'] != null) prefs.setString('savings_goals_v36', data['savings']);
        if (data.containsKey('budgets') && data['budgets'] != null) prefs.setString('catBudgets_v36', data['budgets']);
        if (data.containsKey('fingerprints') && data['fingerprints'] != null) prefs.setStringList('processed_fps_v36', List<String>.from(data['fingerprints']));
        _loadAll();
      }
    } catch (_) {}
  }
}

class UserCardModel {
  final String id, bankId; String cardIdentifier; double balance; final List<TransactionItem> transactions;
  UserCardModel({required this.id, required this.bankId, required this.cardIdentifier, required this.balance, required this.transactions});
  BankEntity get bank {
    if (bankId == 'cash') return const BankEntity(id: 'cash', name: 'النقود السائلة', type: 'محفظة', acronym: 'CASH', entityType: EntityType.wallet, network: PaymentNetwork.walletInternal, exactSenders: [], gradientColors: [Color(0xFF2C5364), Color(0xFF203A43), Color(0xFF0F2027)], textColor: Colors.white, cardTypeBadge: 'WALLET', logoPath: '');
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
  @override Widget build(BuildContext context) {
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

class _MainLayoutScreenState extends State<MainLayoutScreen> with WidgetsBindingObserver {
  int _tab = 0; bool _hasCheckedReminders = false;
  final GlobalKey<AppleWalletScreenState> _walletKey = GlobalKey();
  final GlobalKey<ObligationsViewState> _obsKey = GlobalKey();
  final GlobalKey<CategoryBudgetsViewState> _budgetsKey = GlobalKey();
  final GlobalKey<SavingsGoalsViewState> _savingsKey = GlobalKey();

  @override void initState() { 
    super.initState(); 
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) { widget.appData.initializePermissions(); _checkReminders(); }); 
  }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.appData.isBiometricEnabled) { widget.appData.isAuthenticated = false; widget.appData.authenticateUser(); }
  }

  void _checkReminders() {
    if (_hasCheckedReminders) return;
    _hasCheckedReminders = true;
    final today = DateTime.now().day;
    final dueInstallments = widget.appData.installments.where((i) => i.paidMonths < i.totalMonths && (i.dueDayOfMonth - today).abs() <= 3).toList();
    final dueSubs = widget.appData.subscriptions.where((s) => (s.dueDayOfMonth - today).abs() <= 3).toList();
    final dueDebts = widget.appData.debts.where((d) {
      try { final dt = DateFormat('dd/MM/yyyy').parse(d.dueDate); return dt.difference(DateTime.now()).inDays <= 3; } catch (_) { return false; }
    }).toList();
    
    final totalDue = dueInstallments.length + dueSubs.length + dueDebts.length;
    if (totalDue > 0) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تنبيه: لديك $totalDue التزامات مالية يقترب موعد سدادها!'), backgroundColor: Colors.amber.shade800, duration: const Duration(seconds: 5)));
  }

  void _handleFabPressed() {
    if (_tab == 0) _walletKey.currentState?._showActionOptions();
    else if (_tab == 1) _obsKey.currentState?._showAddOptions();
    else if (_tab == 2) _budgetsKey.currentState?._showAddCategorySheet(context);
    else if (_tab == 3) _savingsKey.currentState?._showAddGoalSheet();
  }

  @override Widget build(BuildContext context) {
    final pages = [AppleWalletScreen(key: _walletKey, appData: widget.appData), ObligationsView(key: _obsKey, appData: widget.appData), CategoryBudgetsView(key: _budgetsKey, appData: widget.appData), SavingsGoalsView(key: _savingsKey, appData: widget.appData), SettingsTabView(appData: widget.appData)];
    final lang = widget.appData.language;
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab, onTap: (i) => setState(() => _tab = i), type: BottomNavigationBarType.fixed, selectedItemColor: const Color(0xFF10B981), unselectedItemColor: Colors.grey, backgroundColor: widget.appData.isDarkMode ? const Color(0xFF121212) : Colors.white, elevation: 10,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.account_balance_wallet_rounded), label: AppStrings.get(lang, 'wallet')),
          BottomNavigationBarItem(icon: const Icon(Icons.event_note_rounded), label: AppStrings.get(lang, 'obligations')),
          BottomNavigationBarItem(icon: const Icon(Icons.pie_chart_rounded), label: AppStrings.get(lang, 'budgets')),
          BottomNavigationBarItem(icon: const Icon(Icons.savings_rounded), label: AppStrings.get(lang, 'savings')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings_rounded), label: AppStrings.get(lang, 'settings'))
        ],
      ),
      floatingActionButton: _tab < 4 ? FloatingActionButton(backgroundColor: const Color(0xFF10B981), child: const Icon(Icons.add_rounded, color: Colors.white, size: 32), onPressed: _handleFabPressed) : null,
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  const EmptyStateWidget({super.key, required this.icon, required this.title, required this.subtitle});
  @override Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 80, color: Colors.grey.withOpacity(0.3)), const SizedBox(height: 16), Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600)), const SizedBox(height: 8), Text(subtitle, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center)]));
}

class AppleWalletScreen extends StatefulWidget {
  final AppData appData; const AppleWalletScreen({super.key, required this.appData});
  @override State<AppleWalletScreen> createState() => AppleWalletScreenState();
}

class AppleWalletScreenState extends State<AppleWalletScreen> {
  final PageController _pageCtrl = PageController(viewportFraction: 0.9);
  int _currentCardIndex = 0;

  void _showActionOptions() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.add_card_rounded, color: Color(0xFF10B981)), title: const Text('إضافة معاملة يدوية'), onTap: () { Navigator.pop(ctx); _showManualTransactionSheet(); }),
      const Divider(),
      ListTile(leading: const Icon(Icons.swap_horiz_rounded, color: Colors.blueAccent), title: const Text('تحويل داخلي بين حساباتي'), onTap: () { Navigator.pop(ctx); _showInternalTransferSheet(); })
    ])));
  }

  void _showManualTransactionSheet() {
    final titleCtrl = TextEditingController(); final amtCtrl = TextEditingController(); bool isExpense = true;
    String selectedCardId = widget.appData.userCards[_currentCardIndex].id;
    String selectedCat = widget.appData.categoryBudgets.keys.first;

    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (bCtx) => StatefulBuilder(builder: (c, setS) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(bCtx).viewInsets.bottom, top: 20, left: 20, right: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [ChoiceChip(label: const Text('مصروف (-)'), selected: isExpense, onSelected: (_) => setS(() => isExpense = true), selectedColor: Colors.redAccent.withOpacity(0.3)), const SizedBox(width: 8), ChoiceChip(label: const Text('دخل (+)'), selected: !isExpense, onSelected: (_) => setS(() => isExpense = false), selectedColor: Colors.green.withOpacity(0.3))]), 
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: selectedCardId, items: widget.appData.userCards.map((k) => DropdownMenuItem(value: k.id, child: Text('${k.bank.name} (${k.cardIdentifier})'))).toList(), onChanged: (v) => setS(() => selectedCardId = v!), decoration: const InputDecoration(labelText: 'اختر الحساب/البطاقة', border: OutlineInputBorder())),
      const SizedBox(height: 12), TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'اسم المعاملة', border: OutlineInputBorder())), 
      const SizedBox(height: 12), TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder())), 
      const SizedBox(height: 12), DropdownButtonFormField<String>(value: selectedCat, items: widget.appData.categoryBudgets.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(), onChanged: (v) => setS(() => selectedCat = v!), decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder())), 
      const SizedBox(height: 16), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: () { final a = double.tryParse(amtCtrl.text); if (a != null && a > 0 && titleCtrl.text.isNotEmpty) { widget.appData.addManualTransaction(cardId: selectedCardId, title: titleCtrl.text, amount: a, isIncome: !isExpense, category: selectedCat); Navigator.pop(bCtx); } }, child: const Text('حفظ المعاملة', style: TextStyle(color: Colors.white))), const SizedBox(height: 20)
    ]))));
  }

  void _showInternalTransferSheet() {
    final amtCtrl = TextEditingController();
    String fromId = widget.appData.userCards.first.id;
    String toId = widget.appData.userCards.length > 1 ? widget.appData.userCards[1].id : widget.appData.userCards.first.id;

    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (bCtx) => StatefulBuilder(builder: (c, setS) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(bCtx).viewInsets.bottom, top: 20, left: 20, right: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('تحويل داخلي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
      DropdownButtonFormField<String>(value: fromId, items: widget.appData.userCards.map((k) => DropdownMenuItem(value: k.id, child: Text('${k.bank.name} (${k.cardIdentifier})'))).toList(), onChanged: (v) => setS(() => fromId = v!), decoration: const InputDecoration(labelText: 'من حساب', border: OutlineInputBorder())), const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: toId, items: widget.appData.userCards.map((k) => DropdownMenuItem(value: k.id, child: Text('${k.bank.name} (${k.cardIdentifier})'))).toList(), onChanged: (v) => setS(() => toId = v!), decoration: const InputDecoration(labelText: 'إلى حساب', border: OutlineInputBorder())), const SizedBox(height: 12),
      TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder())), const SizedBox(height: 20),
      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), onPressed: () { final a = double.tryParse(amtCtrl.text); if (a != null && a > 0 && fromId != toId) { widget.appData.internalTransfer(fromId, toId, a); Navigator.pop(bCtx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحويل الداخلي بنجاح'))); } }, child: const Text('تأكيد التحويل', style: TextStyle(color: Colors.white))), const SizedBox(height: 20)
    ]))));
  }

  void _showEditOrDeleteTxSheet(UserCardModel card, TransactionItem tx) {
    final titleCtrl = TextEditingController(text: tx.name); final amtCtrl = TextEditingController(text: tx.amount.toStringAsFixed(0));
    String selectedCat = widget.appData.categoryBudgets.containsKey(tx.category) ? tx.category : widget.appData.categoryBudgets.keys.first;
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('تعديل أو حذف المعاملة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 16), TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'اسم المعاملة', border: OutlineInputBorder())), const SizedBox(height: 12), TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder())), const SizedBox(height: 12), DropdownButtonFormField<String>(value: selectedCat, items: widget.appData.categoryBudgets.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(), onChanged: (v) => selectedCat = v!, decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder())), const SizedBox(height: 20), Row(children: [Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: () { final a = double.tryParse(amtCtrl.text); if (a != null && a > 0 && titleCtrl.text.isNotEmpty && tx.txFingerprint != null) { widget.appData.updateTransaction(card.id, tx.txFingerprint!, titleCtrl.text, a, selectedCat); Navigator.pop(ctx); setState(() {}); } }, child: const Text('حفظ التعديل', style: TextStyle(color: Colors.white)))), const SizedBox(width: 12), Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () { if (tx.txFingerprint != null) { widget.appData.deleteTransaction(card.id, tx.txFingerprint!); Navigator.pop(ctx); setState(() {}); } }, child: const Text('حذف المعاملة', style: TextStyle(color: Colors.white))))]), const SizedBox(height: 20)])));
  }

  @override Widget build(BuildContext context) {
    final cards = widget.appData.userCards;
    if (_currentCardIndex >= cards.length) _currentCardIndex = 0;
    final currentCard = cards.isNotEmpty ? cards[_currentCardIndex] : null;

    return SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppStrings.get(widget.appData.language, 'wallet'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), Text('${AppStrings.get(widget.appData.language, 'total')} ${widget.appData.getTotalBalance().toStringAsFixed(0)} ${widget.appData.currency}', style: const TextStyle(color: Colors.grey, fontSize: 14))]), 
        Row(children: [
          IconButton(icon: const Icon(Icons.search_rounded, color: Colors.grey, size: 28), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchTransactionsScreen(appData: widget.appData)))),
          IconButton(icon: const Icon(Icons.sync_rounded, color: Colors.blueAccent, size: 28), onPressed: () async { await widget.appData.autoDetectChronological(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم مزامنة الرسائل بنجاح'))); }),
        ])
      ])),
      SizedBox(
        height: 220,
        child: PageView.builder(
          controller: _pageCtrl, itemCount: cards.length,
          onPageChanged: (i) => setState(() => _currentCardIndex = i),
          itemBuilder: (ctx, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: GestureDetector(onLongPress: () { final ctrl = TextEditingController(text: cards[i].cardIdentifier); showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24), child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'الاسم أو رقم الحساب', border: OutlineInputBorder())), const SizedBox(height: 16), ElevatedButton(onPressed: () { widget.appData.editCardName(cards[i].id, ctrl.text); Navigator.pop(ctx); setState((){}); }, child: const Text('حفظ التعديل')), TextButton(onPressed: () { widget.appData.deleteCard(cards[i].id); Navigator.pop(ctx); setState((){ _currentCardIndex = 0; }); }, child: const Text('حذف الكارت', style: TextStyle(color: Colors.redAccent)))]))); }, child: _buildCardDesign(cards[i]))),
        )
      ),
      const SizedBox(height: 16),
      Expanded(
        child: currentCard == null || currentCard.transactions.isEmpty
        ? const EmptyStateWidget(icon: Icons.receipt_long_rounded, title: 'لا توجد معاملات', subtitle: 'اسحب بطاقتك وأضف معاملاتك لتبدأ التتبع')
        : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: currentCard.transactions.length, itemBuilder: (ctx, idx) { 
            final tx = currentCard.transactions[idx]; 
            return GestureDetector(
              onTap: () => _showEditOrDeleteTxSheet(currentCard, tx),
              child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tx.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), if (tx.subtitle != null && tx.subtitle!.isNotEmpty) ...[const SizedBox(height: 2), Text(tx.subtitle!, style: TextStyle(color: Colors.blueAccent.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500))], const SizedBox(height: 2), Text('${tx.category} • ${tx.date}', style: const TextStyle(color: Colors.grey, fontSize: 11))])), Text('${tx.isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)} ${widget.appData.currency}', style: TextStyle(color: tx.isIncome ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16))])),
            ); 
          })
      )
    ]));
  }
  
  Widget _buildCardDesign(UserCardModel card) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: LinearGradient(colors: card.bank.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: card.bank.gradientColors.last.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))]),
      child: Stack(children: [if (card.bank.logoPath.isNotEmpty) Positioned(left: 0, top: 0, child: Opacity(opacity: 0.15, child: Image.asset(card.bank.logoPath, width: 120, height: 120, fit: BoxFit.contain, errorBuilder: (c, e, s) => const SizedBox()))), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(card.bank.name, style: TextStyle(color: card.bank.textColor, fontSize: 18, fontWeight: FontWeight.bold)), if (card.bank.logoPath.isNotEmpty) Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Image.asset(card.bank.logoPath, width: 30, height: 30, fit: BoxFit.contain, errorBuilder: (c, e, s) => Icon(Icons.account_balance, color: card.bank.gradientColors.first)))]), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('الرصيد المتاح', style: TextStyle(color: card.bank.textColor.withOpacity(0.8), fontSize: 12)), Text('${card.balance.toStringAsFixed(2)} ${widget.appData.currency}', style: TextStyle(color: card.bank.textColor, fontSize: 28, fontWeight: FontWeight.w900))]), Text(card.cardIdentifier, style: TextStyle(color: card.bank.textColor.withOpacity(0.9), fontSize: 16, letterSpacing: 2))])]),
    );
  }
}

class SearchTransactionsScreen extends StatefulWidget {
  final AppData appData; const SearchTransactionsScreen({super.key, required this.appData});
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
    return Scaffold(appBar: AppBar(backgroundColor: isDark ? const Color(0xFF121212) : Colors.white, elevation: 0, iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black), title: TextField(autofocus: true, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: const InputDecoration(hintText: 'ابحث عن متجر، شخص، أو تصنيف...', hintStyle: TextStyle(color: Colors.grey, fontSize: 14), border: InputBorder.none), onChanged: (v) => setState(() => _query = v)), actions: [IconButton(icon: Icon(Icons.date_range_rounded, color: _startDate != null ? const Color(0xFF10B981) : Colors.grey), onPressed: () async { final res = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2030), builder: (ctx, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF10B981))), child: child!)); if (res != null) setState(() { _startDate = res.start; _endDate = res.end; }); }), if (_startDate != null) IconButton(icon: const Icon(Icons.clear, color: Colors.redAccent), onPressed: () => setState(() { _startDate = null; _endDate = null; }))]), body: filtered.isEmpty ? const Center(child: Text('لا توجد معاملات مطابقة للبحث', style: TextStyle(color: Colors.grey))) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: filtered.length, itemBuilder: (ctx, i) { final tx = filtered[i]['tx'] as TransactionItem; final card = filtered[i]['card'] as UserCardModel; return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tx.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), if (tx.subtitle != null && tx.subtitle!.isNotEmpty) ...[const SizedBox(height: 2), Text(tx.subtitle!, style: TextStyle(color: Colors.blueAccent.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500))], const SizedBox(height: 2), Text('${tx.category} • ${tx.date} • ${card.bank.name}', style: const TextStyle(color: Colors.grey, fontSize: 11))])), Text('${tx.isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)} ${widget.appData.currency}', style: TextStyle(color: tx.isIncome ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16))])); }));
  }
}

class ObligationsView extends StatefulWidget {
  final AppData appData; const ObligationsView({super.key, required this.appData});
  @override State<ObligationsView> createState() => ObligationsViewState();
}

class ObligationsViewState extends State<ObligationsView> {
  int _selectedTab = 0;

  void _showAddOptions() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.money_off_rounded, color: Color(0xFF10B981)), title: const Text('إضافة قسط جديد'), onTap: () { Navigator.pop(ctx); _showAddInstallmentSheet(); }), const Divider(),
      ListTile(leading: const Icon(Icons.autorenew_rounded, color: Colors.blue), title: const Text('إضافة اشتراك متكرر'), onTap: () { Navigator.pop(ctx); _showAddSubscriptionSheet(); }), const Divider(),
      ListTile(leading: const Icon(Icons.handshake_rounded, color: Colors.orange), title: const Text('إضافة دين أو سلفة'), onTap: () { Navigator.pop(ctx); _showAddDebtSheet(); }),
    ])));
  }

  void _showAddInstallmentSheet() {
    final titleCtrl = TextEditingController(); final provCtrl = TextEditingController(); final amtCtrl = TextEditingController(); final monthsCtrl = TextEditingController(); final dueDayCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24), child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'اسم السلعة/القسط', border: OutlineInputBorder())), const SizedBox(height: 12), TextField(controller: provCtrl, decoration: const InputDecoration(labelText: 'جهة التقسيط', border: OutlineInputBorder())), const SizedBox(height: 12), Row(children: [Expanded(child: TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'القسط الشهري', border: OutlineInputBorder()))), const SizedBox(width: 12), Expanded(child: TextField(controller: monthsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الشهور', border: OutlineInputBorder())))]), const SizedBox(height: 12), TextField(controller: dueDayCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'يوم الاستحقاق (1-31)', border: OutlineInputBorder())), const SizedBox(height: 20), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: () { final amt = double.tryParse(amtCtrl.text); final m = int.tryParse(monthsCtrl.text); final d = int.tryParse(dueDayCtrl.text) ?? 1; if (amt != null && m != null && titleCtrl.text.isNotEmpty) { widget.appData.addInstallment(titleCtrl.text, provCtrl.text.isEmpty ? 'جهة تقسيط' : provCtrl.text, amt, m, d); Navigator.pop(ctx); } }, child: const Text('حفظ', style: TextStyle(color: Colors.white))), const SizedBox(height: 20)])));
  }

  void _showAddSubscriptionSheet() {
    final titleCtrl = TextEditingController(); final amtCtrl = TextEditingController(); final dueDayCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24), child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'اسم الاشتراك', border: OutlineInputBorder())), const SizedBox(height: 12), TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ الشهري', border: OutlineInputBorder())), const SizedBox(height: 12), TextField(controller: dueDayCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'يوم التجديد', border: OutlineInputBorder())), const SizedBox(height: 20), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: () { final amt = double.tryParse(amtCtrl.text); final d = int.tryParse(dueDayCtrl.text) ?? 1; if (amt != null && titleCtrl.text.isNotEmpty) { widget.appData.addSubscription(titleCtrl.text, amt, d); Navigator.pop(ctx); } }, child: const Text('حفظ', style: TextStyle(color: Colors.white))), const SizedBox(height: 20)])));
  }

  void _showAddDebtSheet() {
    final titleCtrl = TextEditingController(); final personCtrl = TextEditingController(); final amtCtrl = TextEditingController(); bool isOwedToMe = true; DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (bCtx) => StatefulBuilder(builder: (c, setS) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(bCtx).viewInsets.bottom, top: 20, left: 20, right: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [ChoiceChip(label: const Text('فلوس لي (سلفته)'), selected: isOwedToMe, onSelected: (_) => setS(() => isOwedToMe = true), selectedColor: Colors.green.withOpacity(0.3)), const SizedBox(width: 8), ChoiceChip(label: const Text('فلوس علي (استلفت)'), selected: !isOwedToMe, onSelected: (_) => setS(() => isOwedToMe = false), selectedColor: Colors.redAccent.withOpacity(0.3))]), const SizedBox(height: 12),
      TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'سبب السلفة', border: OutlineInputBorder())), const SizedBox(height: 12),
      TextField(controller: personCtrl, decoration: const InputDecoration(labelText: 'اسم الشخص', border: OutlineInputBorder())), const SizedBox(height: 12),
      TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder())), const SizedBox(height: 12),
      Row(children: [const Text('تاريخ السداد: '), TextButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030)); if (d != null) setS(() => selectedDate = d); }, child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)))]), const SizedBox(height: 16),
      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: () { final a = double.tryParse(amtCtrl.text); if (a != null && a > 0 && titleCtrl.text.isNotEmpty) { widget.appData.addDebt(titleCtrl.text, personCtrl.text, a, isOwedToMe, DateFormat('dd/MM/yyyy').format(selectedDate)); Navigator.pop(bCtx); } }, child: const Text('حفظ', style: TextStyle(color: Colors.white))), const SizedBox(height: 20)
    ]))));
  }

  @override Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الالتزامات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))])),
      SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ChoiceChip(label: const Text('الأقساط'), selected: _selectedTab == 0, onSelected: (v) => setState(() => _selectedTab = 0), selectedColor: const Color(0xFF10B981).withOpacity(0.2)), const SizedBox(width: 8),
        ChoiceChip(label: const Text('الاشتراكات'), selected: _selectedTab == 1, onSelected: (v) => setState(() => _selectedTab = 1), selectedColor: const Color(0xFF10B981).withOpacity(0.2)), const SizedBox(width: 8),
        ChoiceChip(label: const Text('الديون والسلف'), selected: _selectedTab == 2, onSelected: (v) => setState(() => _selectedTab = 2), selectedColor: const Color(0xFF10B981).withOpacity(0.2)),
      ])),
      const SizedBox(height: 10),
      Expanded(
        child: _selectedTab == 0 
        ? (widget.appData.installments.isEmpty ? const EmptyStateWidget(icon: Icons.money_off_rounded, title: 'لا توجد أقساط', subtitle: 'أضف أقساطك لنتتبعها سوياً') : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: widget.appData.installments.length, itemBuilder: (ctx, i) {
            final inst = widget.appData.installments[i]; final isDone = inst.paidMonths >= inst.totalMonths;
            return Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(inst.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text('${inst.provider} • ${inst.monthlyAmount.toStringAsFixed(0)} ${widget.appData.currency}/شهر (يوم ${inst.dueDayOfMonth})', style: const TextStyle(color: Colors.grey, fontSize: 13))]), IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => widget.appData.deleteInstallment(inst.id))]), const SizedBox(height: 16), LinearProgressIndicator(value: inst.progress, minHeight: 8, backgroundColor: Colors.grey.withOpacity(0.2), valueColor: AlwaysStoppedAnimation(isDone ? Colors.green : const Color(0xFF10B981))), const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('تم سداد: ${inst.paidMonths} / ${inst.totalMonths} شهر', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), if (!isDone) ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: () => widget.appData.markInstallmentPaid(inst.id), child: const Text('دفع قسط', style: TextStyle(color: Colors.white, fontSize: 12))) else const Text('مكتمل', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))])]));
          }))
        : _selectedTab == 1 
        ? (widget.appData.subscriptions.isEmpty ? const EmptyStateWidget(icon: Icons.autorenew_rounded, title: 'لا توجد اشتراكات', subtitle: 'سجل اشتراكات الجيم والإنترنت هنا') : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: widget.appData.subscriptions.length, itemBuilder: (ctx, i) {
            final sub = widget.appData.subscriptions[i];
            return Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(sub.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 4), Text('${sub.amount.toStringAsFixed(0)} ${widget.appData.currency}/شهرياً', style: const TextStyle(color: Colors.grey, fontSize: 13))]), IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => widget.appData.deleteSubscription(sub.id))]));
          }))
        : (widget.appData.debts.isEmpty ? const EmptyStateWidget(icon: Icons.handshake_rounded, title: 'لا توجد ديون', subtitle: 'نظم أموالك المستدانة أو المقرضة هنا') : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: widget.appData.debts.length, itemBuilder: (ctx, i) {
            final d = widget.appData.debts[i];
            return Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: d.isOwedToMe ? Colors.green.withOpacity(0.5) : Colors.redAccent.withOpacity(0.5))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 4), Text('${d.personName} • يُسدد في ${d.dueDate}', style: const TextStyle(color: Colors.grey, fontSize: 13)), const SizedBox(height: 8), Text('${d.isOwedToMe ? 'لي' : 'علي'}: ${d.amount.toStringAsFixed(0)} ${widget.appData.currency}', style: TextStyle(color: d.isOwedToMe ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14))]), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), onPressed: () => widget.appData.deleteDebt(d.id), child: const Text('تم السداد', style: TextStyle(color: Colors.white, fontSize: 12)))]));
          }))
      )
    ]));
  }
}

class HistoricalAnalyticsScreen extends StatelessWidget {
  final AppData appData;
  const HistoricalAnalyticsScreen({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    final isDark = appData.isDarkMode;
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
          if (!tx.isIncome && tx.category != 'تحويل داخلي' && (tx.date.contains('/$monthStr') || tx.date.endsWith(monthStr))) {
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
                      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem('${rod.toY.toStringAsFixed(0)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          ],
        ),
      ),
    );
  }
}

class CategoryBudgetsView extends StatefulWidget {
  final AppData appData; const CategoryBudgetsView({super.key, required this.appData});
  @override State<CategoryBudgetsView> createState() => CategoryBudgetsViewState();
}

class CategoryBudgetsViewState extends State<CategoryBudgetsView> {
  void _showAddCategorySheet(BuildContext context) {
    final nameCtrl = TextEditingController(); final limitCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('إضافة تصنيف جديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 16), TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم التصنيف', border: OutlineInputBorder())), const SizedBox(height: 16), TextField(controller: limitCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الحد الأقصى (ج.م)', border: OutlineInputBorder())), const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.all(14)), onPressed: () { final newLimit = double.tryParse(limitCtrl.text); if (newLimit != null && newLimit >= 0 && nameCtrl.text.isNotEmpty) { widget.appData.setCategoryBudget(nameCtrl.text, newLimit); Navigator.pop(ctx); } }, child: const Text('حفظ التصنيف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))), const SizedBox(height: 20)])));
  }

  void _showEditBudgetSheet(BuildContext context, String category, double currentLimit) {
    final ctrl = TextEditingController(text: currentLimit.toStringAsFixed(0));
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('تعديل ميزانية: $category', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 16), TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الحد الأقصى الجديد', border: OutlineInputBorder())), const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.all(14)), onPressed: () { final newLimit = double.tryParse(ctrl.text); if (newLimit != null && newLimit >= 0) { widget.appData.setCategoryBudget(category, newLimit); Navigator.pop(ctx); } }, child: const Text('حفظ التعديل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))), const SizedBox(height: 8), SizedBox(width: double.infinity, child: TextButton(onPressed: () { widget.appData.deleteCategoryBudget(category); Navigator.pop(ctx); }, child: const Text('حذف هذا التصنيف', style: TextStyle(color: Colors.redAccent)))), const SizedBox(height: 20)])));
  }

  @override Widget build(BuildContext context) {
    List<PieChartSectionData> chartSections = [];
    final colors = [Colors.blue, Colors.redAccent, Colors.amber, Colors.green, Colors.purple, Colors.orange, Colors.teal, Colors.indigo];
    int colorIndex = 0;
    
    widget.appData.categoryBudgets.forEach((key, value) {
      final spent = widget.appData.getCategoryMonthlySpent(key);
      if (spent > 0) {
        chartSections.add(PieChartSectionData(color: colors[colorIndex % colors.length], value: spent, title: key, radius: 50, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)));
        colorIndex++;
      }
    });

    return SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(icon: const Icon(Icons.bar_chart_rounded, color: Colors.blueAccent, size: 30), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoricalAnalyticsScreen(appData: widget.appData)))),
        Text(AppStrings.get(widget.appData.language, 'budgets'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ])),
      if (chartSections.isNotEmpty) SizedBox(height: 180, child: PieChart(PieChartData(sections: chartSections, centerSpaceRadius: 40, sectionsSpace: 2))),
      if (chartSections.isNotEmpty) const SizedBox(height: 20),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), children: widget.appData.categoryBudgets.entries.map((e) {
        final spent = widget.appData.getCategoryMonthlySpent(e.key); final limit = e.value; final pct = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0; final isExceeded = spent > limit;
        return GestureDetector(
          onTap: () => _showEditBudgetSheet(context, e.key, limit),
          child: Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(20), border: isExceeded ? Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5) : null), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, color: isExceeded ? Colors.redAccent : const Color(0xFF10B981)))]), const SizedBox(height: 12), LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.grey.withOpacity(0.2), valueColor: AlwaysStoppedAnimation(isExceeded ? Colors.redAccent : const Color(0xFF10B981))), const SizedBox(height: 12), Text('الاستهلاك: ${spent.toStringAsFixed(0)} من أصل ${limit.toStringAsFixed(0)} ${widget.appData.currency}', style: const TextStyle(fontSize: 12, color: Colors.grey))])),
        );
      }).toList()))
    ]));
  }
}

class SavingsGoalsView extends StatefulWidget {
  final AppData appData; const SavingsGoalsView({super.key, required this.appData});
  @override State<SavingsGoalsView> createState() => SavingsGoalsViewState();
}

class SavingsGoalsViewState extends State<SavingsGoalsView> {
  void _showAddGoalSheet() {
    final titleCtrl = TextEditingController(); final targetCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('إنشاء هدف ادخار جديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
      TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'اسم الهدف (مثال: شراء هاتف)', border: OutlineInputBorder())), const SizedBox(height: 12),
      TextField(controller: targetCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المستهدف', border: OutlineInputBorder())), const SizedBox(height: 20),
      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: () { final t = double.tryParse(targetCtrl.text); if (t != null && t > 0 && titleCtrl.text.isNotEmpty) { widget.appData.addSavingsGoal(titleCtrl.text, t); Navigator.pop(ctx); } }, child: const Text('حفظ الهدف', style: TextStyle(color: Colors.white))), const SizedBox(height: 20)
    ])));
  }

  void _showDepositSheet(SavingsGoalModel goal) {
    final amtCtrl = TextEditingController();
    String sourceCardId = widget.appData.userCards.first.id;
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => StatefulBuilder(builder: (c, setS) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('إيداع في حصالة: ${goal.title}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
      DropdownButtonFormField<String>(value: sourceCardId, items: widget.appData.userCards.map((k) => DropdownMenuItem(value: k.id, child: Text('${k.bank.name} (${k.cardIdentifier})'))).toList(), onChanged: (v) => setS(() => sourceCardId = v!), decoration: const InputDecoration(labelText: 'خصم من حساب', border: OutlineInputBorder())), const SizedBox(height: 12),
      TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المراد إيداعه', border: OutlineInputBorder())), const SizedBox(height: 20),
      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: () { final a = double.tryParse(amtCtrl.text); if (a != null && a > 0) { widget.appData.depositToGoal(goal.id, a, sourceCardId); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الإيداع بنجاح'))); } }, child: const Text('تأكيد الإيداع', style: TextStyle(color: Colors.white))), const SizedBox(height: 20)
    ]))));
  }

  @override Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('التحويش', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))])),
      Expanded(
        child: widget.appData.savingsGoals.isEmpty 
        ? const EmptyStateWidget(icon: Icons.savings_rounded, title: 'لا توجد أهداف', subtitle: 'أضف هدفاً لتبدأ في بناء مدخراتك')
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: widget.appData.savingsGoals.length,
            itemBuilder: (ctx, i) {
              final goal = widget.appData.savingsGoals[i]; final isCompleted = goal.currentAmount >= goal.targetAmount;
              return Container(
                margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(goal.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 4), Text('تم توفير: ${goal.currentAmount.toStringAsFixed(0)} من ${goal.targetAmount.toStringAsFixed(0)} ${widget.appData.currency}', style: const TextStyle(color: Colors.grey, fontSize: 13))]),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => widget.appData.deleteSavingsGoal(goal.id))
                  ]),
                  const SizedBox(height: 16), LinearProgressIndicator(value: goal.progress, minHeight: 8, backgroundColor: Colors.grey.withOpacity(0.2), valueColor: AlwaysStoppedAnimation(isCompleted ? Colors.green : const Color(0xFF10B981))), const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${(goal.progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    if (!isCompleted) ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: () => _showDepositSheet(goal), child: const Text('إيداع', style: TextStyle(color: Colors.white, fontSize: 12))) else const Text('مكتمل بنجاح 🎉', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))
                  ])
                ]),
              );
            },
          ),
      )
    ]));
  }
}

class SettingsTabView extends StatefulWidget {
  final AppData appData; const SettingsTabView({super.key, required this.appData});
  @override State<SettingsTabView> createState() => _SettingsTabViewState();
}

class _SettingsTabViewState extends State<SettingsTabView> {
  void _showPdfExportOptions(BuildContext context) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('اختر الحساب لتصدير التقرير', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 16), ListTile(leading: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF10B981)), title: const Text('جميع الحسابات والمحافظ'), onTap: () { Navigator.pop(ctx); widget.appData.exportPdfReport(); }), const Divider(), ...widget.appData.userCards.map((card) => ListTile(leading: Icon(Icons.credit_card_rounded, color: card.bank.gradientColors.first), title: Text(card.bank.name), subtitle: Text(card.cardIdentifier), onTap: () { Navigator.pop(ctx); widget.appData.exportPdfReport(cardId: card.id); })).toList(), const SizedBox(height: 20)])));
  }

  void _showWipeDataConfirmation() {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('مسح جميع البيانات'), content: const Text('هل أنت متأكد؟ سيتم حذف جميع معاملاتك، ميزانياتك وأهدافك نهائياً ولن تتمكن من التراجع.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () async { await widget.appData.wipeAllData(); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصفير التطبيق بنجاح'))); }, child: const Text('تأكيد المسح', style: TextStyle(color: Colors.white)))]));
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(context: context, builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: ['EGP', '\$', '€', 'SAR', 'AED'].map((c) => ListTile(title: Text(c), onTap: () { widget.appData.setCurrency(c); Navigator.pop(ctx); })).toList()));
  }

  @override Widget build(BuildContext context) {
    final lang = widget.appData.language;
    return SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      Text(AppStrings.get(lang, 'settings'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
      ListTile(leading: const Icon(Icons.table_chart_rounded, color: Colors.green, size: 28), title: Text(AppStrings.get(lang, 'export_csv')), onTap: () => widget.appData.exportCsvReport()), const Divider(),
      ListTile(leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 28), title: Text(AppStrings.get(lang, 'export_pdf')), onTap: () => _showPdfExportOptions(context)), const Divider(),
      ListTile(leading: const Icon(Icons.lock_reset_rounded, color: Colors.amber, size: 28), title: const Text('نسخ احتياطي مشفر (Backup)'), subtitle: const Text('تصدير ملف بيانات آمن ومحمي'), onTap: () async { await widget.appData.exportSecureBackup(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ الاحتياطي بنجاح'))); }), const Divider(),
      ListTile(leading: const Icon(Icons.restore_rounded, color: Colors.teal, size: 28), title: const Text('استعادة البيانات (Restore)'), subtitle: const Text('استرجاع بياناتك من ملف النسخ الاحتياطي'), onTap: () async { await widget.appData.importSecureBackup(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الاستعادة بنجاح'))); }), const Divider(),
      ListTile(leading: const Icon(Icons.attach_money_rounded, color: Colors.purple, size: 28), title: const Text('العملة الافتراضية'), subtitle: Text(widget.appData.currency), onTap: _showCurrencyPicker), const Divider(),
      SwitchListTile(secondary: const Icon(Icons.language_rounded, color: Colors.blue, size: 28), title: const Text('English / العربية'), value: lang == 'en', onChanged: (_) => widget.appData.toggleLanguage()),
      SwitchListTile(secondary: const Icon(Icons.fingerprint_rounded, color: Color(0xFF10B981), size: 28), title: const Text('البصمة / Biometrics'), activeColor: const Color(0xFF10B981), value: widget.appData.isBiometricEnabled, onChanged: (v) => widget.appData.toggleBiometric(v)),
      SwitchListTile(secondary: const Icon(Icons.dark_mode_rounded, size: 28), title: const Text('الوضع الداكن / Dark Mode'), activeColor: const Color(0xFF10B981), value: widget.appData.isDarkMode, onChanged: (v) => widget.appData.toggleTheme()), const Divider(),
      ListTile(leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 28), title: const Text('مسح جميع البيانات', style: TextStyle(color: Colors.redAccent)), onTap: _showWipeDataConfirmation),
      const SizedBox(height: 40),
      Center(child: Text(lang == 'ar' ? 'صنع بكل حب مصطفى الماظ ❤️' : 'Made with love by Mostafa Almaz ❤️', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold))),
      const SizedBox(height: 20)
    ]));
  }
}
