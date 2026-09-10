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
    final String? cardsJson = prefs.getString('cardsData_v24');
    if (cardsJson != null && cardsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(cardsJson);
      userCards = decoded.map((e) => UserCardModel.fromJson(e)).toList();
    } else {
      userCards = [
        UserCardModel(
          id: 'cash_wallet_main', bankId: 'cash',
          cardIdentifier: language == 'ar' ? 'محفظة كاش' : 'Cash Wallet', balance: 0.0, transactions: [],
        )
      ];
      saveCards();
    }

    final String? instJson = prefs.getString('installments_v24');
    if (instJson != null && instJson.isNotEmpty) {
      final List<dynamic> decInst = jsonDecode(instJson);
      installments = decInst.map((e) => InstallmentModel.fromJson(e)).toList();
    }

    final String? budJson = prefs.getString('catBudgets_v24');
    if (budJson != null && budJson.isNotEmpty) {
      final Map<String, dynamic> decBud = jsonDecode(budJson);
      categoryBudgets = decBud.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } else {
      categoryBudgets = {'فواتير ومشتريات': 3000.0, 'سوبرماركت': 4000.0, 'مواصلات': 1500.0, 'عام': 2000.0};
      saveCategoryBudgets();
    }

    final List<String>? fps = prefs.getStringList('processed_fps_v24');
    if (fps != null) processedMessageFingerprints = fps.toSet();
  }

  void saveCards() {
    prefs.setString('cardsData_v24', jsonEncode(userCards.map((c) => c.toJson()).toList()));
    prefs.setStringList('processed_fps_v24', processedMessageFingerprints.toList());
    notifyListeners();
  }

  void saveInstallments() {
    prefs.setString('installments_v24', jsonEncode(installments.map((i) => i.toJson()).toList()));
    notifyListeners();
  }

  void saveCategoryBudgets() {
    prefs.setString('catBudgets_v24', jsonEncode(categoryBudgets));
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
    final timeStr = '${DateTime.now().hour}:${DateTime.now().minute} • ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
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

  void _startNotificationListener() {
    try {
      NotificationListenerService.notificationsStream.listen((event) {
        final bank = EgyptInstitutions.matchSender(event.title ?? '');
        if (bank != null) _processMessage(bank, '${event.title} ${event.content}', DateTime.now(), null);
      });
    } catch (_) {}
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
    final nameMatch = RegExp(r'(?:لـ|إلى|من|لدى|في|to|from)\s+([A-Za-z\u0600-\u06FF\s]{3,20})').firstMatch(text);
    if (nameMatch != null) extractedName = nameMatch.group(1)!.trim();

    String title = isIncome ? 'استلام من $extractedName' : 'دفع لـ $extractedName';
    String category = isIncome ? 'تحويلات' : 'فواتير ومشتريات';

    final amtMatch = RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:جنية|جنيه|EGP|LE)').firstMatch(text) ?? RegExp(r'(?:مبلغ|بيمة)\s*(\d+(?:\.\d{1,2})?)').firstMatch(text);
    
    if (amtMatch != null) {
      final amt = double.tryParse(amtMatch.group(1)!);
      if (amt != null && amt > 0) {
        if (!hasExplicitBalance) {
          if (isIncome) card.balance += amt; else card.balance -= amt;
        }
        final timeStr = '${timestamp.hour}:${timestamp.minute} • ${timestamp.day}/${timestamp.month}/${timestamp.year}';
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
        theme: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFF2F4F7)),
        darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.black),
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
            ElevatedButton(onPressed: () => appData.authenticateUser(), child: const Text('فتح المحفظة بالبصمة')),
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
    final pages = [AppleWalletScreen(appData: widget.appData), InstallmentsView(appData: widget.appData), CategoryBudgetsView(appData: widget.appData), SettingsTabView(appData: widget.appData)];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF10B981),
        unselectedItemColor: Colors.grey,
        backgroundColor: widget.appData.isDarkMode ? const Color(0xFF121212) : Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'المحفظة'),
          BottomNavigationBarItem(icon: Icon(Icons.credit_score), label: 'الأقساط'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'الميزانية'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'الإعدادات'),
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
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('إعدادات الكارت', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'الاسم أو رقم الكارت')),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () { widget.appData.editCardName(card.id, ctrl.text); Navigator.pop(ctx); },
              child: const Text('حفظ التعديل'),
            ),
            const Divider(),
            TextButton(
              onPressed: () { widget.appData.deleteCard(card.id); Navigator.pop(ctx); },
              child: const Text('حذف هذا الكارت نهائياً', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.appData.userCards;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('إجمالي الرصيد: ${widget.appData.getTotalBalance().toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.sync, color: Colors.blue), onPressed: () => widget.appData.autoDetectChronological()),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                children: [
                  SizedBox(
                    height: _expandedIndex == null ? (220.0 + (cards.length - 1) * 68.0) : 240.0,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: List.generate(cards.length, (i) {
                        final top = _expandedIndex == null ? (i * 68.0) : (_expandedIndex == i ? 0.0 : 300.0);
                        return AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          top: top, left: 16, right: 16,
                          child: GestureDetector(
                            onTap: () => setState(() => _expandedIndex = _expandedIndex == i ? null : i),
                            onLongPress: () => _showCardOptions(cards[i]),
                            child: Container(
                              height: 220,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: cards[i].bank.gradientColors),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5))],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(cards[i].bank.name, style: TextStyle(color: cards[i].bank.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text('${cards[i].balance.toStringAsFixed(2)} EGP', style: TextStyle(color: cards[i].bank.textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                                  Text(cards[i].cardIdentifier, style: TextStyle(color: cards[i].bank.textColor, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  if (_expandedIndex != null)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cards[_expandedIndex!].transactions.length,
                      itemBuilder: (ctx, idx) {
                        final tx = cards[_expandedIndex!].transactions[idx];
                        return ListTile(
                          title: Text(tx.name), subtitle: Text(tx.date),
                          trailing: Text('${tx.isIncome ? '+' : '-'}${tx.amount}', style: TextStyle(color: tx.isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InstallmentsView extends StatelessWidget {
  final AppData appData;
  const InstallmentsView({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.all(20), child: Text('الأقساط الشهرية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          ElevatedButton(onPressed: () => appData.addInstallment('موبايل', 'فاليو', 500, 12), child: const Text('إضافة قسط تجريبي')),
          Expanded(
            child: ListView.builder(
              itemCount: appData.installments.length,
              itemBuilder: (ctx, i) {
                final inst = appData.installments[i];
                return ListTile(
                  title: Text(inst.title),
                  subtitle: Text('المدفوع: ${inst.paidMonths} من ${inst.totalMonths} شهور'),
                  trailing: IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => appData.markInstallmentPaid(inst.id)),
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
    return SafeArea(
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.all(20), child: Text('ميزانية التصنيفات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          Expanded(
            child: ListView(
              children: appData.categoryBudgets.entries.map((e) {
                final spent = appData.getCategoryMonthlySpent(e.key);
                return ListTile(
                  title: Text(e.key),
                  subtitle: LinearProgressIndicator(value: e.value > 0 ? spent / e.value : 0),
                  trailing: Text('${spent.toStringAsFixed(0)} / ${e.value.toStringAsFixed(0)}'),
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
          ListTile(leading: const Icon(Icons.table_chart, color: Colors.green), title: const Text('تصدير كشف حساب إكسيل CSV'), onTap: () => appData.exportCsvReport()),
          ListTile(leading: const Icon(Icons.picture_as_pdf, color: Colors.red), title: const Text('تصدير كشف حساب PDF'), onTap: () => appData.exportPdfReport()),
          SwitchListTile(title: const Text('قفل البصمة'), value: appData.isBiometricEnabled, onChanged: (v) => appData.toggleBiometric(v)),
        ],
      ),
    );
  }
}
