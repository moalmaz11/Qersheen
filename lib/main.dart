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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(QersheenApp(prefs: prefs));
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
    id: j['id'], title: j['title'], provider: j['provider'] ?? 'عام',
    monthlyAmount: (j['monthlyAmount'] as num).toDouble(),
    totalMonths: j['totalMonths'] ?? 1, paidMonths: j['paidMonths'] ?? 0, dueDayOfMonth: j['dueDayOfMonth'] ?? 1,
  );
}

class AppData extends ChangeNotifier {
  final SharedPreferences prefs;
  bool isDarkMode;
  bool isBiometricEnabled;
  bool isAuthenticated = false;
  String language;
  List<UserCardModel> userCards = [];
  List<InstallmentModel> installments = [];
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

  void _checkInitialAuth() {
    if (!isBiometricEnabled) isAuthenticated = true;
  }

  // ================= طلب الصلاحيات الأساسية للرسائل =================
  Future<void> initializePermissions() async {
    if (!(await Permission.sms.isGranted)) {
      await Permission.sms.request();
    }
    // تحديث الأرصدة فور الموافقة على الصلاحية
    if (await Permission.sms.isGranted) {
      autoDetectChronological();
    }
  }
  // =======================================================

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
        localizedReason: language == 'ar' ? 'قم بتأكيد هويتك لفتح المحفظة' : 'Authenticate to open Wallet',
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

  void _loadAll() {
    final String? cardsJson = prefs.getString('cardsData_v27');
    if (cardsJson != null && cardsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(cardsJson);
      userCards = decoded.map((e) => UserCardModel.fromJson(e)).toList();
    } else {
      userCards = [
        UserCardModel(
          id: 'cash_wallet_main', bankId: 'cash',
          cardIdentifier: language == 'ar' ? 'محفظة النقود السائلة' : 'Cash Wallet', balance: 0.0, transactions: [],
        )
      ];
      saveCards();
    }

    final String? instJson = prefs.getString('installments_v27');
    if (instJson != null && instJson.isNotEmpty) {
      final List<dynamic> decInst = jsonDecode(instJson);
      installments = decInst.map((e) => InstallmentModel.fromJson(e)).toList();
    }

    final String? budJson = prefs.getString('catBudgets_v27');
    if (budJson != null && budJson.isNotEmpty) {
      final Map<String, dynamic> decBud = jsonDecode(budJson);
      categoryBudgets = decBud.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } else {
      categoryBudgets = {'فواتير ومشتريات': 3000.0, 'سوبرماركت': 4000.0, 'مواصلات': 1500.0, 'عام': 2000.0};
      saveCategoryBudgets();
    }

    final List<String>? fps = prefs.getStringList('processed_fps_v27');
    if (fps != null) processedMessageFingerprints = fps.toSet();
  }

  void saveCards() {
    prefs.setString('cardsData_v27', jsonEncode(userCards.map((c) => c.toJson()).toList()));
    prefs.setStringList('processed_fps_v27', processedMessageFingerprints.toList());
    notifyListeners();
  }

  void saveInstallments() {
    prefs.setString('installments_v27', jsonEncode(installments.map((i) => i.toJson()).toList()));
    notifyListeners();
  }

  void saveCategoryBudgets() {
    prefs.setString('catBudgets_v27', jsonEncode(categoryBudgets));
    notifyListeners();
  }

  void addInstallment(String title, String provider, double monthly, int months) {
    installments.add(InstallmentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title, provider: provider, monthlyAmount: monthly,
      totalMonths: months, paidMonths: 0, dueDayOfMonth: 1,
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

  void deleteInstallment(String id) {
    installments.removeWhere((i) => i.id == id);
    saveInstallments();
  }

  void setCategoryBudget(String category, double limit) {
    categoryBudgets[category] = limit;
    saveCategoryBudgets();
  }

  double getCategoryMonthlySpent(String category) {
    double total = 0.0;
    final monthStr = '/${DateTime.now().month}/${DateTime.now().year}';
    for (var card in userCards) {
      for (var tx in card.transactions) {
        if (!tx.isIncome && (tx.category == category || tx.date.contains(monthStr))) total += tx.amount;
      }
    }
    return total;
  }

  void addNewCard(BankEntity entity, {String? customId}) {
    if (userCards.any((c) => c.bankId == entity.id)) return;
    String idStr = entity.entityType == EntityType.wallet ? (customId ?? '010XXXXXXXX') : (customId ?? '•••• 0000');
    userCards.insert(0, UserCardModel(
      id: '${entity.id}_${DateTime.now().millisecondsSinceEpoch}',
      bankId: entity.id, cardIdentifier: idStr, balance: 0.0, transactions: [],
    ));
    saveCards();
  }

  void deleteCard(String cardId) {
    if (cardId == 'cash_wallet_main') return;
    userCards.removeWhere((c) => c.id == cardId);
    saveCards();
  }

  void editCardName(String cardId, String newName) {
    final card = userCards.firstWhere((c) => c.id == cardId);
    card.cardIdentifier = newName;
    saveCards();
  }

  void addManualCashTx({required String title, required double amount, required bool isIncome, required String category}) {
    final cashCard = userCards.firstWhere((c) => c.bankId == 'cash');
    if (isIncome) cashCard.balance += amount; else cashCard.balance -= amount;
    final timeStr = '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} • ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
    cashCard.transactions.insert(0, TransactionItem(
      name: title, subtitle: 'يدوي', date: timeStr, amount: amount, isIncome: isIncome, category: category, txFingerprint: 'cash_${DateTime.now().millisecondsSinceEpoch}',
    ));
    saveCards();
  }

  double getTotalBalance() {
    double total = 0.0;
    for (var c in userCards) total += c.balance;
    return total;
  }

  Future<void> exportCsvReport() async {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('\uFEFFاسم الحساب,اسم المعاملة,التصنيف,المبلغ,النوع,التاريخ');
    for (var card in userCards) {
      for (var tx in card.transactions) {
        final typeStr = tx.isIncome ? 'دخل' : 'مصروف';
        buffer.writeln('"${card.bank.name}","${tx.name}","${tx.category}",${tx.amount},"$typeStr","${tx.date}"');
      }
    }
    final file = File('${Directory.systemTemp.path}/qersheen_report.csv');
    await file.writeAsString(buffer.toString(), encoding: utf8);
    await Share.shareXFiles([XFile(file.path)], text: 'تقرير معاملات قرشين');
  }

  Future<void> exportPdfReport() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    double totalIn = 0.0, totalOut = 0.0;
    for (var c in userCards) {
      for (var t in c.transactions) {
        if (t.isIncome) totalIn += t.amount; else totalOut += t.amount;
      }
    }
    pdf.addPage(pw.Page(
      theme: pw.ThemeData.withFont(base: font),
      textDirection: pw.TextDirection.rtl,
      build: (pw.Context context) => pw.Column(children: [
        pw.Text('كشف حساب قرشين', style: const pw.TextStyle(fontSize: 24)),
        pw.SizedBox(height: 20),
        pw.Text('الدخل: $totalIn | المصروفات: $totalOut'),
        pw.SizedBox(height: 20),
        pw.Table.fromTextArray(
          headers: ['المعاملة', 'المبلغ', 'التاريخ'],
          data: userCards.expand((c) => c.transactions.take(20).map((t) => [t.name, '${t.isIncome ? '+' : '-'}${t.amount}', t.date])).toList(),
        ),
      ]),
    ));
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'qersheen_statement.pdf');
  }

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
    
    if (!userCards.any((c) => c.bankId == bank.id)) addNewCard(bank, customId: phone ?? (acc != null ? '•••• $acc' : null));
    final card = userCards.firstWhere((c) => c.bankId == bank.id);

    final balMatch = RegExp(r'(?:رصيد|balance).*?(\d+(?:\.\d{1,2})?)', caseSensitive: false).firstMatch(text);
    bool hasExplicitBalance = false;
    if (balMatch != null) {
      card.balance = double.tryParse(balMatch.group(1)!) ?? card.balance;
      hasExplicitBalance = true;
    }

    if (processedMessageFingerprints.contains(fingerprint)) return;

    bool isIncome = RegExp(r'(إيداع|استلام|وارد|تحويل من|received|credited|added)').hasMatch(text);
    bool isExpense = RegExp(r'(خصم|شراء|سداد|دفع|سحب|تحويل إلى|paid|debited|purchase)').hasMatch(text);
    
    if (!isIncome && !isExpense) return;

    String extractedName = 'معاملة مالية';
    final nameMatch = RegExp(r'(?:لـ|إلى|من|لدى|في|to|from)\s+([A-Za-z\u0621-\u064A0-9\s\.\-]{3,25})').firstMatch(text);
    if (nameMatch != null) {
      String rawName = nameMatch.group(1)!;
      rawName = rawName.replaceAll(RegExp(r'(محفظة|كاش|هو|عمليه|شراء|واكسب|رصيد|حساب|رقم|بمبلغ|بتاريخ)'), '');
      extractedName = rawName.trim();
      if (extractedName.isEmpty) extractedName = 'معاملة مالية';
    }

    String title = isIncome ? 'استلام من $extractedName' : 'دفع لـ $extractedName';
    String category = isIncome ? 'تحويلات' : 'فواتير ومشتريات';

    final amtMatch = RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:جنية|جنيه|EGP|LE)').firstMatch(text) ?? RegExp(r'(?:مبلغ|قيمة)\s*(\d+(?:\.\d{1,2})?)').firstMatch(text);
    
    if (amtMatch != null) {
      final amt = double.tryParse(amtMatch.group(1)!);
      if (amt != null && amt > 0) {
        if (!hasExplicitBalance) {
          if (isIncome) card.balance += amt; else card.balance -= amt;
        }
        final timeStr = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
        card.transactions.insert(0, TransactionItem(name: title, date: timeStr, amount: amt, isIncome: isIncome, category: category, txFingerprint: fingerprint));
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
      return const BankEntity(id: 'cash', name: 'النقود السائلة', type: 'محفظة', acronym: 'CASH', entityType: EntityType.wallet, network: PaymentNetwork.walletInternal, exactSenders: [], gradientColors: [Color(0xFF2C5364), Color(0xFF203A43), Color(0xFF0F2027)], textColor: Colors.white, cardTypeBadge: 'WALLET', logoPath: '');
    }
    return EgyptInstitutions.all.firstWhere((b) => b.id == bankId, orElse: () => EgyptInstitutions.all.first);
  }

  Map<String, dynamic> toJson() => {'id': id, 'bankId': bankId, 'cardIdentifier': cardIdentifier, 'balance': balance, 'transactions': transactions.map((t) => t.toJson()).toList()};
  factory UserCardModel.fromJson(Map<String, dynamic> j) => UserCardModel(id: j['id'], bankId: j['bankId'], cardIdentifier: j['cardIdentifier'], balance: (j['balance'] as num).toDouble(), transactions: (j['transactions'] as List).map((t) => TransactionItem.fromJson(t)).toList());
}

class TransactionItem {
  final String name, date, category;
  final String? subtitle, txFingerprint;
  final double amount;
  final bool isIncome;

  TransactionItem({required this.name, this.subtitle, required this.date, required this.amount, required this.isIncome, required this.category, this.txFingerprint});
  Map<String, dynamic> toJson() => {'name': name, 'date': date, 'amount': amount, 'isIncome': isIncome, 'category': category, 'txFingerprint': txFingerprint};
  factory TransactionItem.fromJson(Map<String, dynamic> j) => TransactionItem(name: j['name'], date: j['date'], amount: (j['amount'] as num).toDouble(), isIncome: j['isIncome'], category: j['category'] ?? 'عام', txFingerprint: j['txFingerprint']);
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
  final AppData appData;
  const AuthLockScreen({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint, size: 80, color: Color(0xFF10B981)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () => appData.authenticateUser(), 
              child: const Text('فتح المحفظة بالبصمة', style: TextStyle(color: Colors.white)),
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.appData.initializePermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [AppleWalletScreen(appData: widget.appData), InstallmentsView(appData: widget.appData), CategoryBudgetsView(appData: widget.appData), SettingsTabView(appData: widget.appData)];
    final isDark = widget.appData.isDarkMode;
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF10B981),
        unselectedItemColor: Colors.grey,
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'المحفظة'),
          BottomNavigationBarItem(icon: Icon(Icons.credit_score_rounded), label: 'الأقساط'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart_rounded), label: 'الميزانية'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'الإعدادات'),
        ],
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

  void _showCardOptions(UserCardModel card) {
    final ctrl = TextEditingController(text: card.cardIdentifier);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إعدادات الكارت', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'الاسم أو رقم الحساب', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.all(14)),
                onPressed: () { widget.appData.editCardName(card.id, ctrl.text); Navigator.pop(ctx); },
                child: const Text('حفظ التعديل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () { widget.appData.deleteCard(card.id); setState((){ _expandedIndex = null; }); Navigator.pop(ctx); },
                child: const Text('حذف هذا الكارت نهائياً', style: TextStyle(color: Colors.redAccent)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.appData.userCards;
    final isDark = widget.appData.isDarkMode;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المحفظة', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    Text('الإجمالي: ${widget.appData.getTotalBalance().toStringAsFixed(0)} EGP', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.sync_rounded, color: Colors.blueAccent, size: 28), 
                  onPressed: () {
                    widget.appData.autoDetectChronological();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم مزامنة رسائل الـ SMS بنجاح')));
                  }
                ),
              ],
            ),
          ),
          Expanded(
            child: _expandedIndex != null 
              ? _buildExpandedView(cards[_expandedIndex!], isDark)
              : _buildStackedView(cards),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedView(List<UserCardModel> cards) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: SizedBox(
        height: 220.0 + (cards.length - 1) * 70.0,
        child: Stack(
          clipBehavior: Clip.none,
          children: List.generate(cards.length, (i) {
            return Positioned(
              top: i * 70.0, left: 16, right: 16,
              child: GestureDetector(
                onTap: () => setState(() => _expandedIndex = i),
                onLongPress: () => _showCardOptions(cards[i]),
                child: _buildCardDesign(cards[i]),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildExpandedView(UserCardModel card, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () => setState(() => _expandedIndex = null),
            onLongPress: () => _showCardOptions(card),
            child: _buildCardDesign(card),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => setState(() => _expandedIndex = null),
          icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.grey),
          label: const Text('طي الكارت وعرض المحفظة', style: TextStyle(color: Colors.grey)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: card.transactions.length,
            itemBuilder: (ctx, idx) {
              final tx = card.transactions[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('${tx.category} • ${tx.date}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('${tx.isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)}', style: TextStyle(color: tx.isIncome ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCardDesign(UserCardModel card) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: card.bank.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: card.bank.gradientColors.last.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          if (card.bank.logoPath.isNotEmpty)
            Positioned(
              left: 0, top: 0,
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(card.bank.logoPath, width: 120, height: 120, fit: BoxFit.contain, errorBuilder: (c, e, s) => const SizedBox()),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(card.bank.name, style: TextStyle(color: card.bank.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  if (card.bank.logoPath.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Image.asset(card.bank.logoPath, width: 30, height: 30, fit: BoxFit.contain, errorBuilder: (c, e, s) => Icon(Icons.account_balance, color: card.bank.gradientColors.first)),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الرصيد المتاح', style: TextStyle(color: card.bank.textColor.withOpacity(0.8), fontSize: 12)),
                  Text('${card.balance.toStringAsFixed(2)} EGP', style: TextStyle(color: card.bank.textColor, fontSize: 28, fontWeight: FontWeight.w900)),
                ],
              ),
              Text(card.cardIdentifier, style: TextStyle(color: card.bank.textColor.withOpacity(0.9), fontSize: 16, letterSpacing: 2)),
            ],
          ),
        ],
      ),
    );
  }
}

class InstallmentsView extends StatefulWidget {
  final AppData appData;
  const InstallmentsView({super.key, required this.appData});
  @override
  State<InstallmentsView> createState() => _InstallmentsViewState();
}

class _InstallmentsViewState extends State<InstallmentsView> {
  void _showAddSheet() {
    final titleCtrl = TextEditingController();
    final provCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final monthsCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إضافة قسط جديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'اسم السلعة (مثال: موبايل)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: provCtrl, decoration: const InputDecoration(labelText: 'جهة التقسيط (مثال: فاليو، أمان)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'القسط الشهري', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: monthsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد الشهور', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.all(14)),
                onPressed: () {
                  final amt = double.tryParse(amtCtrl.text);
                  final m = int.tryParse(monthsCtrl.text);
                  if (amt != null && m != null && titleCtrl.text.isNotEmpty) {
                    widget.appData.addInstallment(titleCtrl.text, provCtrl.text.isEmpty ? 'جهة تقسيط' : provCtrl.text, amt, m);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('حفظ القسط', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    final isDark = widget.appData.isDarkMode;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الأقساط والمدفوعات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF10B981), size: 32), onPressed: _showAddSheet),
              ],
            ),
          ),
          Expanded(
            child: widget.appData.installments.isEmpty 
              ? const Center(child: Text('لا توجد أقساط مسجلة حالياً', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.appData.installments.length,
              itemBuilder: (ctx, i) {
                final inst = widget.appData.installments[i];
                final isDone = inst.paidMonths >= inst.totalMonths;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(inst.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              Text('${inst.provider} • ${inst.monthlyAmount.toStringAsFixed(0)} ج.م / شهر', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => widget.appData.deleteInstallment(inst.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: inst.progress,
                          minHeight: 8,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation(isDone ? Colors.green : const Color(0xFF10B981)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('تم سداد: ${inst.paidMonths} / ${inst.totalMonths} شهر', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          if (!isDone)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), minimumSize: const Size(0, 32)),
                              onPressed: () => widget.appData.markInstallmentPaid(inst.id),
                              child: const Text('دفع قسط', style: TextStyle(color: Colors.white, fontSize: 12)),
                            )
                          else
                            const Text('مكتمل', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
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
    );
  }
}

class CategoryBudgetsView extends StatelessWidget {
  final AppData appData;
  const CategoryBudgetsView({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    final isDark = appData.isDarkMode;
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Align(alignment: Alignment.centerRight, child: Text('الميزانية والاستهلاك', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: appData.categoryBudgets.entries.map((e) {
                final spent = appData.getCategoryMonthlySpent(e.key);
                final limit = e.value;
                final pct = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
                final isExceeded = spent > limit;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: isExceeded ? Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5) : null,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, color: isExceeded ? Colors.redAccent : const Color(0xFF10B981))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation(isExceeded ? Colors.redAccent : const Color(0xFF10B981)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('الاستهلاك: ${spent.toStringAsFixed(0)} من أصل ${limit.toStringAsFixed(0)} ج.م', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsTabView extends StatelessWidget {
  final AppData appData;
  const SettingsTabView({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('الإعدادات والتقارير', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.table_chart_rounded, color: Colors.green, size: 28),
            title: const Text('تصدير كشف حساب إكسيل CSV'),
            subtitle: const Text('حفظ نسخة كاملة من بياناتك لمعالجتها'),
            onTap: () => appData.exportCsvReport(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 28),
            title: const Text('تصدير تقرير PDF رسمي'),
            subtitle: const Text('ملف منسق جاهز للطباعة والمشاركة'),
            onTap: () => appData.exportPdfReport(),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint_rounded, color: Color(0xFF10B981), size: 28),
            title: const Text('قفل التطبيق بالبصمة'),
            subtitle: const Text('حماية بياناتك المالية عند فتح التطبيق'),
            activeColor: const Color(0xFF10B981),
            value: appData.isBiometricEnabled,
            onChanged: (v) => appData.toggleBiometric(v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_rounded, size: 28),
            title: const Text('الوضع الداكن'),
            activeColor: const Color(0xFF10B981),
            value: appData.isDarkMode,
            onChanged: (v) => appData.toggleTheme(),
          ),
        ],
      ),
    );
  }
}
