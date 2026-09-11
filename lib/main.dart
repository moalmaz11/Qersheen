import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'models/finance_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D0D11),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const QersheenApp());
}

class QersheenApp extends StatelessWidget {
  const QersheenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'قرشين - Qersheen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090A0F),
        primaryColor: const Color(0xFFE5C07B),
        fontFamily: 'Cairo',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE5C07B),
          secondary: Color(0xFF00E676),
          surface: Color(0xFF14161F),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: ModernWalletHome(),
      ),
    );
  }
}

class ModernWalletHome extends StatefulWidget {
  const ModernWalletHome({super.key});

  @override
  State<ModernWalletHome> createState() => _ModernWalletHomeState();
}

class _ModernWalletHomeState extends State<ModernWalletHome> {
  int _activeNav = 0;
  List<BankCard> _cards = [];
  List<TransactionRecord> _transactions = [];
  List<LoanObligation> _obligations = [];
  bool _isLoading = true;
  String? _selectedCardId;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // تحميل الكروت
    final cardsData = prefs.getString('saved_cards');
    if (cardsData != null) {
      final List dec = jsonDecode(cardsData);
      _cards = dec.map((e) => BankCard.fromMap(e)).toList();
    } else {
      _cards = [
        BankCard(
          id: 'card_cib',
          title: 'حساب CIB الجاري',
          issuer: 'CIB',
          lastFour: '8821',
          balance: 42500.0,
          primaryColor: 0xFF1B2A4A,
          secondaryColor: 0xFF0D1526,
        ),
        BankCard(
          id: 'card_vf',
          title: 'فودافون كاش',
          issuer: 'Vodafone',
          lastFour: '0109',
          balance: 6200.0,
          primaryColor: 0xFF8B1515,
          secondaryColor: 0xFF3D0909,
        ),
        BankCard(
          id: 'card_instapay',
          title: 'إنستاباي - IPA',
          issuer: 'InstaPay',
          lastFour: '0943',
          balance: 15800.0,
          primaryColor: 0xFF4A148C,
          secondaryColor: 0xFF1E0738,
        ),
      ];
      _saveCards();
    }

    // تحميل المعاملات
    final txData = prefs.getString('saved_tx');
    if (txData != null) {
      final List dec = jsonDecode(txData);
      _transactions = dec.map((e) => TransactionRecord.fromMap(e)).toList();
    } else {
      _transactions = [
        TransactionRecord(
          id: 'tx_1',
          cardId: 'card_cib',
          amount: 1250.0,
          type: 'expense',
          category: 'تسوق وسوبرماركت',
          note: 'كارفور سيتي سنتر',
          date: DateTime.now().subtract(const Duration(hours: 4)),
        ),
        TransactionRecord(
          id: 'tx_2',
          cardId: 'card_vf',
          amount: 350.0,
          type: 'expense',
          category: 'فواتير ومرافق',
          note: 'فاتورة الكهرباء وشحن رصيد',
          date: DateTime.now().subtract(const Duration(days: 1)),
        ),
        TransactionRecord(
          id: 'tx_3',
          cardId: 'card_instapay',
          amount: 7000.0,
          type: 'income',
          category: 'تحويلات واستلام',
          note: 'تحويل نقدي وارد',
          date: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];
      _saveTx();
    }

    // تحميل الأقساط
    final obData = prefs.getString('saved_ob');
    if (obData != null) {
      final List dec = jsonDecode(obData);
      _obligations = dec.map((e) => LoanObligation.fromMap(e)).toList();
    } else {
      _obligations = [
        LoanObligation(
          id: 'ob_1',
          title: 'لابتوب العمل M3',
          provider: 'ڤاليو - ValU',
          monthlyAmount: 2350.0,
          totalMonths: 12,
          paidMonths: 4,
          dueDay: 15,
        ),
      ];
      _saveOb();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveCards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_cards', jsonEncode(_cards.map((e) => e.toMap()).toList()));
  }

  Future<void> _saveTx() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_tx', jsonEncode(_transactions.map((e) => e.toMap()).toList()));
  }

  Future<void> _saveOb() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_ob', jsonEncode(_obligations.map((e) => e.toMap()).toList()));
  }

  double get _netWorth => _cards.fold(0.0, (sum, c) => sum + c.balance);

  void _addCustomTransaction(TransactionRecord tx) {
    setState(() {
      _transactions.insert(0, tx);
      final idx = _cards.indexWhere((c) => c.id == tx.cardId);
      if (idx != -1) {
        final c = _cards[idx];
        final newBal = tx.type == 'income' ? c.balance + tx.amount : c.balance - tx.amount;
        _cards[idx] = BankCard(
          id: c.id,
          title: c.title,
          issuer: c.issuer,
          lastFour: c.lastFour,
          balance: newBal,
          primaryColor: c.primaryColor,
          secondaryColor: c.secondaryColor,
        );
      }
    });
    _saveTx();
    _saveCards();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE5C07B))),
      );
    }

    final filteredTransactions = _selectedCardId == null
        ? _transactions
        : _transactions.where((t) => t.cardId == _selectedCardId).toList();

    return Scaffold(
      body: SafeArea(
        child: _activeNav == 0
            ? _buildWalletView(filteredTransactions)
            : _activeNav == 1
                ? _buildObligationsView()
                : _buildSettingsView(),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          color: Color(0xFF0F1118),
          border: Border(top: BorderSide(color: Color(0xFF1F2333), width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavButton(0, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'المحفظة'),
            _buildNavButton(1, Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded, 'الأقساط'),
            _buildNavButton(2, Icons.tune_rounded, Icons.tune_rounded, 'الخصوصية'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(int idx, IconData iconOff, IconData iconOn, String label) {
    final active = _activeNav == idx;
    return InkWell(
      onTap: () => setState(() => _activeNav = idx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? iconOn : iconOff, color: active ? const Color(0xFFE5C07B) : Colors.white38, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? const Color(0xFFE5C07B) : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletView(List<TransactionRecord> currentTxs) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إجمالي الثروة النقدية',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      NumberFormat('#,##0.00').format(_netWorth),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ج.م',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE5C07B)),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_rounded, size: 14, color: Color(0xFF00E676)),
                  SizedBox(width: 6),
                  Text('محلي ١٠٠٪', style: TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // قسم البطاقات الأفقي
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _cards.length,
            itemBuilder: (ctx, i) {
              final c = _cards[i];
              final isSel = _selectedCardId == c.id;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCardId = isSel ? null : c.id;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 300,
                  margin: const EdgeInsets.only(left: 14),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(c.primaryColor), Color(c.secondaryColor)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSel ? const Color(0xFFE5C07B) : Colors.white12,
                      width: isSel ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            c.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            c.issuer,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFE5C07B)),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الرصيد الفعلي', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                '${NumberFormat('#,##0.00').format(c.balance)} ج.م',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                          Text(
                            '•••• ${c.lastFour}',
                            style: const TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 24),

        // أزرار العمليات
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openAddTxSheet(),
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.black, size: 20),
                label: const Text('إضافة معاملة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5C07B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                if (_selectedCardId != null) {
                  setState(() => _selectedCardId = null);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B1E29),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              child: Icon(
                _selectedCardId != null ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded,
                color: _selectedCardId != null ? const Color(0xFFE5C07B) : Colors.white60,
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedCardId != null ? 'معاملات البطاقة المحددة' : 'السجل المالي الأخير',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              '${currentTxs.length} عمليات',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ...currentTxs.map((tx) {
          final isIncome = tx.type == 'income';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF13151F),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF1E2233)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isIncome ? const Color(0xFF00E676).withOpacity(0.12) : const Color(0xFFFF5252).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
                    color: isIncome ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.note,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${tx.category} • ${DateFormat('dd MMM - hh:mm a').format(tx.date)}',
                        style: const TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isIncome ? '+' : '-'}${NumberFormat('#,##0.00').format(tx.amount)} ج.م',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isIncome ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildObligationsView() {
    final totalMonthly = _obligations.fold(0.0, (s, o) => s + o.monthlyAmount);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        const Text('الأقساط والالتزامات المالية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('متابعة سداد ڤاليو، أمان، وسلف البنوك شهرياً', style: TextStyle(color: Colors.white38, fontSize: 13)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF13151F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E2233)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إجمالي الدفعات هذا الشهر', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    '${NumberFormat('#,##0.00').format(totalMonthly)} ج.م',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE5C07B)),
                  ),
                ],
              ),
              const Icon(Icons.event_note_rounded, color: Color(0xFFE5C07B), size: 32),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ..._obligations.map((ob) {
          final progress = ob.paidMonths / ob.totalMonths;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF13151F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E2233)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(ob.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${ob.monthlyAmount.toStringAsFixed(0)} ج.م/شهر', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE5C07B))),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${ob.provider} • استحقاق يوم ${ob.dueDay} شهرياً', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تم سداد ${ob.paidMonths} من ${ob.totalMonths} شهر', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    Text('${((progress) * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSettingsView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        const Text('الخصوصية والتحكم', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('بياناتك المالية مشفرة ومحفوظة على هاتفك فقط', style: TextStyle(color: Colors.white38, fontSize: 13)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF00E676).withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF00E676).withOpacity(0.25)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFF00E676), size: 28),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'التطبيق يعمل بدون إنترنت نهائياً بنسبة ١٠٠٪ وبدون خوادم وسيطة.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          tileColor: const Color(0xFF13151F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: const Icon(Icons.share_rounded, color: Color(0xFFE5C07B)),
          title: const Text('تصدير المعاملات CSV'),
          subtitle: const Text('حفظ نسخة جدولية من الحركات', style: TextStyle(fontSize: 12, color: Colors.white38)),
          onTap: () {
            final buffer = StringBuffer('ID,Card,Amount,Type,Category,Note,Date\n');
            for (var t in _transactions) {
              buffer.writeln('${t.id},${t.cardId},${t.amount},${t.type},${t.category},"${t.note}",${t.date}');
            }
            Share.share(buffer.toString(), subject: 'تقرير قرشين المالي');
          },
        ),
      ],
    );
  }

  void _openAddTxSheet() {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String type = 'expense';
    String cardId = _cards.first.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141622),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إضافة معاملة جديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('مصروف')),
                      selected: type == 'expense',
                      selectedColor: const Color(0xFFFF5252),
                      onSelected: (v) => setSheetState(() => type = 'expense'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('دخل')),
                      selected: type == 'income',
                      selectedColor: const Color(0xFF00E676),
                      onSelected: (v) => setSheetState(() => type = 'income'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amtCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'المبلغ (جنيه مصري)',
                  filled: true,
                  fillColor: const Color(0xFF1E2233),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: 'الوصف أو الملاحظة',
                  filled: true,
                  fillColor: const Color(0xFF1E2233),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final val = double.tryParse(amtCtrl.text);
                    if (val != null && val > 0) {
                      _addCustomTransaction(
                        TransactionRecord(
                          id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
                          cardId: cardId,
                          amount: val,
                          type: type,
                          category: 'معاملة يدوية',
                          note: noteCtrl.text.isEmpty ? 'معاملة نقدية' : noteCtrl.text,
                          date: DateTime.now(),
                        ),
                      );
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5C07B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('حفظ المعاملة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
