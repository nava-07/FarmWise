import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/language_provider.dart';
import '../providers/navigation_provider.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  static const String prefsKey = 'farm_finance_transactions_v1';

  // Static helper so Dashboard can load the exact same financial summary instantly
  static Future<Map<String, dynamic>> getFinanceSummary() async {
    final transactions = await getTransactions();
    int totalIncome = 0;
    int totalExpense = 0;

    for (var tx in transactions) {
      final int amount = (tx['amount'] as num).toInt();
      final String type = (tx['type'] ?? 'Income').toString().toLowerCase();
      if (type == 'income') {
        totalIncome += amount;
        if (tx['associatedExpense'] != null && (tx['associatedExpense'] as num) > 0) {
          totalExpense += (tx['associatedExpense'] as num).toInt();
        }
      } else {
        totalExpense += amount;
      }
    }

    final int profit = totalIncome - totalExpense;
    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'profit': profit,
    };
  }

  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(prefsKey);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      if (jsonStr.contains('Wheat Harvest Sales to Mandi')) {
        // Clear out old default dummy data
        await prefs.remove(prefsKey);
        return [];
      }
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        debugPrint('Error decoding finance transactions: $e');
      }
    }

    return [];
  }

  static Future<void> saveTransactions(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(list));
  }

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final txs = await FinanceScreen.getTransactions();
    final summary = await FinanceScreen.getFinanceSummary();
    if (mounted) {
      setState(() {
        _transactions = txs;
        _summary = summary;
        _loading = false;
      });
    }
  }

  Future<void> _showAddTransactionDialog() async {
    String selectedType = 'Income';
    String selectedCategory = 'Crop Sales';
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final optionalExpenseController = TextEditingController();

    final List<String> incomeCategories = ['Crop Sales', 'Subsidy', 'Livestock', 'Rental', 'Other Income'];
    final List<String> expenseCategories = ['Fertilizers', 'Seeds', 'Equipment', 'Labor', 'Pesticides', 'Other Expense'];

    try {
      await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final categories = selectedType == 'Income' ? incomeCategories : expenseCategories;
              if (!categories.contains(selectedCategory)) {
                selectedCategory = categories.first;
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text('Add New Transaction'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Type Selector
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedType == 'Income' ? AppColors.primary : Colors.grey.shade200,
                                foregroundColor: selectedType == 'Income' ? Colors.white : AppColors.textMuted,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => setDialogState(() {
                                selectedType = 'Income';
                                selectedCategory = incomeCategories.first;
                              }),
                              child: Text('+ ${"Income".tr(context)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedType == 'Expense' ? AppColors.error : Colors.grey.shade200,
                                foregroundColor: selectedType == 'Expense' ? Colors.white : AppColors.textMuted,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => setDialogState(() {
                                selectedType = 'Expense';
                                selectedCategory = expenseCategories.first;
                              }),
                              child: Text('- ${"Expense".tr(context)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Description / Title'.tr(context),
                          hintText: selectedType == 'Income' ? 'e.g. Sold Tomato batch'.tr(context) : 'e.g. Bought Drip Irrigation Pipe'.tr(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount (in ₹)'.tr(context),
                          prefixText: '₹ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category'.tr(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c.tr(context)))).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedCategory = val);
                        },
                      ),
                      if (selectedType == 'Income') ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: optionalExpenseController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Associated Expense (Optional, in ₹)'.tr(context),
                            hintText: 'e.g. Cost of seeds, labor, transport'.tr(context),
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            helperText: 'Enter any expense incurred to calculate net profit/loss on this income'.tr(context),
                            helperStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text('Cancel'.tr(context), style: const TextStyle(color: AppColors.textMuted)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final title = titleController.text.trim();
                      final amountStr = amountController.text.trim();
                      if (title.isEmpty || amountStr.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please enter description and amount'.tr(context))),
                        );
                        return;
                      }
                      final int? amount = int.tryParse(amountStr);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please enter a valid amount'.tr(context))),
                        );
                        return;
                      }

                      int? associatedExpense;
                      if (selectedType == 'Income' && optionalExpenseController.text.trim().isNotEmpty) {
                        associatedExpense = int.tryParse(optionalExpenseController.text.trim());
                      }

                      final newTx = {
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'title': title,
                        'amount': amount,
                        'type': selectedType,
                        'date': 'Today',
                        'category': selectedCategory,
                        if (associatedExpense != null && associatedExpense > 0) 'associatedExpense': associatedExpense,
                      };

                      final updatedList = [newTx, ..._transactions];
                      await FinanceScreen.saveTransactions(updatedList);
                      Navigator.pop(dialogContext);
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${selectedType.tr(context)} added successfully!'), backgroundColor: AppColors.primary),
                      );
                    },
                    child: Text('Save Transaction'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      titleController.dispose();
      amountController.dispose();
      optionalExpenseController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredTxs = _transactions;
    if (_selectedFilter != 'All') {
      filteredTxs = _transactions.where((tx) => (tx['type'] as String?)?.toLowerCase() == _selectedFilter.toLowerCase()).toList();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back to Home'.tr(context),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Provider.of<NavigationProvider>(context, listen: false).setIndex(0);
            }
          },
        ),
        title: Text('Farm Finance Hub'.tr(context)),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Data'.tr(context),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Add Transaction'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddTransactionDialog,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBalanceCard(),
                      const SizedBox(height: 24),
                      _buildCategoryBreakdowns(),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transactions'.tr(context),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textMain),
                          ),
                          _buildFilterChips(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTransactionsList(filteredTxs),
                      const SizedBox(height: 80), // Padding for FAB
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCategoryBreakdowns() {
    final Map<String, int> incomeByCategory = {};
    final Map<String, int> expenseByCategory = {};

    for (var tx in _transactions) {
      final int amt = (tx['amount'] as num).toInt();
      final String type = (tx['type'] ?? 'Income').toString().toLowerCase();
      final String cat = tx['category'] ?? 'General';
      
      if (type == 'income') {
        incomeByCategory[cat] = (incomeByCategory[cat] ?? 0) + amt;
        if (tx['associatedExpense'] != null && (tx['associatedExpense'] as num) > 0) {
          final int expAmt = (tx['associatedExpense'] as num).toInt();
          final String expCat = '$cat (${"Cost".tr(context)})';
          expenseByCategory[expCat] = (expenseByCategory[expCat] ?? 0) + expAmt;
        }
      } else {
        expenseByCategory[cat] = (expenseByCategory[cat] ?? 0) + amt;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Category-Wise Breakdown'.tr(context),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textMain),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildCategoryCard(
                title: 'Income Categories'.tr(context),
                icon: Icons.trending_up,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
                categories: incomeByCategory,
                emptyMessage: 'No income recorded'.tr(context),
                isIncome: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCategoryCard(
                title: 'Expense Categories'.tr(context),
                icon: Icons.trending_down,
                iconColor: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
                categories: expenseByCategory,
                emptyMessage: 'No expenses recorded'.tr(context),
                isIncome: false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Map<String, int> categories,
    required String emptyMessage,
    required bool isIncome,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: bgColor,
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w700, color: iconColor, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  emptyMessage,
                  style: const TextStyle(color: AppColors.textLight, fontSize: 13, fontStyle: FontStyle.italic),
                ),
              )
            else
              ...categories.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key.tr(context),
                          style: const TextStyle(color: AppColors.textMain, fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '₹${entry.value}',
                        style: TextStyle(color: iconColor, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        _buildChip('All'),
        const SizedBox(width: 8),
        _buildChip('Income'),
        const SizedBox(width: 8),
        _buildChip('Expense'),
      ],
    );
  }

  Widget _buildChip(String label) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label.tr(context), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.textMuted)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = label);
        }
      },
    );
  }

  Widget _buildBalanceCard() {
    if (_summary == null) return const SizedBox();
    
    final income = _summary!['totalIncome'] ?? 0;
    final expense = _summary!['totalExpense'] ?? 0;
    final profit = _summary!['profit'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net Farm Profit / Balance'.tr(context),
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Season 2026'.tr(context), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹$profit',
            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward, color: Color(0xFF6EE7B7), size: 16),
                          const SizedBox(width: 4),
                          Expanded(child: Text('Total Income'.tr(context), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('₹$income', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward, color: Color(0xFFFCA5A5), size: 16),
                          const SizedBox(width: 4),
                          Expanded(child: Text('Total Expense'.tr(context), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('₹$expense', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(List<Map<String, dynamic>> txs) {
    if (txs.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 1,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.textLight),
                const SizedBox(height: 12),
                Text('No transactions found'.tr(context), style: const TextStyle(color: AppColors.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Tap "Add Transaction" below to keep track of your farm finances.'.tr(context), style: const TextStyle(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: txs.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final tx = txs[index];
          final type = tx['type'] as String? ?? 'Income';
          final isIncome = type.toLowerCase() == 'income';
          final category = tx['category'] as String? ?? 'Farming';
          
          final num? assocExpNum = tx['associatedExpense'] as num?;
          final int assocExp = assocExpNum?.toInt() ?? 0;
          final int amount = (tx['amount'] as num).toInt();
          final int diff = amount - assocExp;

          return Dismissible(
            key: Key(tx['id'] ?? index.toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              color: AppColors.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (direction) async {
              final id = tx['id'];
              final updated = _transactions.where((item) => item['id'] != id).toList();
              await FinanceScreen.saveTransactions(updated);
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Transaction deleted'.tr(context))),
                );
              }
            },
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: isIncome ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                child: Icon(
                  isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  size: 24,
                ),
              ),
              title: Text(
                tx['title'] ?? tx['description'] ?? 'Farming transaction',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMain, fontSize: 15),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(category.tr(context), style: TextStyle(fontSize: 10, color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          (tx['date'] ?? '').toString().tr(context),
                          style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                        ),
                      ],
                    ),
                    if (isIncome && assocExp > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: diff >= 0 ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              diff >= 0 ? Icons.trending_up : Icons.trending_down,
                              size: 12,
                              color: diff >= 0 ? const Color(0xFF065F46) : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                diff >= 0
                                    ? '${"Profit:".tr(context)} +₹$diff (${"Expense:".tr(context)} ₹$assocExp)'
                                    : '${"Loss:".tr(context)} -₹${diff.abs()} (${"Expense:".tr(context)} ₹$assocExp)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: diff >= 0 ? const Color(0xFF065F46) : const Color(0xFFDC2626),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing: Text(
                '${isIncome ? "+" : "-"} ₹${tx['amount']}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  fontSize: 17,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
