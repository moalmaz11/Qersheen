import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(QersheenApp(prefs: prefs));
}

// === إدارة حالة التطبيق والبيانات ===
class AppData extends ChangeNotifier {
  final SharedPreferences prefs;
  bool isDarkMode;
  double dailyBudgetLimit;
  
  List<UserCardModel> userCards = [];

  AppData(this.prefs) 
      : isDarkMode = prefs.getBool('isDark') ?? true,
        dailyBudgetLimit = prefs.getDouble('dailyLimit') ?? 620.0 {
    _loadCards();
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
    final String? cardsJson = prefs.getString('cardsData');
    if (cardsJson != null) {
      final List<dynamic> decoded = jsonDecode(cardsJson);
      userCards = decoded.map((e) => UserCardModel.fromJson(e)).toList();
    } else {
      // البيانات الافتراضية لأول مرة
      userCards = [
        UserCardModel(
          id: 'cib', name: 'البنك التجاري الدولي', acronym: 'CIB', 
          balance: 48250.0, 
          primaryColor: 0xFF0B1A30, secondaryColor: 0xFF0369A1, badgeBg: 0xFF38BDF8,
          transactions: [TransactionItem(name: 'رصيد افتتاحي', date: 'الآن', amount: 48250.0, isIncome: true)],
        ),
        UserCardModel(
          id: 'nbe', name: 'البنك الأهلي المصري', acronym: 'NBE', 
          balance: 18500.0, 
          primaryColor: 0xFF072B19, secondaryColor: 0xFF0E5431, badgeBg: 0xFFEAB308,
          transactions: [TransactionItem(name: 'رصيد افتتاحي', date: 'الآن', amount: 18500.0, isIncome: true)],
        ),
        UserCardModel(
          id: 'voda', name: 'فودافون كاش', acronym: 'VODA', 
          balance: 2450.0, 
          primaryColor: 0xFF3D0714, secondaryColor: 0xFF991B1B, badgeBg: 0xFFEF4444,
          transactions: [TransactionItem(name: 'رصيد افتتاحي', date: 'الآن', amount: 2450.0, isIncome: true)],
        ),
      ];
      _saveCards();
    }
  }

  void _saveCards() {
    final String encoded = jsonEncode(userCards.map((c) => c.toJson()).toList());
    prefs.setString('cardsData', encoded);
  }

  void addTransaction(String cardId, String name, double amount, bool isIncome) {
    final cardIndex = userCards.indexWhere((c) => c.id == cardId);
    if (cardIndex != -1) {
      final card = userCards[cardIndex];
      card.balance += isIncome ? amount : -amount;
      card.transactions.insert(0, TransactionItem(name: name, date: 'اليوم', amount: amount, isIncome: isIncome));
      _saveCards();
      notifyListeners();
    }
  }

  // محرك قراءة الرسائل (SMS Parser الأساسي)
  Future<void> scanSmsInbox() async {
    var permission = await Permission.sms.request();
    if (permission.isGranted) {
      SmsQuery query = SmsQuery();
      List<SmsMessage> messages = await query.querySms(kinds: [SmsQueryKind.inbox]);
      // هنا يتم بناء خوارزمية استخراج الأرقام من رسائل NBE و VF-Cash
      // يتم طباعة العدد كمثال للتأكد من عمل الصلاحية
      debugPrint("تم قراءة ${messages.length} رسالة بنجاح");
    }
  }
}

// === النماذج (Models) ===
class UserCardModel {
  final String id, name, acronym;
  double balance;
  final int primaryColor, secondaryColor, badgeBg;
  final List<TransactionItem> transactions;

  UserCardModel({required this.id, required this.name, required this.acronym, required this.balance, required this.primaryColor, required this.secondaryColor, required this.badgeBg, required this.transactions});

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'acronym': acronym, 'balance': balance,
    'primaryColor': primaryColor, 'secondaryColor': secondaryColor, 'badgeBg': badgeBg,
    'transactions': transactions.map((t) => t.toJson()).toList(),
  };

  factory UserCardModel.fromJson(Map<String, dynamic> json) => UserCardModel(
    id: json['id'], name: json['name'], acronym: json['acronym'], balance: json['balance'],
    primaryColor: json['primaryColor'], secondaryColor: json['secondaryColor'], badgeBg: json['badgeBg'],
    transactions: (json['transactions'] as List).map((t) => TransactionItem.fromJson(t)).toList(),
  );
}

class TransactionItem {
  final String name, date;
  final double amount;
  final bool isIncome;
  TransactionItem({required this.name, required this.date, required this.amount, required this.isIncome});

  Map<String, dynamic> toJson() => {'name': name, 'date': date, 'amount': amount, 'isIncome': isIncome};
  factory TransactionItem.fromJson(Map<String, dynamic> json) => TransactionItem(name: json['name'], date: json['date'], amount: json['amount'], isIncome: json['isIncome']);
}

// === واجهة التطبيق الرئيسية ===
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
          theme: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFEEF3F8), fontFamily: 'sans-serif'),
          darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF050811), fontFamily: 'sans-serif'),
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
    
    final List<Widget> pages = [
      WalletTab(appData: widget.appData),
      AnalyticsTab(appData: widget.appData),
      BudgetTab(appData: widget.appData),
      SettingsTab(appData: widget.appData),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D121E) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.wallet_rounded, 'المحفظة', isDark),
            _buildNavItem(1, Icons.show_chart_rounded, 'التحليلات', isDark),
            _buildNavItem(2, Icons.pie_chart_outline_rounded, 'الميزانية', isDark),
            _buildNavItem(3, Icons.tune_rounded, 'الإعدادات', isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF10B981) : (isDark ? const Color(0xFF64748B) : Colors.grey);
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// === 1. صفحة المحفظة ===
class WalletTab extends StatefulWidget {
  final AppData appData;
  const WalletTab({super.key, required this.appData});

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  List<int> _stackOrder = [];

  @override
  void initState() {
    super.initState();
    _stackOrder = List.generate(widget.appData.userCards.length, (i) => i);
    widget.appData.addListener(_updateState);
  }

  @override
  void dispose() {
    widget.appData.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() => setState(() {});

  void _bringCardToFront(int cardIndex) {
    final currentPos = _stackOrder.indexOf(cardIndex);
    if (currentPos == 0) return;
    setState(() {
      _stackOrder.removeAt(currentPos);
      _stackOrder.insert(0, cardIndex);
    });
  }

  void _showAddTransactionDialog(BuildContext context, bool isIncome) {
    final activeCard = widget.appData.userCards[_stackOrder[0]];
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.appData.isDarkMode ? const Color(0xFF121A2B) : Colors.white,
        title: Text(isIncome ? 'إضافة رصيد' : 'تسجيل مصروف', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الكارت المحدد: ${activeCard.name}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'الوصف (مثال: راتب، بقالة)')),
            TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ (ج.م)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isIncome ? Colors.green : Colors.red),
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount > 0 && titleController.text.isNotEmpty) {
                widget.appData.addTransaction(activeCard.id, titleController.text, amount, isIncome);
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
    final isDark = widget.appData.isDarkMode;
    final activeCard = widget.appData.userCards[_stackOrder[0]];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06B6D4)]),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.black, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('قرشين', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
                        Text('المحفظة الذكية', style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white54 : Colors.black54)),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: widget.appData.toggleTheme,
                  icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 280, 
              child: Stack(
                children: List.generate(widget.appData.userCards.length, (cardIndex) {
                  final position = _stackOrder.indexOf(cardIndex);
                  return _buildAnimatedCard(cardIndex, position);
                }),
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121A2B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الحد الآمن اليومي للصرف:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('${widget.appData.dailyBudgetLimit.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildQuickAction(Icons.add_circle_outline, 'إضافة', isDark, () => _showAddTransactionDialog(context, true)),
                _buildQuickAction(Icons.remove_circle_outline, 'سحب/صرف', isDark, () => _showAddTransactionDialog(context, false)),
                _buildQuickAction(Icons.sync_rounded, 'فحص SMS', isDark, () => widget.appData.scanSmsInbox()),
              ],
            ),
            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerRight,
              child: Text('عمليات: ${activeCard.name}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            ),
            const SizedBox(height: 10),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeCard.transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = activeCard.transactions[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121A2B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(item.isIncome ? Icons.arrow_downward : Icons.arrow_upward, 
                               color: item.isIncome ? Colors.green : Colors.red, size: 20),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(item.date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      Text('${item.isIncome ? '+' : '-'}${item.amount.toStringAsFixed(2)} ج.م', 
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: item.isIncome ? Colors.green : Colors.red)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, bool isDark, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121A2B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isDark ? Colors.white70 : Colors.black87, size: 20),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCard(int cardIndex, int position) {
    final card = widget.appData.userCards[cardIndex];
    final double topOffset = position * 50.0; 
    final double scale = 1.0 - (position * 0.05);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      top: topOffset,
      left: 0, right: 0,
      child: GestureDetector(
        onTap: () => _bringCardToFront(cardIndex),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: Container(
            height: 180,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(card.primaryColor), Color(card.secondaryColor)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(card.badgeBg).withValues(alpha: 0.3)),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(card.badgeBg).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Color(card.badgeBg).withValues(alpha: 0.5)),
                      ),
                      child: Text(card.acronym, style: TextStyle(color: Color(card.badgeBg), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    Text(card.name, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الرصيد الحالي المتاح', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    const SizedBox(height: 4),
                    Text('${card.balance.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  ],
                ),
                const Text('متزامن محلياً', style: TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// === 2. صفحة التحليلات ===
class AnalyticsTab extends StatelessWidget {
  final AppData appData;
  const AnalyticsTab({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    double totalBalance = appData.userCards.fold(0, (sum, card) => sum + card.balance);
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تحليل السيولة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: appData.userCards.map((card) {
                    final value = card.balance > 0 ? card.balance : 1.0;
                    final percentage = (value / totalBalance) * 100;
                    return PieChartSectionData(
                      color: Color(card.badgeBg),
                      value: value,
                      title: '${percentage.toStringAsFixed(0)}%',
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: appData.userCards.length,
                itemBuilder: (ctx, i) {
                  final card = appData.userCards[i];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: Color(card.badgeBg), radius: 10),
                    title: Text(card.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    trailing: Text('${card.balance.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

// === 3. صفحة الميزانية ===
class BudgetTab extends StatefulWidget {
  final AppData appData;
  const BudgetTab({super.key, required this.appData});

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  late TextEditingController _limitController;

  @override
  void initState() {
    super.initState();
    _limitController = TextEditingController(text: widget.appData.dailyBudgetLimit.toString());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الميزانية اليومية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text('قم بتحديد سقف المصروفات اليومية الآمنة لتجنب الإسراف:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: _limitController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الحد اليومي (ج.م)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.all(12)),
                onPressed: () {
                  final val = double.tryParse(_limitController.text) ?? 620.0;
                  widget.appData.updateDailyLimit(val);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الميزانية بنجاح')));
                },
                child: const Text('حفظ التعديلات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === 4. صفحة الإعدادات ===
class SettingsTab extends StatelessWidget {
  final AppData appData;
  const SettingsTab({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('الإعدادات وصلاحيات النظام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.sms_rounded, color: Colors.blue),
            title: const Text('منح صلاحية قراءة رسائل البنك (SMS)'),
            subtitle: const Text('لتفعيل السحب التلقائي للمعاملات'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () async {
              var status = await Permission.sms.request();
              if (status.isGranted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم منح الصلاحية بنجاح')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الصلاحية')));
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(appData.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: Colors.orange),
            title: const Text('تغيير مظهر التطبيق'),
            trailing: Switch(
              value: appData.isDarkMode,
              onChanged: (val) => appData.toggleTheme(),
              activeColor: const Color(0xFF10B981),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('مسح جميع البيانات المحلية'),
            onTap: () {
              appData.prefs.clear();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم المسح. أعد تشغيل التطبيق.')));
            },
          ),
        ],
      ),
    );
  }
}
