import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(QersheenApp(prefs: prefs));
}

// ================= State Management =================
class AppData extends ChangeNotifier {
  final SharedPreferences prefs;
  bool isDarkMode;
  double dailyBudgetLimit;
  List<UserCardModel> userCards = [];

  AppData(this.prefs) 
      : isDarkMode = prefs.getBool('isDark') ?? true,
        dailyBudgetLimit = prefs.getDouble('dailyLimit') ?? 600.0 {
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
    if (cardsJson != null && cardsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(cardsJson);
      userCards = decoded.map((e) => UserCardModel.fromJson(e)).toList();
    } else {
      userCards = [];
    }
  }

  void _saveCards() {
    final String encoded = jsonEncode(userCards.map((c) => c.toJson()).toList());
    prefs.setString('cardsData', encoded);
  }

  void addNewCard(BankEntity entity) {
    final newCard = UserCardModel(
      id: entity.id + DateTime.now().millisecondsSinceEpoch.toString(),
      name: entity.name, acronym: entity.acronym, balance: 0.0,
      primaryColor: entity.primaryColor.value, secondaryColor: entity.secondaryColor.value, badgeBg: entity.badgeBg.value,
      transactions: [TransactionItem(name: 'تفعيل الحساب', date: DateTime.now().toIso8601String(), amount: 0.0, isIncome: true, category: 'عام')],
    );
    userCards.insert(0, newCard);
    _saveCards();
    notifyListeners();
  }

  void addTransaction(String cardId, String name, double amount, bool isIncome, String category) {
    final cardIndex = userCards.indexWhere((c) => c.id == cardId);
    if (cardIndex != -1) {
      userCards[cardIndex].balance += isIncome ? amount : -amount;
      userCards[cardIndex].transactions.insert(0, TransactionItem(
        name: name, date: DateTime.now().toIso8601String(), amount: amount, isIncome: isIncome, category: category
      ));
      _saveCards();
      notifyListeners();
    }
  }

  void deleteTransaction(String cardId, TransactionItem transaction) {
    final cardIndex = userCards.indexWhere((c) => c.id == cardId);
    if (cardIndex != -1) {
      userCards[cardIndex].balance += transaction.isIncome ? -transaction.amount : transaction.amount;
      userCards[cardIndex].transactions.remove(transaction);
      _saveCards();
      notifyListeners();
    }
  }

  void clearAllData() {
    userCards.clear();
    _saveCards();
    notifyListeners();
  }

  // حساب مصاريف اليوم لصفحة الميزانية
  double getTodayExpenses() {
    double total = 0;
    final today = DateTime.now();
    for (var card in userCards) {
      for (var tx in card.transactions) {
        if (!tx.isIncome) {
          final txDate = DateTime.parse(tx.date);
          if (txDate.year == today.year && txDate.month == today.month && txDate.day == today.day) {
            total += tx.amount;
          }
        }
      }
    }
    return total;
  }
}

// ================= Models =================
class UserCardModel {
  final String id, name, acronym;
  double balance;
  final int primaryColor, secondaryColor, badgeBg;
  final List<TransactionItem> transactions;

  UserCardModel({required this.id, required this.name, required this.acronym, required this.balance, required this.primaryColor, required this.secondaryColor, required this.badgeBg, required this.transactions});
  
  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'acronym': acronym, 'balance': balance, 'primaryColor': primaryColor, 'secondaryColor': secondaryColor, 'badgeBg': badgeBg,
    'transactions': transactions.map((t) => t.toJson()).toList(),
  };

  factory UserCardModel.fromJson(Map<String, dynamic> json) => UserCardModel(
    id: json['id'], name: json['name'], acronym: json['acronym'], balance: json['balance'], primaryColor: json['primaryColor'], secondaryColor: json['secondaryColor'], badgeBg: json['badgeBg'],
    transactions: (json['transactions'] as List).map((t) => TransactionItem.fromJson(t)).toList(),
  );
}

class TransactionItem {
  final String name, date, category;
  final double amount;
  final bool isIncome;
  TransactionItem({required this.name, required this.date, required this.amount, required this.isIncome, required this.category});

  Map<String, dynamic> toJson() => {'name': name, 'date': date, 'amount': amount, 'isIncome': isIncome, 'category': category};
  factory TransactionItem.fromJson(Map<String, dynamic> json) => TransactionItem(
    name: json['name'], date: json['date'], amount: json['amount'], isIncome: json['isIncome'], category: json['category'] ?? 'عام'
  );
}

class BankEntity {
  final String id, name, type, acronym;
  final Color primaryColor, secondaryColor, badgeBg;
  const BankEntity({required this.id, required this.name, required this.type, required this.acronym, required this.primaryColor, required this.secondaryColor, required this.badgeBg});
}

class EgyptInstitutions {
  static const List<BankEntity> all = [
    BankEntity(id: 'cib', name: 'البنك التجاري الدولي', type: 'بنك تجاري', acronym: 'CIB', primaryColor: Color(0xFF0B1A30), secondaryColor: Color(0xFF0369A1), badgeBg: Color(0xFF38BDF8)),
    BankEntity(id: 'nbe', name: 'البنك الأهلي المصري', type: 'بنك قطاع عام', acronym: 'NBE', primaryColor: Color(0xFF072B19), secondaryColor: Color(0xFF0E5431), badgeBg: Color(0xFFEAB308)),
    BankEntity(id: 'misr', name: 'بنك مصر', type: 'بنك قطاع عام', acronym: 'BM', primaryColor: Color(0xFF4A0A10), secondaryColor: Color(0xFF7F1D1D), badgeBg: Color(0xFFDC2626)),
    BankEntity(id: 'voda', name: 'فودافون كاش', type: 'محفظة إلكترونية', acronym: 'VODA', primaryColor: Color(0xFF3D0714), secondaryColor: Color(0xFF991B1B), badgeBg: Color(0xFFEF4444)),
  ];
}

// ================= App Setup =================
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
    final pages = [WalletTab(appData: widget.appData), AnalyticsTab(appData: widget.appData), BudgetTab(appData: widget.appData), SettingsTab(appData: widget.appData)];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF0D121E) : Colors.white, border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.account_balance_wallet_rounded, 'المحفظة', isDark),
            _buildNavItem(1, Icons.donut_large_rounded, 'التحليلات', isDark),
            _buildNavItem(2, Icons.track_changes_rounded, 'الميزانية', isDark),
            _buildNavItem(3, Icons.settings_rounded, 'الإعدادات', isDark),
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
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// ================= Tab 1: Wallet =================
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
    _syncStackOrder();
    widget.appData.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    widget.appData.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    _syncStackOrder();
    setState(() {});
  }

  void _syncStackOrder() {
    if (_stackOrder.length != widget.appData.userCards.length) {
      _stackOrder = List.generate(widget.appData.userCards.length, (i) => i);
    }
  }

  void _bringCardToFront(int cardIndex) {
    final currentPos = _stackOrder.indexOf(cardIndex);
    if (currentPos <= 0) return;
    setState(() {
      _stackOrder.removeAt(currentPos);
      _stackOrder.insert(0, cardIndex);
    });
  }

  void _openAddCardDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.appData.isDarkMode ? const Color(0xFF0D1424) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: EgyptInstitutions.all.length,
        itemBuilder: (context, idx) {
          final entity = EgyptInstitutions.all[idx];
          return ListTile(
            title: Text(entity.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(entity.type),
            trailing: const Icon(Icons.add_circle, color: Color(0xFF10B981)),
            onTap: () { widget.appData.addNewCard(entity); Navigator.pop(ctx); },
          );
        },
      ),
    );
  }

  void _showTransactionDialog(bool isIncome) {
    if (widget.appData.userCards.isEmpty) return;
    final activeCard = widget.appData.userCards[_stackOrder[0]];
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = isIncome ? 'راتب' : 'طعام';
    final categories = isIncome ? ['راتب', 'أعمال', 'أخرى'] : ['طعام', 'فواتير', 'مواصلات', 'تسوق', 'أخرى'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          backgroundColor: widget.appData.isDarkMode ? const Color(0xFF121A2B) : Colors.white,
          title: Text(isIncome ? 'إضافة دخل' : 'تسجيل مصروف'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'البيان (مثال: غداء)')),
              TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ (ج.م)')),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setStateSB(() => selectedCategory = v!),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isIncome ? Colors.green : Colors.red),
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0.0;
                if (amount > 0 && titleController.text.isNotEmpty) {
                  widget.appData.addTransaction(activeCard.id, titleController.text, amount, isIncome, selectedCategory);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    final d = DateTime.parse(isoDate);
    return '${d.year}/${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.appData.isDarkMode;
    final hasCards = widget.appData.userCards.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06B6D4)])),
                      child: const Icon(Icons.wallet, color: Colors.black, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text('قرشين', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ],
                ),
                IconButton(onPressed: _openAddCardDialog, icon: const Icon(Icons.add_card, color: Color(0xFF10B981), size: 30)),
              ],
            ),
            const SizedBox(height: 20),

            if (!hasCards)
              Container(
                height: 200, alignment: Alignment.center,
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(20)),
                child: const Text('اضغط على علامة + لإضافة حساب بنكي أو محفظة'),
              )
            else
              SizedBox(
                height: 200 + ((widget.appData.userCards.length - 1) * 60.0),
                child: Stack(
                  children: List.generate(widget.appData.userCards.length, (cardIndex) {
                    final position = _stackOrder.indexOf(cardIndex);
                    return _buildAnimatedCard(cardIndex, position);
                  }),
                ),
              ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAction(Icons.arrow_downward, 'دخل', Colors.green, isDark, () => _showTransactionDialog(true)),
                _buildQuickAction(Icons.arrow_upward, 'مصروف', Colors.redAccent, isDark, () => _showTransactionDialog(false)),
                _buildQuickAction(Icons.sync, 'تحويل', Colors.blue, isDark, () {}),
              ],
            ),
            const SizedBox(height: 20),
            
            if (hasCards) ...[
              Text('سجل عمليات: ${widget.appData.userCards[_stackOrder[0]].name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.appData.userCards[_stackOrder[0]].transactions.length,
                itemBuilder: (context, index) {
                  final item = widget.appData.userCards[_stackOrder[0]].transactions[index];
                  return Dismissible(
                    key: Key(item.date + item.name),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20),
                      color: Colors.red, child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (dir) => widget.appData.deleteTransaction(widget.appData.userCards[_stackOrder[0]].id, item),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
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
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: (item.isIncome ? Colors.green : Colors.red).withValues(alpha: 0.1), shape: BoxShape.circle),
                                child: Icon(item.isIncome ? Icons.south_west : Icons.north_east, color: item.isIncome ? Colors.green : Colors.red, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text('${item.category} • ${_formatDate(item.date)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          Text('${item.isIncome ? '+' : '-'}${item.amount.toStringAsFixed(0)} ج.م', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: item.isIncome ? Colors.green : Colors.red)),
                        ],
                      ),
                    ),
                  );
                },
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121A2B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAnimatedCard(int cardIndex, int position) {
    final card = widget.appData.userCards[cardIndex];
    final double topOffset = position * 60.0;
    final double scale = 1.0 - (position * 0.04);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic,
      top: topOffset, left: 0, right: 0,
      child: GestureDetector(
        onTap: () => _bringCardToFront(cardIndex),
        child: Transform.scale(
          scale: scale, alignment: Alignment.topCenter,
          child: Container(
            height: 190,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(card.primaryColor), Color(card.secondaryColor)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Color(card.badgeBg).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(card.acronym, style: TextStyle(color: Color(card.badgeBg), fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    Text(card.name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الرصيد المتاح', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Text('${card.balance.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================= Tab 2: Analytics =================
class AnalyticsTab extends StatelessWidget {
  final AppData appData;
  const AnalyticsTab({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    Map<String, double> expensesByCategory = {};
    for (var card in appData.userCards) {
      for (var tx in card.transactions) {
        if (!tx.isIncome) {
          expensesByCategory[tx.category] = (expensesByCategory[tx.category] ?? 0) + tx.amount;
        }
      }
    }

    final colors = [Colors.redAccent, Colors.blueAccent, Colors.orangeAccent, Colors.purpleAccent, Colors.teal];
    int colorIdx = 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تحليل المصروفات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            if (expensesByCategory.isEmpty)
              const Center(child: Text('لا توجد مصروفات مسجلة لتحليلها.'))
            else ...[
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: expensesByCategory.entries.map((e) {
                      final color = colors[colorIdx++ % colors.length];
                      return PieChartSectionData(
                        color: color, value: e.value, title: e.key, radius: 50,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text('تفاصيل الصرف:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: expensesByCategory.entries.map((e) {
                    return ListTile(
                      title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text('${e.value.toStringAsFixed(0)} ج.م', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

// ================= Tab 3: Budget =================
class BudgetTab extends StatefulWidget {
  final AppData appData;
  const BudgetTab({super.key, required this.appData});
  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  late TextEditingController _limitCtrl;

  @override
  void initState() {
    super.initState();
    _limitCtrl = TextEditingController(text: widget.appData.dailyBudgetLimit.toStringAsFixed(0));
  }

  @override
  Widget build(BuildContext context) {
    final todaySpent = widget.appData.getTodayExpenses();
    final limit = widget.appData.dailyBudgetLimit;
    final double percentage = (todaySpent / limit).clamp(0.0, 1.0);
    final isDanger = percentage > 0.8;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الميزانية اليومية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.appData.isDarkMode ? const Color(0xFF121A2B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDanger ? Colors.red.withValues(alpha: 0.5) : (widget.appData.isDarkMode ? Colors.white10 : Colors.black12)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('صرفت اليوم', style: TextStyle(color: Colors.grey)),
                      Text('${todaySpent.toStringAsFixed(0)} / ${limit.toStringAsFixed(0)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 12,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(isDanger ? Colors.red : const Color(0xFF10B981)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (isDanger) const Text('احذر! لقد اقتربت من تجاوز ميزانيتك اليومية.', style: TextStyle(color: Colors.red, fontSize: 12))
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text('تعديل الحد اليومي للصرف:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _limitCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'المبلغ (ج.م)'),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () {
                  final val = double.tryParse(_limitCtrl.text) ?? limit;
                  widget.appData.updateDailyLimit(val);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الميزانية')));
                },
                child: const Text('حفظ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ================= Tab 4: Settings =================
class SettingsTab extends StatelessWidget {
  final AppData appData;
  const SettingsTab({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('الإعدادات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ListTile(
            leading: Icon(appData.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: Colors.orange),
            title: const Text('المظهر الداكن (Dark Mode)'),
            trailing: Switch(value: appData.isDarkMode, onChanged: (v) => appData.toggleTheme(), activeColor: const Color(0xFF10B981)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sms, color: Colors.blue),
            title: const Text('قراءة رسائل البنوك تلقائياً'),
            subtitle: const Text('طلب صلاحية SMS لتحديث الأرصدة'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم تفعيل هذه الميزة قريباً'))); },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('تصفير التطبيق (مسح كل البيانات)'),
            onTap: () {
              appData.clearAllData();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم مسح جميع الحسابات والمعاملات.')));
            },
          ),
          const SizedBox(height: 40),
          const Center(child: Text('قرشين - الإصدار 1.0', style: TextStyle(color: Colors.grey, fontSize: 12))),
        ],
      ),
    );
  }
}
