import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'ai_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await OnDeviceFinanceAI.initialize();
  runApp(QersheenApp(prefs: prefs));
}

enum EntityType { bank, wallet }

class BankEntity {
  final String id, name, type, acronym;
  final EntityType entityType;
  final List<String> exactSenders;
  final List<Color> gradientColors;
  final Color textColor, chipColor;
  final String? cardTypeBadge;
  final String logoAsset;

  const BankEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.acronym,
    required this.entityType,
    required this.exactSenders,
    required this.gradientColors,
    required this.textColor,
    required this.chipColor,
    required this.logoAsset,
    this.cardTypeBadge,
  });

  Widget buildLogo({double size = 38}) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.18),
        child: Image.asset(
          'assets/logos/$logoAsset',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            color: gradientColors.first,
            child: Center(
              child: Text(
                acronym.length > 4 ? acronym.substring(0, 4) : acronym,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EgyptInstitutions {
  static List<BankEntity> all = [
    BankEntity(
      id: 'nbe', name: 'البنك الأهلي المصري', type: 'National Bank of Egypt', acronym: 'NBE',
      entityType: EntityType.bank, cardTypeBadge: 'prepaid', exactSenders: ['nbe', 'ahli'],
      gradientColors: const [Color(0xFF133E2B), Color(0xFF1E5638), Color(0xFFB45309)],
      textColor: Colors.white, chipColor: const Color(0xFFD4AF37), logoAsset: 'nbe.png',
    ),
    BankEntity(
      id: 'misr', name: 'بنك مصر', type: 'BANQUE MISR', acronym: 'BM',
      entityType: EntityType.bank, cardTypeBadge: 'classic debit', exactSenders: ['banquemisr', 'bm'],
      gradientColors: const [Color(0xFF8C6527), Color(0xFFB38738), Color(0xFF5A3A0E)],
      textColor: Colors.white, chipColor: const Color(0xFFE5C158), logoAsset: 'misr.png',
    ),
    BankEntity(
      id: 'cib', name: 'البنك التجاري الدولي', type: 'Commercial International Bank', acronym: 'CIB',
      entityType: EntityType.bank, cardTypeBadge: 'titanium debit', exactSenders: ['cib', 'cibeg'],
      gradientColors: const [Color(0xFF0C1D36), Color(0xFF1B3D6B), Color(0xFF0A182B)],
      textColor: Colors.white, chipColor: const Color(0xFFD4AF37), logoAsset: 'cib.png',
    ),
    BankEntity(
      id: 'voda', name: 'فودافون كاش', type: 'Vodafone Cash Wallet', acronym: 'VF-CASH',
      entityType: EntityType.wallet, cardTypeBadge: 'smart wallet', exactSenders: ['vf-cash', 'vfcash', 'vodafone'],
      gradientColors: const [Color(0xFF4A0404), Color(0xFF990000), Color(0xFF2A0000)],
      textColor: Colors.white, chipColor: Colors.transparent, logoAsset: 'voda.png',
    ),
    BankEntity(
      id: 'orange', name: 'أورنج كاش', type: 'Orange Cash Wallet', acronym: 'ORANGE',
      entityType: EntityType.wallet, cardTypeBadge: 'e-wallet', exactSenders: ['orangecash', 'orange'],
      gradientColors: const [Color(0xFF431407), Color(0xFFC2410C), Color(0xFF240A03)],
      textColor: Colors.white, chipColor: Colors.transparent, logoAsset: 'orange.png',
    ),
    BankEntity(
      id: 'etisalat', name: 'إي آند كاش (اتصالات)', type: 'e& Cash Wallet', acronym: 'e& CASH',
      entityType: EntityType.wallet, cardTypeBadge: 'e-wallet', exactSenders: ['etisalatcash', 'e&cash'],
      gradientColors: const [Color(0xFF1E3A0F), Color(0xFF3F6212), Color(0xFF102008)],
      textColor: Colors.white, chipColor: Colors.transparent, logoAsset: 'etisalat.png',
    ),
    BankEntity(
      id: 'we', name: 'وي باي (WE Pay)', type: 'WE Pay Telecom Egypt', acronym: 'WE PAY',
      entityType: EntityType.wallet, cardTypeBadge: 'smart wallet', exactSenders: ['wepay', 'telecomegypt'],
      gradientColors: const [Color(0xFF2E1065), Color(0xFF581C87), Color(0xFF170836)],
      textColor: Colors.white, chipColor: Colors.transparent, logoAsset: 'we.png',
    ),
    BankEntity(
      id: 'fawry', name: 'محفظة فوري باي', type: 'Fawry Pay Wallet', acronym: 'FAWRY',
      entityType: EntityType.wallet, cardTypeBadge: 'digital wallet', exactSenders: ['fawry', 'myfawry'],
      gradientColors: const [Color(0xFF422006), Color(0xFF854D0E), Color(0xFF201003)],
      textColor: Colors.white, chipColor: Colors.transparent, logoAsset: 'fawry.png',
    ),
    BankEntity(
      id: 'qnb', name: 'بنك QNB الأهلي', type: 'Qatar National Bank Alahli', acronym: 'QNB',
      entityType: EntityType.bank, cardTypeBadge: 'platinum debit', exactSenders: ['qnb', 'qnbaa'],
      gradientColors: const [Color(0xFF2D0A1E), Color(0xFF581338), Color(0xFF1F0414)],
      textColor: Colors.white, chipColor: const Color(0xFFE5C158), logoAsset: 'qnb.png',
    ),
    BankEntity(
      id: 'caire', name: 'بنك القاهرة', type: 'Banque Du Caire', acronym: 'BDC',
      entityType: EntityType.bank, cardTypeBadge: 'gold debit', exactSenders: ['bdc', 'banqueducaire'],
      gradientColors: const [Color(0xFF431407), Color(0xFF7C2D12), Color(0xFF2A0802)],
      textColor: Colors.white, chipColor: const Color(0xFFD4AF37), logoAsset: 'bdc.png',
    ),
    BankEntity(
      id: 'alex', name: 'بنك الإسكندرية', type: 'AlexBank - Intesa Sanpaolo', acronym: 'ALEX',
      entityType: EntityType.bank, cardTypeBadge: 'classic', exactSenders: ['alexbank'],
      gradientColors: const [Color(0xFF022C22), Color(0xFF065F46), Color(0xFF021B14)],
      textColor: Colors.white, chipColor: const Color(0xFFD4AF37), logoAsset: 'alex.png',
    ),
  ];

  static BankEntity? matchSender(String sender) {
    final s = sender.toLowerCase().replaceAll('-', '').replaceAll(' ', '').trim();
    for (var bank in all) {
      for (var exact in bank.exactSenders) {
        final cleanExact = exact.toLowerCase().replaceAll('-', '').replaceAll(' ', '');
        if (s == cleanExact || s.contains(cleanExact)) return bank;
      }
    }
    return null;
  }
}

class AppData extends ChangeNotifier {
  final SharedPreferences prefs;
  bool isDarkMode;
  double dailyBudgetLimit;
  List<UserCardModel> userCards = [];

  AppData(this.prefs)
      : isDarkMode = prefs.getBool('isDark') ?? true,
        dailyBudgetLimit = prefs.getDouble('dailyLimit') ?? 600.0 {
    _loadCards();
    _startNotificationListener();
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    prefs.setBool('isDark', isDarkMode);
    notifyListeners();
  }

  void updateDailyLimit(double newLimit) {
    dailyBudgetLimit = newLimit;
    prefs.setDouble('dailyLimit', newLimit);
    notifyListeners();
  }

  void _loadCards() {
    final String? cardsJson = prefs.getString('cardsData_v10');
    if (cardsJson != null && cardsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(cardsJson);
      userCards = decoded.map((e) => UserCardModel.fromJson(e)).toList();
    } else {
      userCards = [];
    }
  }

  void _saveCards() {
    final String encoded = jsonEncode(userCards.map((c) => c.toJson()).toList());
    prefs.setString('cardsData_v10', encoded);
  }

  void addNewCard(BankEntity entity, {String? customIdentifier, double initialBalance = 0.0}) {
    if (userCards.any((c) => c.bankId == entity.id)) return;

    String displayId;
    if (entity.entityType == EntityType.wallet) {
      displayId = customIdentifier ?? '010XXXXXXXX';
    } else {
      displayId = customIdentifier ?? '•••• ${(1000 + (DateTime.now().microsecond % 9000))}';
    }

    final newCard = UserCardModel(
      id: entity.id + DateTime.now().millisecondsSinceEpoch.toString(),
      bankId: entity.id,
      cardIdentifier: displayId,
      balance: initialBalance,
      transactions: [],
    );
    userCards.insert(0, newCard);
    _saveCards();
    notifyListeners();
  }

  void setCardBalance(String cardId, double newBalance) {
    final idx = userCards.indexWhere((c) => c.id == cardId);
    if (idx != -1) {
      userCards[idx].balance = newBalance;
      _saveCards();
      notifyListeners();
    }
  }

  void addTransaction(String cardId, TransactionItem tx) {
    final idx = userCards.indexWhere((c) => c.id == cardId);
    if (idx != -1) {
      userCards[idx].transactions.insert(0, tx);
      _saveCards();
      notifyListeners();
    }
  }

  void deleteTransaction(String cardId, TransactionItem item) {
    final idx = userCards.indexWhere((c) => c.id == cardId);
    if (idx != -1) {
      userCards[idx].transactions.remove(item);
      _saveCards();
      notifyListeners();
    }
  }

  void clearAll() {
    userCards.clear();
    _saveCards();
    notifyListeners();
  }

  void _startNotificationListener() {
    try {
      NotificationListenerService.notificationsStream.listen((event) {
        final title = event.title ?? '';
        final content = event.content ?? '';
        final fullText = '$title $content';

        final matchedBank = EgyptInstitutions.matchSender(title);
        if (matchedBank != null) {
          _processWithAI(matchedBank, fullText, DateTime.now());
        }
      });
    } catch (_) {}
  }

  void _processWithAI(BankEntity matchedBank, String body, DateTime date) {
    final res = OnDeviceFinanceAI.analyzeContext(body, isWallet: matchedBank.entityType == EntityType.wallet);

    if (!userCards.any((c) => c.bankId == matchedBank.id)) {
      addNewCard(matchedBank, customIdentifier: res.userIdentifier);
    }

    final card = userCards.firstWhere((c) => c.bankId == matchedBank.id);

    if (res.userIdentifier != null) {
      if (matchedBank.entityType == EntityType.wallet && card.cardIdentifier.contains('X')) {
        card.cardIdentifier = res.userIdentifier!;
        _saveCards();
      } else if (matchedBank.entityType == EntityType.bank && card.cardIdentifier.startsWith('•••• 0')) {
        card.cardIdentifier = res.userIdentifier!;
        _saveCards();
      }
    }

    if (res.actualBalance != null) {
      setCardBalance(card.id, res.actualBalance!);
    }

    if (res.intent == AITransactionIntent.balanceInquiryOnly || res.transactionAmount == null || res.transactionAmount! <= 0) {
      return;
    }

    final txTime = res.matchedTimestamp ?? date.toIso8601String();

    final isDup = card.transactions.any((t) => t.amount == res.transactionAmount && t.name == res.primaryTitle);
    if (!isDup) {
      addTransaction(
        card.id,
        TransactionItem(
          name: res.primaryTitle,
          subtitle: res.partyDetail,
          date: txTime,
          amount: res.transactionAmount!,
          isIncome: res.isIncome,
          category: _categoryFromIntent(res.intent),
          intent: res.intent,
        ),
      );
    }
  }

  String _categoryFromIntent(AITransactionIntent intent) {
    switch (intent) {
      case AITransactionIntent.atmWithdrawal: return 'سحب كاش';
      case AITransactionIntent.merchantPurchase: return 'مشتريات وفواتير';
      case AITransactionIntent.p2pTransferOut:
      case AITransactionIntent.p2pTransferIn: return 'تحويلات';
      case AITransactionIntent.bankDeposit: return 'إيداع وراتب';
      default: return 'عام';
    }
  }

  Future<int> autoDetectBanksAndSms() async {
    int detected = 0;
    try {
      var status = await Permission.sms.request();
      if (!status.isGranted) return -1;
      SmsQuery query = SmsQuery();
      List<SmsMessage> messages = await query.querySms(kinds: [SmsQueryKind.inbox]);

      for (var msg in messages) {
        final sender = msg.address ?? '';
        final body = msg.body ?? '';

        final matchedBank = EgyptInstitutions.matchSender(sender);
        if (matchedBank != null) {
          _processWithAI(matchedBank, body, msg.date ?? DateTime.now());
          detected++;
        }
      }
    } catch (_) {}
    return detected;
  }

  double getTodayExpenses() {
    double total = 0;
    final today = DateTime.now();
    for (var card in userCards) {
      for (var tx in card.transactions) {
        if (!tx.isIncome) {
          try {
            final d = DateTime.parse(tx.date);
            if (d.year == today.year && d.month == today.month && d.day == today.day) {
              total += tx.amount;
            }
          } catch (_) {}
        }
      }
    }
    return total;
  }
}

class UserCardModel {
  final String id, bankId;
  String cardIdentifier;
  double balance;
  final List<TransactionItem> transactions;

  UserCardModel({required this.id, required this.bankId, required this.cardIdentifier, required this.balance, required this.transactions});

  BankEntity get bank => EgyptInstitutions.all.firstWhere((b) => b.id == bankId, orElse: () => EgyptInstitutions.all.first);

  Map<String, dynamic> toJson() => {
    'id': id, 'bankId': bankId, 'cardIdentifier': cardIdentifier, 'balance': balance,
    'transactions': transactions.map((t) => t.toJson()).toList(),
  };

  factory UserCardModel.fromJson(Map<String, dynamic> json) => UserCardModel(
    id: json['id'], bankId: json['bankId'], cardIdentifier: json['cardIdentifier'] ?? '•••• 0000', balance: (json['balance'] as num).toDouble(),
    transactions: (json['transactions'] as List).map((t) => TransactionItem.fromJson(t)).toList(),
  );
}

class TransactionItem {
  final String name;
  final String? subtitle;
  final String date, category;
  final double amount;
  final bool isIncome;
  final AITransactionIntent intent;

  TransactionItem({
    required this.name, this.subtitle, required this.date, required this.amount, required this.isIncome, required this.category,
    this.intent = AITransactionIntent.unknown,
  });

  Map<String, dynamic> toJson() => {
    'name': name, 'subtitle': subtitle, 'date': date, 'amount': amount, 'isIncome': isIncome, 'category': category, 'intent': intent.index,
  };

  factory TransactionItem.fromJson(Map<String, dynamic> json) => TransactionItem(
    name: json['name'], subtitle: json['subtitle'], date: json['date'], amount: (json['amount'] as num).toDouble(), isIncome: json['isIncome'],
    category: json['category'] ?? 'عام', intent: AITransactionIntent.values[(json['intent'] ?? AITransactionIntent.unknown.index)],
  );
}

class QersheenApp extends StatelessWidget {
  final SharedPreferences prefs;
  const QersheenApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData(prefs),
      builder: (context, _) {
        final appData = AppData(prefs);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'قرشين',
          themeMode: appData.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFF2F4F7), fontFamily: 'sans-serif'),
          darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.black, fontFamily: 'sans-serif'),
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          home: MainNavigatorScreen(appData: appData),
        );
      },
    );
  }
}

class MainNavigatorScreen extends StatefulWidget {
  final AppData appData;
  const MainNavigatorScreen({super.key, required this.appData});

  @override
  State<MainNavigatorScreen> createState() => _MainNavigatorScreenState();
}

class _MainNavigatorScreenState extends State<MainNavigatorScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.appData.isDarkMode;
    final pages = [
      AppleWalletTab(appData: widget.appData),
      AnalyticsTab(appData: widget.appData),
      BudgetTab(appData: widget.appData),
      SettingsTab(appData: widget.appData)
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF121212) : Colors.white, border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.wallet_rounded, 'المحفظة', isDark),
            _buildNavItem(1, Icons.pie_chart_outline_rounded, 'التحليلات', isDark),
            _buildNavItem(2, Icons.track_changes_rounded, 'الميزانية', isDark),
            _buildNavItem(3, Icons.tune_rounded, 'الإعدادات', isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF10B981) : Colors.grey;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class AppleWalletTab extends StatefulWidget {
  final AppData appData;
  const AppleWalletTab({super.key, required this.appData});
  @override
  State<AppleWalletTab> createState() => _AppleWalletTabState();
}

class _AppleWalletTabState extends State<AppleWalletTab> {
  int? _expandedIndex;

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(margin: const EdgeInsets.all(12), width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إضافة حساب إلى المحفظة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('${EgyptInstitutions.all.length} متاح', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: EgyptInstitutions.all.length,
                itemBuilder: (ctx, idx) {
                  final entity = EgyptInstitutions.all[idx];
                  final added = widget.appData.userCards.any((c) => c.bankId == entity.id);
                  return ListTile(
                    leading: entity.buildLogo(),
                    title: Text(entity.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(entity.type, style: const TextStyle(fontSize: 11)),
                    trailing: added ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
                    onTap: added ? null : () {
                      if (entity.entityType == EntityType.wallet) {
                        Navigator.pop(ctx);
                        _askPhoneDialog(entity);
                      } else {
                        widget.appData.addNewCard(entity);
                        Navigator.pop(ctx);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _askPhoneDialog(BankEntity entity) {
    final phoneCtrl = TextEditingController(text: '010');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text('رقم محفظة ${entity.name}'),
        content: TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, maxLength: 11, decoration: const InputDecoration(labelText: 'رقم الموبايل', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () {
              widget.appData.addNewCard(entity, customIdentifier: phoneCtrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('إضافة', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _getTransactionIcon(AITransactionIntent intent, bool isIncome) {
    IconData icon;
    Color bg;
    Color fg;

    switch (intent) {
      case AITransactionIntent.atmWithdrawal:
        icon = Icons.local_atm_rounded;
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amber.shade700;
        break;
      case AITransactionIntent.merchantPurchase:
        icon = Icons.shopping_bag_rounded;
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = Colors.blueAccent;
        break;
      case AITransactionIntent.p2pTransferOut:
      case AITransactionIntent.p2pTransferIn:
        icon = isIncome ? Icons.call_received_rounded : Icons.call_made_rounded;
        bg = (isIncome ? Colors.green : Colors.purple).withValues(alpha: 0.15);
        fg = isIncome ? Colors.green : Colors.purpleAccent;
        break;
      case AITransactionIntent.bankDeposit:
        icon = Icons.savings_rounded;
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green;
        break;
      default:
        icon = isIncome ? Icons.south_west_rounded : Icons.north_east_rounded;
        bg = (isIncome ? Colors.green : Colors.red).withValues(alpha: 0.15);
        fg = isIncome ? Colors.green : Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: fg, size: 20),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المحفظة', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.sync_rounded, color: Colors.blueAccent, size: 26),
                      tooltip: 'فحص الرسائل بمحرك الذكاء الاصطناعي',
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المحرك المحلي يحلل الرسائل سياقياً...')));
                        await widget.appData.autoDetectBanksAndSms();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحليل وتحديث الأرصدة')));
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Color(0xFF10B981), size: 30),
                      onPressed: _openAddSheet,
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: cards.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 70, color: Colors.grey.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text('اضغط على علامة التزامن لتشغيل الذكاء الاصطناعي المحلي', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('إضافة بطاقة يدوياً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: _openAddSheet,
                        )
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildAppleWalletStack(cards),
                        ),

                        if (_expandedIndex != null && _expandedIndex! < cards.length) ...[
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                  icon: const Icon(Icons.close_fullscreen_rounded, size: 16),
                                  onPressed: () => setState(() => _expandedIndex = null),
                                  label: const Text('طي الكارت'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildCardTransactions(cards[_expandedIndex!], isDark),
                        ]
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleWalletStack(List<UserCardModel> cards) {
    const double cardHeight = 210.0;
    const double headerPeek = 65.0;

    double totalHeight;
    if (_expandedIndex == null) {
      totalHeight = cardHeight + ((cards.length - 1) * headerPeek);
    } else {
      totalHeight = cardHeight + 30;
    }

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(cards.length, (index) {
          final card = cards[index];
          final bool isSelected = _expandedIndex == index;

          double topPosition;
          double opacity = 1.0;

          if (_expandedIndex == null) {
            topPosition = index * headerPeek;
          } else {
            if (isSelected) {
              topPosition = 0;
            } else {
              topPosition = cardHeight + 20;
              opacity = 0.0;
            }
          }

          return AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            top: topPosition,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: opacity,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (_expandedIndex == index) {
                      _expandedIndex = null;
                    } else {
                      _expandedIndex = index;
                    }
                  });
                },
                child: _buildRealisticCard(card, isSelected),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRealisticCard(UserCardModel card, bool isExpanded) {
    final bank = card.bank;
    final isWallet = bank.entityType == EntityType.wallet;

    return Container(
      height: 210,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: bank.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8))],
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bank.cardTypeBadge ?? (isWallet ? 'smart wallet' : 'card'),
                style: TextStyle(color: bank.textColor.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(bank.name, style: TextStyle(color: bank.textColor, fontWeight: FontWeight.w900, fontSize: 15)),
                      Text(bank.type, style: TextStyle(color: bank.textColor.withValues(alpha: 0.7), fontSize: 9.5)),
                    ],
                  ),
                  const SizedBox(width: 10),
                  bank.buildLogo(size: 38),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (!isWallet) ...[
                Container(
                  width: 44, height: 32,
                  decoration: BoxDecoration(color: bank.chipColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black26)),
                  child: Center(child: Container(width: 28, height: 18, decoration: BoxDecoration(border: Border.all(color: Colors.black38, width: 0.8), borderRadius: BorderRadius.circular(3)))),
                ),
                const SizedBox(width: 12),
                Transform.rotate(angle: 1.5708, child: Icon(Icons.wifi, size: 20, color: bank.textColor.withValues(alpha: 0.6))),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [Icon(Icons.phone_android_rounded, size: 16, color: Colors.white70), SizedBox(width: 4), Text('محفظة هاتف', style: TextStyle(color: Colors.white70, fontSize: 11))]),
                )
              ],
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('الرصيد المتاح', style: TextStyle(color: bank.textColor.withValues(alpha: 0.7), fontSize: 10)),
                  Text(
                    '${card.balance.toStringAsFixed(2)} ج.م',
                    style: TextStyle(color: bank.textColor, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                card.cardIdentifier,
                style: TextStyle(color: bank.textColor.withValues(alpha: 0.95), fontSize: isWallet ? 18 : 15, fontWeight: FontWeight.bold, letterSpacing: isWallet ? 1.5 : 2),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
                child: Text(bank.acronym, style: TextStyle(color: bank.textColor.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardTransactions(UserCardModel card, bool isDark) {
    if (card.transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('لا توجد معاملات مسجلة على هذا الحساب حتى الآن', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: card.transactions.length,
      itemBuilder: (ctx, i) {
        final tx = card.transactions[i];
        return Dismissible(
          key: Key(tx.date + tx.name + i.toString()),
          direction: DismissDirection.endToStart,
          background: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
          onDismissed: (_) => widget.appData.deleteTransaction(card.id, tx),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _getTransactionIcon(tx.intent, tx.isIncome),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (tx.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(tx.subtitle!, style: const TextStyle(color: Colors.blueAccent, fontSize: 11)),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          '${tx.category} • ${tx.date}',
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '${tx.isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)} ج.م',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: tx.isIncome ? Colors.green : Colors.redAccent),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AnalyticsTab extends StatelessWidget {
  final AppData appData;
  const AnalyticsTab({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    Map<String, double> expenses = {};
    for (var card in appData.userCards) {
      for (var tx in card.transactions) {
        if (!tx.isIncome) expenses[tx.category] = (expenses[tx.category] ?? 0) + tx.amount;
      }
    }
    final colors = [Colors.redAccent, Colors.blueAccent, Colors.amber, Colors.purpleAccent, Colors.teal];
    int cIdx = 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تحليل المصروفات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            if (expenses.isEmpty)
              const Center(child: Text('لا توجد مصروفات مسجلة'))
            else ...[
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2, centerSpaceRadius: 50,
                    sections: expenses.entries.map((e) {
                      final c = colors[cIdx++ % colors.length];
                      return PieChartSectionData(color: c, value: e.value, title: e.key, radius: 50, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12));
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Expanded(
                child: ListView(
                  children: expenses.entries.map((e) => ListTile(
                    title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text('${e.value.toStringAsFixed(0)} ج.م', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                  )).toList(),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

class BudgetTab extends StatefulWidget {
  final AppData appData;
  const BudgetTab({super.key, required this.appData});
  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  late TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.appData.dailyBudgetLimit.toStringAsFixed(0));
  }

  @override
  Widget build(BuildContext context) {
    final spent = widget.appData.getTodayExpenses();
    final limit = widget.appData.dailyBudgetLimit;
    final double pct = (spent / limit).clamp(0.0, 1.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الميزانية اليومية', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('مصروفات اليوم', style: TextStyle(color: Colors.grey)),
                    Text('${spent.toStringAsFixed(0)} / ${limit.toStringAsFixed(0)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                  const SizedBox(height: 15),
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: pct, minHeight: 12, backgroundColor: Colors.grey.withValues(alpha: 0.2), valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)))),
                ],
              ),
            ),
            const SizedBox(height: 30),
            TextField(controller: _ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سقف الصرف اليومي (ج.م)', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.all(14)),
                onPressed: () {
                  final val = double.tryParse(_ctrl.text) ?? limit;
                  widget.appData.updateDailyLimit(val);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
                },
                child: const Text('حفظ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class SettingsTab extends StatelessWidget {
  final AppData appData;
  const SettingsTab({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('الإعدادات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ListTile(
            title: const Text('المظهر الداكن'),
            trailing: Switch(value: appData.isDarkMode, onChanged: (_) => appData.toggleTheme(), activeColor: const Color(0xFF10B981)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_active_rounded, color: Colors.blueAccent),
            title: const Text('تفعيل الاستماع للإشعارات لحظياً'),
            subtitle: const Text('تحليل الإشعارات محلياً فور وصولها بالذكاء الاصطناعي'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () async {
              final status = await NotificationListenerService.isPermissionGranted();
              if (!status) {
                await NotificationListenerService.requestPermission();
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('صلاحية الوصول للإشعارات مفعلة بالفعل')));
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('تصفير كل البطاقات والبيانات القديمة'),
            leading: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
            onTap: () {
              appData.clearAll();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم مسح البيانات لتطبيق التحليل الذكي')));
            },
          ),
        ],
      ),
    );
  }
}
