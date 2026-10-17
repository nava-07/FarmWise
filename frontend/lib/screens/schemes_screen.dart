import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/language_provider.dart';
import '../providers/navigation_provider.dart';

class SchemesScreen extends StatefulWidget {
  const SchemesScreen({super.key});

  @override
  State<SchemesScreen> createState() => _SchemesScreenState();
}

class _SchemesScreenState extends State<SchemesScreen> {
  String _selectedTag = 'All';

  final List<String> _tags = [
    'All',
    'Direct Subsidy',
    'Crop Insurance',
    'Farming Loan & Credit',
    'Irrigation & Tech',
    'Soil & Nutrient',
  ];

  final List<Map<String, dynamic>> _schemes = [
    {
      'title': 'PM-KISAN Samman Nidhi Yojana',
      'desc': 'Get guaranteed income support of ₹6,000 per year in three equal installments directly transferred to bank accounts via Direct Benefit Transfer (DBT).',
      'tag': 'Direct Subsidy',
      'status': '🟢 LIVE TODAY — 17th Installment KYC Active',
      'benefit': '₹6,000 / Year Cash Grant',
      'eligibility': 'All landholding farming families across India with valid Aadhaar linked bank account.',
      'url': 'https://pmkisan.gov.in',
      'icon': Icons.account_balance_wallet,
      'color': const Color(0xFF059669),
    },
    {
      'title': 'Pradhan Mantri Fasal Bima Yojana (PMFBY)',
      'desc': 'Comprehensive crop insurance protection against drought, cyclone, flood, pests, and post-harvest losses at rock-bottom premium rates (1.5% - 2.0%).',
      'tag': 'Crop Insurance',
      'status': '🟢 LIVE DAILY — Kharif Season 2026 Open',
      'benefit': 'Up to 100% Crop Loss Compensation',
      'eligibility': 'Sharecroppers, tenant farmers, and landowners cultivating notified crops in designated zones.',
      'url': 'https://pmfby.gov.in',
      'icon': Icons.security,
      'color': const Color(0xFF2563EB),
    },
    {
      'title': 'Kisaan Credit Card (KCC) Loan Scheme',
      'desc': 'Institutional credit facility providing short-term cultivation loans up to ₹3,00,000 at a deeply subsidized 4% effective interest rate with timely repayment bonus.',
      'tag': 'Farming Loan & Credit',
      'status': '🟢 LIVE TODAY — Instant Digital Approval Active',
      'benefit': 'Up to ₹3.0 Lakh at 4% Interest',
      'eligibility': 'Individual farmers, joint farming groups, self-help groups, and agricultural laborers.',
      'url': 'https://www.myscheme.gov.in/schemes/kcc',
      'icon': Icons.credit_card,
      'color': const Color(0xFF7C3AED),
    },
    {
      'title': 'Pradhan Mantri Krishi Sinchayee Yojana (PMKSY)',
      'desc': 'Under "Per Drop More Crop", receive 55% to 90% government subsidy on modern Micro, Drip, and Sprinkler Irrigation automation installations.',
      'tag': 'Irrigation & Tech',
      'status': '🟢 LIVE DAILY — State Horticulture Portal Open',
      'benefit': '55% - 90% Heavy Drip Subsidy',
      'eligibility': 'All farmers possessing agricultural land with an existing sustainable water source (well/borewell).',
      'url': 'https://pmksy.gov.in',
      'icon': Icons.water_drop,
      'color': const Color(0xFF0284C7),
    },
    {
      'title': 'Soil Health Card (SHC) Scheme',
      'desc': 'Free scientific nutritional status evaluation of farm soil once every 2 years with tailored NPK fertilizer & micronutrient prescriptions.',
      'tag': 'Soil & Nutrient',
      'status': '🟢 LIVE TODAY — Free Sample Testing Active',
      'benefit': 'Free Laboratory Testing & Report Card',
      'eligibility': 'Every registered farmer in rural gram panchayat database across all Indian states.',
      'url': 'https://soilhealth.dac.gov.in',
      'icon': Icons.science,
      'color': const Color(0xFFD97706),
    },
    {
      'title': 'National Mission on Edible Oils & Oil Palms (NMEO-OP)',
      'desc': 'Special financial support, seed subsidies, and planting assistance for farmers cultivating mustard, groundnut, soybean, and oil palm crops.',
      'tag': 'Direct Subsidy',
      'status': '🟢 LIVE DAILY — 2026 Expansion Drive Open',
      'benefit': '₹29,000 / Hectare Planting Subsidy',
      'eligibility': 'Farmers undertaking fresh oil palm plantations or rotating grain crops to oilseeds.',
      'url': 'https://nmeo-op.gov.in',
      'icon': Icons.eco,
      'color': const Color(0xFF10B981),
    },
    {
      'title': 'Agriculture Infrastructure Fund (AIF)',
      'desc': 'Medium and long term debt financing facility providing 3% interest subvention and credit guarantee for cold stores, sorting units, and processing centers.',
      'tag': 'Farming Loan & Credit',
      'status': '🟢 LIVE TODAY — Applications Being Accepted',
      'benefit': '3% Interest Subvention + Credit Guarantee',
      'eligibility': 'Primary Agricultural Credit Societies (PACS), FPOs, agribusiness entrepreneurs, and farmers.',
      'url': 'https://agriinfra.dac.gov.in',
      'icon': Icons.warehouse,
      'color': const Color(0xFF4F46E5),
    },
  ];

  void _showApplyDialog(Map<String, dynamic> scheme) {
    showDialog(
      context: context,
      builder: (BuildContext dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(scheme['icon'] as IconData, color: scheme['color'] as Color, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text('Live Application Portal'.tr(context), style: TextStyle(fontWeight: FontWeight.w800, color: scheme['color'] as Color))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (scheme['title'] as String).tr(context),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF059669), size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text((scheme['status'] as String).tr(context), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF065F46)))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Required KYC Documents for Enrollment:'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain, fontSize: 14)),
                const SizedBox(height: 8),
                _buildDocItem('Aadhaar Card linked with Mobile Number'.tr(context)),
                _buildDocItem('Bank Account Passbook (IFSC Code & DBT enabled)'.tr(context)),
                _buildDocItem('Land Patta / Chitta / Revenue Khasra documents'.tr(context)),
                _buildDocItem('Recent Passport size photograph'.tr(context)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _launchSchemeUrl(scheme['url'] as String, scheme['title'] as String, scheme['color'] as Color),
                  child: Text(
                    'Official Govt Portal Reference:\n${scheme['url']}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Close'.tr(context), style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme['color'] as Color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.rocket_launch, size: 18),
              label: Text('Proceed to Online KYC & Apply'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(dialogCtx);
                _launchSchemeUrl(scheme['url'] as String, scheme['title'] as String, scheme['color'] as Color);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchSchemeUrl(String url, String title, Color color) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (e) {
        // Silently ignore if browser cannot be launched
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'Redirecting to Live Government Portal for'.tr(context)} ${title.tr(context)}...'),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildDocItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.folder_special, size: 16, color: AppColors.textLight),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textMain))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('dd MMMM yyyy').format(DateTime.now());
    
    List<Map<String, dynamic>> filtered = _schemes;
    if (_selectedTag != 'All') {
      filtered = _schemes.where((s) => s['tag'] == _selectedTag).toList();
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
        title: Text('Live Indian Government Schemes & Subsidies'.tr(context)),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live Daily Status Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF047857), Color(0xFF065F46)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GOVERNMENT DBT SUBSIDY PORTAL'.tr(context),
                              style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${'Live Daily Schemes Status — Today,'.tr(context)} $todayStr',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Category Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _tags.map((tag) {
                      final isSelected = _selectedTag == tag;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(tag.tr(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? Colors.white : AppColors.textMain)),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.white,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedTag = tag);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Schemes List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final scheme = filtered[index];
                    final color = scheme['color'] as Color;
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.06),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top row: Title and Icon
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(scheme['icon'] as IconData, color: color, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (scheme['title'] as String).tr(context),
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textMain),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          (scheme['tag'] as String).tr(context),
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            
                            // Live Status Badge
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                (scheme['status'] as String).tr(context),
                                style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Description
                            Text(
                              (scheme['desc'] as String).tr(context),
                              style: const TextStyle(color: AppColors.textLight, fontSize: 14, height: 1.5),
                            ),
                            const SizedBox(height: 14),

                            // Benefits and Eligibility Summary box
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.card_giftcard, size: 18, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text('Key Benefit:'.tr(context), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text((scheme['benefit'] as String).tr(context), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color))),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.people_outline, size: 18, color: AppColors.textLight),
                                      const SizedBox(width: 8),
                                      Text('Eligibility:'.tr(context), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text((scheme['eligibility'] as String).tr(context), style: const TextStyle(fontSize: 12.5, color: AppColors.textLight))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Action Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.app_registration, size: 20),
                                label: Text('Apply Live Online & Check KYC'.tr(context), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                onPressed: () => _showApplyDialog(scheme),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
