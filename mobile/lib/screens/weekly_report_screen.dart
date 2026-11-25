import 'package:nutricare/utils/app_urls.dart';
import 'package:nutricare/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'widgets/custom_card.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? reportData;
  Map<String, dynamic>? _aiAnalysis;
  bool isLoading = false;
  bool isPrinting = false;
  bool _useAI = false;
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;

  // Animation controllers
  late AnimationController _scoreAnimationController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    selectedEndDate = DateTime.now();
    selectedStartDate = DateTime.now().subtract(const Duration(days: 6));

    _scoreAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scoreAnimationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════
  // DATA HELPERS
  // ═══════════════════════════════════════

  Future<int> getCurrentUserId() async {
    final currentAuth = await AuthService().getAuth();
    final authDataString =
        currentAuth == null ? null : jsonEncode(currentAuth.toJson());
    if (authDataString == null) return 1;
    final Map<String, dynamic> authData = jsonDecode(authDataString);
    return authData['user']?['user_id'] ?? 1;
  }

  String _getComplianceText() {
    if (reportData == null) return '0/7 Days Tracked';
    final compliance = reportData?['compliance'] ?? '';
    final match = RegExp(r'(\d+)/(\d+)').firstMatch(compliance);
    if (match != null)
      return '${match.group(1)}/${match.group(2)} Days Tracked';
    final totalDays = reportData?['summary']?['total_days'] ?? 0;
    if (totalDays > 0) return '$totalDays/7 Days Tracked';
    final dailyLogs = reportData?['daily_logs'] as List?;
    if (dailyLogs != null && dailyLogs.isNotEmpty)
      return '${dailyLogs.length}/7 Days Tracked';
    return '0/7 Days Tracked';
  }

  String _getTrendText() {
    if (reportData == null) return 'STABLE';
    String trend = reportData?['summary']?['trend'] ??
        reportData?['weekly_trend'] ??
        'STABLE';
    trend = trend.toString().toUpperCase();
    if (trend == 'RISING') return 'GLUCOSE RISING';
    if (trend == 'FALLING') return 'GLUCOSE FALLING';
    if (trend == 'STABLE') return 'STABLE';
    return 'INSUFFICIENT DATA';
  }

  Color _getTrendColor() {
    switch (_getTrendText()) {
      case 'GLUCOSE FALLING':
        return AppColors.textSecondary;
      case 'GLUCOSE RISING':
        return AppColors.textSecondary;
      default:
        return AppColors.warning;
    }
  }

  IconData _getTrendIcon() {
    switch (_getTrendText()) {
      case 'GLUCOSE FALLING':
        return Icons.trending_up;
      case 'GLUCOSE RISING':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  int _getDaysCount() {
    if (reportData == null) return 0;
    final logs = reportData?['daily_logs'] as List? ?? [];
    return logs.length;
  }

  bool _hasEnoughDataForAI() {
    return _getDaysCount() >= 3;
  }

  // ═══════════════════════════════════════
  // API CALLS
  // ═══════════════════════════════════════

  Future<void> fetchWeeklyReport() async {
    if (selectedStartDate == null || selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date range')),
      );
      return;
    }

    final daysDifference =
        selectedEndDate!.difference(selectedStartDate!).inDays;
    if (daysDifference > 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 7 days allowed')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      _aiAnalysis = null;
      reportData = null;
    });

    final currentAuth = await AuthService().getAuth();
    final authDataString =
        currentAuth == null ? null : jsonEncode(currentAuth.toJson());
    if (authDataString == null) {
      setState(() => isLoading = false);
      return;
    }

    final Map<String, dynamic> authData = jsonDecode(authDataString);
    final String? token = authData['access_token'];
    if (token == null || token.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    final startDateStr = DateFormat('yyyy-MM-dd').format(selectedStartDate!);
    final endDateStr = DateFormat('yyyy-MM-dd').format(selectedEndDate!);

    final endpoint = _useAI
        ? '${AppUrls.baseUrl}/weekly-reports/generate-with-ai'
        : '${AppUrls.baseUrl}/weekly-reports/generate';

    final url =
        Uri.parse('$endpoint?start_date=$startDateStr&end_date=$endDateStr');

    try {
      final response = await http.post(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        setState(() {
          reportData = decoded;
          _aiAnalysis = decoded['ai_analysis'];
        });

        if (_aiAnalysis?['health_score'] != null &&
            (_aiAnalysis!['health_score'] as Map).isNotEmpty) {
          _scoreAnimationController.forward(from: 0);
        }
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error['detail'] ?? 'Failed to generate report')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() => isLoading = false);
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: selectedStartDate ??
            DateTime.now().subtract(const Duration(days: 6)),
        end: selectedEndDate ?? DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (picked.end.difference(picked.start).inDays > 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 7 days allowed')),
        );
        return;
      }

      setState(() {
        selectedStartDate = picked.start;
        selectedEndDate = picked.end;
      });
      await fetchWeeklyReport();
    }
  }

  // ═══════════════════════════════════════
  // PRINT/PDF
  // ═══════════════════════════════════════

  Future<void> _printOrSaveReport() async {
    if (reportData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please generate report first')),
      );
      return;
    }

    setState(() => isPrinting = true);

    try {
      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        build: (context) => [
          _buildPdfHeader(),
          _buildPdfExecutiveSummary(),
          _buildPdfClinicalMetrics(),
          _buildPdfLifestyleMetrics(),
          _buildPdfComparativeAnalysis(),
          _buildPdfDailyLogs(),
          _buildPdfAchievements(),
          _buildPdfFooter(),
        ],
        margin: const pw.EdgeInsets.all(40),
      ));

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'NutriCare_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isPrinting = false);
    }
  }

  // ═══════════════════════════════════════
  // PDF BUILDERS
  // ═══════════════════════════════════════

  pw.Widget _buildPdfHeader() {
    return pw.Column(children: [
      pw.Center(
          child: pw.Text('NutriCare Health Report',
              style:
                  pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 10),
      pw.Center(
          child: pw.Text('AI-Powered Health Analytics',
              style: pw.TextStyle(fontSize: 14, color: PdfColors.grey))),
      pw.SizedBox(height: 20),
      pw.Divider(),
      pw.SizedBox(height: 10),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Report ID: ${reportData?['report_id'] ?? 'N/A'}'),
        pw.Text('Generated: ${reportData?['generated_at'] ?? '-'}'),
      ]),
      pw.SizedBox(height: 20),
    ]);
  }

  pw.Widget _buildPdfExecutiveSummary() {
    return pw.Column(children: [
      pw.Text('Executive Summary',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Container(
        padding: const pw.EdgeInsets.all(15),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(children: [
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [
                  pw.Text(_getComplianceText(),
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Compliance',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey))
                ]),
                pw.Column(children: [
                  pw.Text(_getTrendText(),
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Trend',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey))
                ]),
              ]),
        ]),
      ),
      pw.SizedBox(height: 20),
    ]);
  }

  pw.Widget _buildPdfClinicalMetrics() {
    return pw.Column(children: [
      pw.Text('Clinical Metrics',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Table(border: pw.TableBorder.all(), children: [
        pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              _pdfCell('Parameter', bold: true),
              _pdfCell('Average', bold: true),
              _pdfCell('Target', bold: true),
              _pdfCell('Status', bold: true),
            ]),
        ...(reportData?['clinical_metrics'] as List? ?? [])
            .map((m) => pw.TableRow(children: [
                  _pdfCell(m['parameter'] ?? '-'),
                  _pdfCell(m['average_value'] ?? '-'),
                  _pdfCell(m['target_range'] ?? '-'),
                  _pdfCell(m['status'] ?? '-'),
                ])),
      ]),
      pw.SizedBox(height: 20),
    ]);
  }

  pw.Widget _buildPdfLifestyleMetrics() {
    return pw.Column(children: [
      pw.Text('Lifestyle Metrics',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Table(border: pw.TableBorder.all(), children: [
        pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              _pdfCell('Factor', bold: true),
              _pdfCell('Average', bold: true),
              _pdfCell('Recommendation', bold: true),
              _pdfCell('Assessment', bold: true),
            ]),
        ...(reportData?['lifestyle_metrics'] as List? ?? [])
            .map((m) => pw.TableRow(children: [
                  _pdfCell(m['factor'] ?? '-'),
                  _pdfCell(m['weekly_average'] ?? '-'),
                  _pdfCell(m['recommendation'] ?? '-'),
                  _pdfCell(m['assessment'] ?? '-'),
                ])),
      ]),
      pw.SizedBox(height: 20),
    ]);
  }

  pw.Widget _buildPdfComparativeAnalysis() {
    return pw.Column(children: [
      pw.Text('Comparative Analysis',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Expanded(
            child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.green),
              borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(children: [
            pw.Text('Lowest Average Glucose',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(reportData?['best_day']?['date'] ?? 'N/A'),
            pw.Text(
                'Glucose: ${reportData?['best_day']?['avg_glucose'] ?? 0} mg/dL'),
          ]),
        )),
        pw.SizedBox(width: 10),
        pw.Expanded(
            child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.red),
              borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(children: [
            pw.Text('Highest Average Glucose',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(reportData?['worst_day']?['date'] ?? 'N/A'),
            pw.Text(
                'Glucose: ${reportData?['worst_day']?['avg_glucose'] ?? 0} mg/dL'),
          ]),
        )),
      ]),
      pw.SizedBox(height: 20),
    ]);
  }

  pw.Widget _buildPdfDailyLogs() {
    final logs = reportData?['daily_logs'] as List? ?? [];
    return pw.Column(children: [
      pw.Text('Daily Log Summary',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Table(border: pw.TableBorder.all(), children: [
        pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              _pdfCell('Date', bold: true),
              _pdfCell('AM', bold: true),
              _pdfCell('PM', bold: true),
              _pdfCell('Exercise', bold: true),
              _pdfCell('Sleep', bold: true),
              _pdfCell('Water', bold: true),
              _pdfCell('Status', bold: true),
            ]),
        ...logs.map((l) => pw.TableRow(children: [
              _pdfCell(l['date'] ?? '-'),
              _pdfCell('${l['morning_glucose'] ?? '—'}'),
              _pdfCell('${l['evening_glucose'] ?? '—'}'),
              _pdfCell('${l['exercise_minutes'] ?? '—'}'),
              _pdfCell('${l['sleep_hours'] ?? '—'}'),
              _pdfCell('${l['water'] ?? '—'}'),
              _pdfCell(l['status'] ?? '-'),
            ])),
      ]),
      pw.SizedBox(height: 20),
    ]);
  }

  pw.Widget _buildPdfAchievements() {
    final achievements = reportData?['achievements'] as List? ?? [];
    return pw.Column(children: [
      pw.Text('Achievements & Recommendations',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(children: [
          pw.Text('Key Achievements:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          ...achievements.map((a) => pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
              child: pw.Text(
                  '• ${a.toString().replaceAll('✓', '[+]').replaceAll('⚠️', '[!]')}'))),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Text('Recommendations:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10),
              child: pw.Text(reportData?['recommendations'] ??
                  'Continue maintaining healthy habits.')),
        ]),
      ),
      pw.SizedBox(height: 20),
    ]);
  }

  pw.Widget _buildPdfFooter() {
    return pw.Column(children: [
      pw.Divider(),
      pw.SizedBox(height: 10),
      pw.Text(
          'Medical Disclaimer: This report is for informational purposes only. Consult your healthcare provider for medical advice.',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          textAlign: pw.TextAlign.center),
      pw.SizedBox(height: 5),
      pw.Text('NutriCare © 2025 Diabetes Management System',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          textAlign: pw.TextAlign.center),
    ]);
  }

  pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)));
  }

  // ═══════════════════════════════════════
  // AI ANALYSIS SECTION BUILDERS
  // ═══════════════════════════════════════

  Widget _buildAIAnalysisSection() {
    if (_aiAnalysis == null) return const SizedBox.shrink();

    // Check if it's insufficient data
    if (_aiAnalysis!['risk_level'] == 'insufficient_data') {
      return const SizedBox.shrink(); // Already shown above
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        CustomCard(
          padding: const EdgeInsets.all(24),
          borderRadius: BorderRadius.circular(16),
          elevation: 3,
          backgroundColor: Colors.purple.withOpacity(0.03),
          border: Border.all(color: Colors.purple.withOpacity(0.15)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAIHeader(),
              const SizedBox(height: 20),
              _buildHealthSummary(),
              const SizedBox(height: 20),
              _buildGlucosePatternAnalysis(),
              const SizedBox(height: 16),
              _buildExerciseGlucoseRelationship(),
              const SizedBox(height: 16),
              _buildSleepStressImpact(),
              const SizedBox(height: 16),
              _buildHydrationLifestyle(),
              const SizedBox(height: 16),
              _buildWeekComparison(),
              if (_hasWeekComparison()) ...[const SizedBox(height: 16)],
              _buildEducationalInsights(),
              const SizedBox(height: 20),
              _buildAIRecommendations(),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
      ],
    );
  }

  Widget _buildAIHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.purple.withOpacity(0.1),
          Colors.blue.withOpacity(0.1)
        ]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.smart_toy, color: Colors.purple, size: 24)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              _aiAnalysis?['review_status'] == 'unverified_ai_draft'
                  ? 'AI draft — clinician review needed'
                  : 'Recorded data summary',
              style: AppTextStyles.heading4
                  .copyWith(color: Colors.purple, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(_aiAnalysis!['generated_by'] ?? 'Recorded data',
              style: AppTextStyles.caption
                  .copyWith(color: Colors.purple.withOpacity(0.7))),
        ])),
        const Icon(Icons.info_outline, color: Colors.purple, size: 20),
      ]),
    );
  }

  Widget _buildHealthSummary() {
    final summary = _aiAnalysis!['health_summary'] ?? '';
    if (summary.toString().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.purple.withOpacity(0.08),
            Colors.blue.withOpacity(0.08)
          ]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withOpacity(0.1))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📋', style: TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(summary,
                style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.5,
                    fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _buildGlucosePatternAnalysis() {
    final data = _aiAnalysis!['glucose_pattern_analysis'];
    if (data == null || data.isEmpty) return const SizedBox.shrink();
    return _buildAnalysisCard(
        title: '📊 Deep Glucose Pattern Analysis',
        icon: Icons.bloodtype,
        color: Colors.red,
        children: [
          if (data['morning_vs_evening']?.toString().isNotEmpty == true)
            _buildInsightRow('🌅 Morning vs Evening',
                data['morning_vs_evening'], Colors.orange),
          if (data['best_day_explanation']?.toString().isNotEmpty == true)
            _buildInsightRow('✅ Best Day Analysis',
                data['best_day_explanation'], Colors.green),
          if (data['worst_day_explanation']?.toString().isNotEmpty == true)
            _buildInsightRow('⚠️ Worst Day Analysis',
                data['worst_day_explanation'], Colors.red),
          if (data['variability_concern']?.toString().isNotEmpty == true)
            _buildInsightRow('📈 Variability Concern',
                data['variability_concern'], Colors.purple),
        ]);
  }

  Widget _buildExerciseGlucoseRelationship() {
    final data = _aiAnalysis!['exercise_glucose_relationship'];
    if (data == null || data.isEmpty) return const SizedBox.shrink();
    return _buildAnalysisCard(
        title: '🏃 Exercise-Glucose Relationship',
        icon: Icons.fitness_center,
        color: Colors.green,
        children: [
          if (data['impact_summary']?.toString().isNotEmpty == true)
            _buildInsightRow(
                '💪 Impact Summary', data['impact_summary'], Colors.green),
          if (data['optimal_timing']?.toString().isNotEmpty == true)
            _buildInsightRow(
                '⏰ Optimal Timing', data['optimal_timing'], Colors.blue),
          if (data['intensity_recommendation']?.toString().isNotEmpty == true)
            _buildInsightRow('🎯 Intensity Guide',
                data['intensity_recommendation'], Colors.orange),
        ]);
  }

  Widget _buildSleepStressImpact() {
    final data = _aiAnalysis!['sleep_stress_impact'];
    if (data == null || data.isEmpty) return const SizedBox.shrink();
    return _buildAnalysisCard(
        title: '😴 Sleep & Stress Impact',
        icon: Icons.bedtime,
        color: Colors.indigo,
        children: [
          if (data['sleep_glucose_link']?.toString().isNotEmpty == true)
            _buildInsightRow('🛌 Sleep-Glucose Link',
                data['sleep_glucose_link'], Colors.indigo),
          if (data['stress_correlation']?.toString().isNotEmpty == true)
            _buildInsightRow('🧘 Stress Correlation',
                data['stress_correlation'], Colors.purple),
          if (data['improvement_tip']?.toString().isNotEmpty == true)
            _buildInsightRow(
                '💡 Improvement Tip', data['improvement_tip'], Colors.green),
        ]);
  }

  Widget _buildHydrationLifestyle() {
    final data = _aiAnalysis!['hydration_lifestyle'];
    if (data == null || data.isEmpty) return const SizedBox.shrink();
    return _buildAnalysisCard(
        title: '💧 Hydration & Lifestyle Factors',
        icon: Icons.water_drop,
        color: Colors.blue,
        children: [
          if (data['water_glucose_relationship']?.toString().isNotEmpty == true)
            _buildInsightRow('💦 Water-Glucose Link',
                data['water_glucose_relationship'], Colors.blue),
          if (data['lifestyle_score']?.toString().isNotEmpty == true)
            _buildLifestyleScore(data['lifestyle_score']),
          if (data['key_habit_to_improve']?.toString().isNotEmpty == true)
            _buildInsightRow('🎯 Key Habit to Improve',
                data['key_habit_to_improve'], Colors.orange),
        ]);
  }

  Widget _buildLifestyleScore(String score) {
    Color scoreColor;
    IconData scoreIcon;
    switch (score.toLowerCase()) {
      case 'excellent':
        scoreColor = Colors.green;
        scoreIcon = Icons.star;
        break;
      case 'good':
        scoreColor = Colors.lightGreen;
        scoreIcon = Icons.thumb_up;
        break;
      case 'fair':
        scoreColor = Colors.orange;
        scoreIcon = Icons.trending_flat;
        break;
      default:
        scoreColor = Colors.red;
        scoreIcon = Icons.warning;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(scoreIcon, color: scoreColor, size: 18)),
        const SizedBox(width: 10),
        Text('Lifestyle Score: ',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scoreColor.withOpacity(0.3))),
            child: Text(score.toUpperCase(),
                style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13))),
      ]),
    );
  }

  bool _hasWeekComparison() {
    final comparison = _aiAnalysis!['week_comparison'];
    if (comparison == null || comparison.isEmpty) return false;
    final trend = comparison['trend_direction'] ?? '';
    return trend.isNotEmpty && !trend.contains('No previous data');
  }

  Widget _buildWeekComparison() {
    final comparison = _aiAnalysis!['week_comparison'];
    if (comparison == null || comparison.isEmpty || !_hasWeekComparison())
      return const SizedBox.shrink();
    return _buildAnalysisCard(
        title: '📊 Week-over-Week Comparison',
        icon: Icons.compare_arrows,
        color: Colors.teal,
        children: [
          if (comparison['trend_direction']?.toString().isNotEmpty == true)
            _buildTrendDirection(comparison['trend_direction']),
          if (comparison['key_improvement']?.toString().isNotEmpty == true)
            _buildInsightRow('📈 Key Improvement',
                comparison['key_improvement'], Colors.green),
          if (comparison['key_decline']?.toString().isNotEmpty == true)
            _buildInsightRow(
                '📉 Key Decline', comparison['key_decline'], Colors.red),
        ]);
  }

  Widget _buildTrendDirection(String trend) {
    Color trendColor;
    IconData trendIcon;
    final lower = trend.toLowerCase();
    if (lower.contains('improv')) {
      trendColor = Colors.green;
      trendIcon = Icons.trending_up;
    } else if (lower.contains('declin') || lower.contains('worsen')) {
      trendColor = Colors.red;
      trendIcon = Icons.trending_down;
    } else {
      trendColor = Colors.orange;
      trendIcon = Icons.trending_flat;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: trendColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(trendIcon, color: trendColor, size: 18)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(trend,
                style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14))),
      ]),
    );
  }

  Widget _buildEducationalInsights() {
    final data = _aiAnalysis!['educational_insights'];
    if (data == null || data.isEmpty) return const SizedBox.shrink();
    return _buildAnalysisCard(
        title: '📚 Educational Insights',
        icon: Icons.school,
        color: Colors.amber.shade700,
        children: [
          if (data['key_learning']?.toString().isNotEmpty == true)
            _buildInsightRow(
                '🧠 Key Learning', data['key_learning'], Colors.blue),
          if (data['practical_tip']?.toString().isNotEmpty == true)
            _buildInsightRow(
                '💡 Practical Tip', data['practical_tip'], Colors.green),
          if (data['myth_or_fact']?.toString().isNotEmpty == true)
            _buildInsightRow(
                '❓ Myth or Fact', data['myth_or_fact'], Colors.purple),
        ]);
  }

  Widget _buildAIRecommendations() {
    final recommendations = _aiAnalysis!['recommendations'];
    if (recommendations == null ||
        (recommendations is List && recommendations.isEmpty))
      return const SizedBox.shrink();
    List<String> recs = recommendations is List
        ? recommendations.map((r) => r.toString()).toList()
        : [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
              child:
                  const Icon(Icons.checklist, color: Colors.green, size: 18)),
          const SizedBox(width: 10),
          Text('🎯 AI Recommendations',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.green.shade700, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        ...recs.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 4),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.green.shade400,
                          Colors.green.shade600
                        ]),
                        borderRadius: BorderRadius.circular(13)),
                    child: Center(
                        child: Text('${entry.key + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)))),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(entry.value,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary, height: 1.4))),
              ]),
            )),
      ]),
    );
  }

  Widget _buildAnalysisCard(
      {required String title,
      required IconData icon,
      required Color color,
      required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.12))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, color: color, size: 16)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: color, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _buildInsightRow(String label, String content, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: AppTextStyles.caption
                .copyWith(color: color, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        const Text('•', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(content,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary, height: 1.4))),
      ]),
    );
  }

  // ═══════════════════════════════════════
  // NEW: HEALTH SCORE GAUGE
  // ═══════════════════════════════════════

  Widget _buildHealthScoreGauge() {
    final score = _aiAnalysis?['health_score'];
    if (score == null || (score is Map && score.isEmpty))
      return const SizedBox.shrink();

    final total = (score['total'] ?? 0).toDouble();
    final glucoseControl = (score['glucose_control'] ?? 0).toDouble();
    final lifestyle = (score['lifestyle'] ?? 0).toDouble();
    final consistency = (score['consistency'] ?? 0).toDouble();

    Color scoreColor;
    String scoreLabel;
    if (total >= 80) {
      scoreColor = Colors.green;
      scoreLabel = 'Excellent';
    } else if (total >= 60) {
      scoreColor = Colors.lightGreen;
      scoreLabel = 'Good';
    } else if (total >= 40) {
      scoreColor = Colors.orange;
      scoreLabel = 'Fair';
    } else {
      scoreColor = Colors.red;
      scoreLabel = 'Needs Attention';
    }

    return AnimatedBuilder(
      animation: _scoreAnimationController,
      builder: (context, child) {
        final animatedValue = _scoreAnimationController.value * total;
        return CustomCard(
          padding: const EdgeInsets.all(24),
          borderRadius: BorderRadius.circular(20),
          elevation: 3,
          backgroundColor: scoreColor.withOpacity(0.03),
          child: Column(children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.speed, color: scoreColor, size: 24)),
              const SizedBox(width: 12),
              Text('Health Score',
                  style: AppTextStyles.heading4.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: scoreColor,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(scoreLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13))),
            ]),
            const SizedBox(height: 24),
            SizedBox(
                width: 160,
                height: 160,
                child: Stack(alignment: Alignment.center, children: [
                  CustomPaint(
                      size: const Size(160, 160),
                      painter: _GaugePainter(
                          value: animatedValue / 100,
                          color: scoreColor,
                          backgroundColor: Colors.grey.withOpacity(0.1))),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedBuilder(
                        animation: _scoreAnimationController,
                        builder: (context, child) => Text(
                            '${animatedValue.toInt()}',
                            style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: scoreColor))),
                    Text('/100',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ]),
                ])).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Row(children: [
              _buildScoreItem(
                  'Glucose\nControl', glucoseControl.toInt(), 40, Colors.red),
              const SizedBox(width: 8),
              _buildScoreItem('Lifestyle', lifestyle.toInt(), 30, Colors.blue),
              const SizedBox(width: 8),
              _buildScoreItem(
                  'Consistency', consistency.toInt(), 30, Colors.green),
            ]),
          ]),
        );
      },
    );
  }

  Widget _buildScoreItem(String label, int value, int max, Color color) {
    final ratio = max > 0 ? value / max : 0.0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.15))),
        child: Column(children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6)),
          const SizedBox(height: 6),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary, fontSize: 10),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════
  // NEW: RISK LEVEL INDICATOR
  // ═══════════════════════════════════════

  Widget _buildRiskLevelIndicator() {
    final riskLevel = _aiAnalysis?['risk_level'] ?? 'not_assessed';
    final riskExplanation = _aiAnalysis?['risk_explanation'] ?? '';

    if (riskLevel == 'insufficient_data') {
      return _buildInsufficientDataCard();
    }
    if (!['low', 'medium', 'high'].contains(riskLevel)) {
      return CustomCard(
        padding: const EdgeInsets.all(16),
        child: Text(
            'Risk not assessed. Review your recorded readings with your healthcare professional.',
            style: AppTextStyles.bodyMedium),
      );
    }

    Color riskColor;
    IconData riskIcon;
    String riskLabel;
    switch (riskLevel.toString().toLowerCase()) {
      case 'low':
        riskColor = Colors.green;
        riskIcon = Icons.shield;
        riskLabel = 'Low Risk';
        break;
      case 'high':
        riskColor = Colors.red;
        riskIcon = Icons.warning_amber;
        riskLabel = 'High Risk';
        break;
      default:
        riskColor = Colors.orange;
        riskIcon = Icons.info_outline;
        riskLabel = 'Medium Risk';
    }

    return CustomCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      backgroundColor: riskColor.withOpacity(0.05),
      border: Border.all(color: riskColor.withOpacity(0.2)),
      child: Row(children: [
        AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) => Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: riskColor
                        .withOpacity(0.15 + (_pulseController.value * 0.1)),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(riskIcon, color: riskColor, size: 28))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(riskLabel,
              style: TextStyle(
                  color: riskColor, fontWeight: FontWeight.bold, fontSize: 16)),
          if (riskExplanation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(riskExplanation,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary, height: 1.3))
          ],
        ])),
      ]),
    );
  }

  Widget _buildInsufficientDataCard() {
    return CustomCard(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      backgroundColor: Colors.orange.withOpacity(0.05),
      border: Border.all(color: Colors.orange.withOpacity(0.2)),
      child: Column(children: [
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
            child:
                const Icon(Icons.data_usage, color: Colors.orange, size: 40)),
        const SizedBox(height: 16),
        Text('Insufficient Data for AI Analysis',
            style: AppTextStyles.heading4
                .copyWith(color: Colors.orange, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
            'You need at least 3 days of complete tracking data for AI-powered insights.\nCurrently: ${_getDaysCount()} day(s).',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _buildDataRequirementDot(1, _getDaysCount() >= 1),
          _buildDataRequirementLine(),
          _buildDataRequirementDot(2, _getDaysCount() >= 2),
          _buildDataRequirementLine(),
          _buildDataRequirementDot(3, _getDaysCount() >= 3),
        ]),
        const SizedBox(height: 12),
        Text('Track more days to unlock AI analysis',
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
      ]),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildDataRequirementDot(int day, bool completed) {
    return Column(children: [
      Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: completed ? Colors.green : Colors.grey.withOpacity(0.2),
              shape: BoxShape.circle),
          child: Center(
              child: completed
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text('$day',
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold)))),
      const SizedBox(height: 4),
      Text('Day $day',
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textHint, fontSize: 10)),
    ]);
  }

  Widget _buildDataRequirementLine() {
    return Container(
        width: 30,
        height: 2,
        color: Colors.grey.withOpacity(0.3),
        margin: const EdgeInsets.only(bottom: 20));
  }

  // ═══════════════════════════════════════
  // NEW: CORRELATION INSIGHTS
  // ═══════════════════════════════════════

  Widget _buildCorrelationInsights() {
    final corr = _aiAnalysis?['correlation_insights'];
    if (corr == null || (corr is Map && corr.isEmpty))
      return const SizedBox.shrink();

    return CustomCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      backgroundColor: Colors.teal.withOpacity(0.04),
      border: Border.all(color: Colors.teal.withOpacity(0.15)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.insights, color: Colors.teal, size: 20)),
          const SizedBox(width: 10),
          Text('Correlation Insights',
              style: AppTextStyles.heading4
                  .copyWith(color: Colors.teal, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        if (corr['strongest_factor']?.toString().isNotEmpty == true)
          _buildCorrelationItem(
              '🎯 Strongest Factor', corr['strongest_factor'], Colors.teal),
        if (corr['improvement_area']?.toString().isNotEmpty == true)
          _buildCorrelationItem(
              '💡 Easiest Win', corr['improvement_area'], Colors.green),
      ]),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildCorrelationItem(String label, String content, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label: ',
            style: AppTextStyles.bodySmall
                .copyWith(color: color, fontWeight: FontWeight.w600)),
        Expanded(
            child: Text(content,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary, height: 1.3))),
      ]),
    );
  }

  // ═══════════════════════════════════════
  // NEW: ACTION PRIORITY MATRIX
  // ═══════════════════════════════════════

  Widget _buildActionMatrix() {
    final matrix = _aiAnalysis?['action_matrix'];
    if (matrix == null || (matrix is Map && matrix.isEmpty))
      return const SizedBox.shrink();

    final urgentImportant = matrix['urgent_important'] as List? ?? [];
    final importantNotUrgent = matrix['important_not_urgent'] as List? ?? [];
    final quickWins = matrix['quick_wins'] as List? ?? [];

    if (urgentImportant.isEmpty &&
        importantNotUrgent.isEmpty &&
        quickWins.isEmpty) return const SizedBox.shrink();

    return CustomCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.grid_view,
                  color: AppColors.primary, size: 20)),
          const SizedBox(width: 10),
          Text('Action Priority Matrix',
              style: AppTextStyles.heading4.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        if (urgentImportant.isNotEmpty) ...[
          _buildMatrixSection(
              '🔴 Urgent & Important', urgentImportant, Colors.red),
          const SizedBox(height: 12)
        ],
        if (importantNotUrgent.isNotEmpty) ...[
          _buildMatrixSection(
              '🟡 Important, Not Urgent', importantNotUrgent, Colors.orange),
          const SizedBox(height: 12)
        ],
        if (quickWins.isNotEmpty)
          _buildMatrixSection('🟢 Quick Wins', quickWins, Colors.green),
      ]),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildMatrixSection(String title, List items, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: AppTextStyles.bodySmall
                .copyWith(color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('• ',
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.bold)),
                Expanded(
                    child: Text(item.toString(),
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary, height: 1.3))),
              ]),
            )),
      ]),
    );
  }

  // ═══════════════════════════════════════
  // METRIC BUILDERS
  // ═══════════════════════════════════════

  Widget _buildMetricRow(String parameter, String averageValue,
      String targetRange, String status) {
    Color statusColor;
    switch (status) {
      case 'Optimal':
      case 'Excellent':
      case 'Adequate':
      case 'Normal':
      case 'Balanced':
        statusColor = AppColors.success;
        break;
      case 'Acceptable':
      case 'Manageable':
      case 'Moderate':
        statusColor = AppColors.warning;
        break;
      default:
        statusColor = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight)),
      child: Row(children: [
        Expanded(
            flex: 2,
            child: Text(parameter,
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600))),
        Expanded(
            flex: 2,
            child: Text(averageValue,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textPrimary))),
        Expanded(
            flex: 2,
            child: Text(targetRange,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary))),
        Expanded(
            flex: 2,
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3))),
                child: Text(status,
                    style: AppTextStyles.caption.copyWith(
                        color: statusColor, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center))),
      ]),
    );
  }

  Widget _buildLifestyleMetricRow(String factor, String weeklyAverage,
      String recommendation, String assessment) {
    Color color;
    switch (assessment) {
      case 'Excellent':
      case 'Optimal':
      case 'Adequate':
      case 'Balanced':
        color = AppColors.success;
        break;
      case 'Manageable':
      case 'Moderate':
        color = AppColors.warning;
        break;
      default:
        color = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight)),
      child: Row(children: [
        Expanded(
            flex: 2,
            child: Text(factor,
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600))),
        Expanded(
            flex: 2,
            child: Text(weeklyAverage,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textPrimary))),
        Expanded(
            flex: 2,
            child: Text(recommendation,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary))),
        Expanded(
            flex: 2,
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.3))),
                child: Text(assessment,
                    style: AppTextStyles.caption
                        .copyWith(color: color, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center))),
      ]),
    );
  }

  Widget _buildDailyLogs() {
    if (reportData == null || reportData!['daily_logs'] == null)
      return const SizedBox();
    List logs = reportData!['daily_logs'] ?? [];
    if (logs.isEmpty)
      return Container(
          padding: const EdgeInsets.all(20),
          child: const Text('No daily logs available'));
    return Column(
      children: logs.map((log) {
        String status = log['status'] ?? 'Normal';
        Color statusColor;
        switch (status) {
          case 'Excellent':
            statusColor = AppColors.success;
            break;
          case 'Good':
            statusColor = Colors.green;
            break;
          case 'Moderate':
            statusColor = AppColors.warning;
            break;
          default:
            statusColor = AppColors.error;
        }
        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderLight)),
          child: Row(children: [
            Expanded(
                child: Text(log['date'] ?? '-',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textPrimary))),
            Expanded(
                child: Text('${log['morning_glucose'] ?? '—'}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textPrimary))),
            Expanded(
                child: Text('${log['evening_glucose'] ?? '—'}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textPrimary))),
            Expanded(
                child: Text('${log['exercise_minutes'] ?? '—'}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textPrimary))),
            Expanded(
                child: Text('${log['sleep_hours'] ?? '—'}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textPrimary))),
            Expanded(
                child: Text('${log['water'] ?? '—'}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textPrimary))),
            Expanded(
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: statusColor.withOpacity(0.3))),
                    child: Text(status,
                        style: AppTextStyles.caption.copyWith(
                            color: statusColor, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center))),
          ]),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════
  // MAIN BUILD
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF38ADB6)]),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.analytics,
                  color: AppColors.white, size: 22)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Weekly Report',
                style: AppTextStyles.heading3.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
            if (reportData != null)
              Text('${_getDaysCount()} days analyzed',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ]),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: FilterChip(
              selected: _useAI,
              label: Text(_useAI ? 'AI On' : 'AI Off',
                  style: TextStyle(
                      color: _useAI ? Colors.white : AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              selectedColor: Colors.purple,
              checkmarkColor: Colors.white,
              backgroundColor: AppColors.background,
              side: BorderSide(
                  color: _useAI
                      ? Colors.purple
                      : AppColors.primary.withOpacity(0.3)),
              onSelected: (selected) => setState(() {
                _useAI = selected;
                reportData = null;
                _aiAnalysis = null;
              }),
              avatar: Icon(_useAI ? Icons.smart_toy : Icons.analytics,
                  size: 18, color: _useAI ? Colors.white : AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
          ),
          IconButton(
              onPressed: _selectDateRange,
              icon: const Icon(Icons.date_range, color: AppColors.primary),
              tooltip: 'Select Date Range'),
          IconButton(
              onPressed: _printOrSaveReport,
              icon: isPrinting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.print, color: AppColors.primary),
              tooltip: 'Print/Save Report'),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: fetchWeeklyReport,
              icon:
                  const Icon(Icons.refresh, color: AppColors.primary, size: 18),
              label: Text('Generate',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.primary)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 0),
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                      _useAI
                          ? 'Generating AI-enhanced report...'
                          : 'Generating report...',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                  if (_useAI) ...[
                    const SizedBox(height: 8),
                    Text('Analyzing health patterns',
                        style: AppTextStyles.caption
                            .copyWith(color: Colors.purple))
                  ],
                ]))
          : reportData == null
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  shape: BoxShape.circle),
                              child: Icon(Icons.analytics_outlined,
                                  size: 64,
                                  color: AppColors.primary.withOpacity(0.6)))
                          .animate()
                          .scale(duration: 600.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 20),
                      Text('Generate Your Report',
                          style: AppTextStyles.heading4.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('Select a date range and tap Generate',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary)),
                    ]))
              : RefreshIndicator(
                  onRefresh: fetchWeeklyReport,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Range Card
                          if (selectedStartDate != null &&
                              selectedEndDate != null)
                            CustomCard(
                              padding: const EdgeInsets.all(16),
                              borderRadius: BorderRadius.circular(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        '${DateFormat('MMM dd, yyyy').format(selectedStartDate!)} - ${DateFormat('MMM dd, yyyy').format(selectedEndDate!)}',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600)),
                                    Row(children: [
                                      if (_useAI)
                                        Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: Colors.purple
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: const Text('🤖 AI Enhanced',
                                                style: TextStyle(
                                                    color: Colors.purple,
                                                    fontSize: 11))),
                                      const SizedBox(width: 8),
                                      Text(
                                          '${selectedEndDate!.difference(selectedStartDate!).inDays + 1} days',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                  color:
                                                      AppColors.textSecondary)),
                                    ]),
                                  ]),
                            )
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .slideY(begin: -0.2, end: 0),

                          // Header Card
                          CustomCard(
                            padding: const EdgeInsets.all(20),
                            borderRadius: BorderRadius.circular(16),
                            elevation: 3,
                            child: Column(children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                    color: _useAI
                                        ? Colors.purple
                                        : AppColors.primary,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Row(children: [
                                  Icon(
                                      _useAI ? Icons.smart_toy : Icons.favorite,
                                      color: AppColors.white,
                                      size: 32),
                                  const SizedBox(width: 16),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text('NutriCare',
                                            style: AppTextStyles.heading2
                                                .copyWith(
                                                    color: AppColors.white)),
                                        Text(
                                            _useAI
                                                ? 'AI-Enhanced Analytics'
                                                : 'AI-Powered Health Analytics',
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                    color: AppColors.white
                                                        .withOpacity(0.9))),
                                        Text('Patient Health Report',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                    color: AppColors.white
                                                        .withOpacity(0.8))),
                                      ])),
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                            'Report ID: ${reportData?['report_id'] ?? 'N/A'}',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                    color: AppColors.white
                                                        .withOpacity(0.8))),
                                        Text(
                                            'Generated: ${reportData?['generated_at'] ?? '-'}',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                    color: AppColors.white
                                                        .withOpacity(0.8))),
                                      ]),
                                ]),
                              ),
                            ]),
                          )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 24),

                          // Report Info Card
                          CustomCard(
                            padding: const EdgeInsets.all(20),
                            borderRadius: BorderRadius.circular(16),
                            elevation: 3,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.analytics,
                                        color: AppColors.primary, size: 24),
                                    const SizedBox(width: 12),
                                    Text('Weekly Health Analysis Report',
                                        style: AppTextStyles.heading4.copyWith(
                                            color: AppColors.textPrimary))
                                  ]),
                                  const SizedBox(height: 16),
                                  Text(
                                      'Reporting Period: ${reportData?['start_date']} to ${reportData?['end_date']}',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Data Collection: ${reportData?['compliance'] ?? 'N/A'}',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                          color: AppColors.textSecondary)),
                                ]),
                          )
                              .animate()
                              .fadeIn(duration: 600.ms, delay: 200.ms)
                              .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 16),

                          // ═══ NEW: Health Score (AI only) ═══
                          if (_useAI && _aiAnalysis != null) ...[
                            _buildHealthScoreGauge()
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 250.ms)
                                .scale(
                                    begin: const Offset(0.9, 0.9),
                                    end: const Offset(1, 1)),
                            const SizedBox(height: 16),
                          ],

                          // ═══ NEW: Risk Level (AI only) ═══
                          if (_useAI && _aiAnalysis != null) ...[
                            _buildRiskLevelIndicator()
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 300.ms)
                                .slideX(begin: -0.3, end: 0),
                            const SizedBox(height: 16),
                          ],

                          // Executive Summary
                          CustomCard(
                            padding: const EdgeInsets.all(20),
                            borderRadius: BorderRadius.circular(16),
                            elevation: 3,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Executive Summary',
                                      style: AppTextStyles.heading4.copyWith(
                                          color: AppColors.textPrimary)),
                                  const SizedBox(height: 16),
                                  Row(children: [
                                    Expanded(
                                        child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                    color: AppColors.primary
                                                        .withOpacity(0.2))),
                                            child: Column(children: [
                                              const Icon(Icons.description,
                                                  color: AppColors.primary,
                                                  size: 32),
                                              const SizedBox(height: 8),
                                              Text(_getComplianceText(),
                                                  style: AppTextStyles.heading4
                                                      .copyWith(
                                                          color: AppColors
                                                              .primary)),
                                              Text('Monitoring Compliance',
                                                  style: AppTextStyles.bodySmall
                                                      .copyWith(
                                                          color: AppColors
                                                              .textSecondary))
                                            ]))),
                                    const SizedBox(width: 16),
                                    Expanded(
                                        child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                                color: _getTrendColor()
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                    color: _getTrendColor()
                                                        .withOpacity(0.2))),
                                            child: Column(children: [
                                              Icon(_getTrendIcon(),
                                                  color: _getTrendColor(),
                                                  size: 32),
                                              const SizedBox(height: 8),
                                              Text(_getTrendText(),
                                                  style: AppTextStyles.heading4
                                                      .copyWith(
                                                          color:
                                                              _getTrendColor())),
                                              Text('Weekly Trend',
                                                  style: AppTextStyles.bodySmall
                                                      .copyWith(
                                                          color: AppColors
                                                              .textSecondary))
                                            ]))),
                                  ]),
                                ]),
                          )
                              .animate()
                              .fadeIn(duration: 600.ms, delay: 400.ms)
                              .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 16),

                          // Clinical Metrics
                          CustomCard(
                            padding: const EdgeInsets.all(20),
                            borderRadius: BorderRadius.circular(16),
                            elevation: 3,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Section 1: CLINICAL METRICS',
                                      style: AppTextStyles.heading4.copyWith(
                                          color: AppColors.textPrimary)),
                                  const SizedBox(height: 20),
                                  Text('1.1 Blood Glucose Analysis',
                                      style: AppTextStyles.heading4
                                          .copyWith(color: AppColors.primary)),
                                  const SizedBox(height: 16),
                                  Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Row(children: [
                                        Expanded(
                                            flex: 2,
                                            child: Text('Parameter',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                        Expanded(
                                            flex: 2,
                                            child: Text('Average Value',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                        Expanded(
                                            flex: 2,
                                            child: Text('Target Range',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                        Expanded(
                                            flex: 2,
                                            child: Text('Status',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                      ])),
                                  ...(reportData?['clinical_metrics']
                                              as List? ??
                                          [])
                                      .map((metric) => _buildMetricRow(
                                          metric['parameter'] ?? '-',
                                          metric['average_value'] ?? '-',
                                          metric['target_range'] ?? '-',
                                          metric['status'] ?? '-'))
                                      .toList(),
                                  const SizedBox(height: 20),
                                  Text('1.2 Lifestyle & Wellness Metrics',
                                      style: AppTextStyles.heading4
                                          .copyWith(color: AppColors.primary)),
                                  const SizedBox(height: 16),
                                  Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Row(children: [
                                        Expanded(
                                            flex: 2,
                                            child: Text('Factor',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                        Expanded(
                                            flex: 2,
                                            child: Text('Weekly Average',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                        Expanded(
                                            flex: 2,
                                            child: Text('Recommendation',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                        Expanded(
                                            flex: 2,
                                            child: Text('Assessment',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                      ])),
                                  ...(reportData?['lifestyle_metrics']
                                              as List? ??
                                          [])
                                      .map((metric) => _buildLifestyleMetricRow(
                                          metric['factor'] ?? '-',
                                          metric['weekly_average'] ?? '-',
                                          metric['recommendation'] ?? '-',
                                          metric['assessment'] ?? '-'))
                                      .toList(),
                                ]),
                          )
                              .animate()
                              .fadeIn(duration: 600.ms, delay: 600.ms)
                              .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 16),

                          // ═══ NEW: Correlation Insights (AI only) ═══
                          if (_useAI && _aiAnalysis != null) ...[
                            _buildCorrelationInsights(),
                            const SizedBox(height: 16),
                          ],

                          // ═══ NEW: Action Matrix (AI only) ═══
                          if (_useAI && _aiAnalysis != null) ...[
                            _buildActionMatrix(),
                            const SizedBox(height: 16),
                          ],

                          // Comparative Analysis
                          if (reportData?['best_day'] != null &&
                              reportData?['worst_day'] != null)
                            CustomCard(
                              padding: const EdgeInsets.all(20),
                              borderRadius: BorderRadius.circular(16),
                              elevation: 3,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Section 2: COMPARATIVE ANALYSIS',
                                        style: AppTextStyles.heading4.copyWith(
                                            color: AppColors.textPrimary)),
                                    const SizedBox(height: 16),
                                    Row(children: [
                                      Expanded(
                                          child: Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                  color: AppColors.success
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: AppColors.success
                                                          .withOpacity(0.2))),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(children: [
                                                      const Icon(
                                                          Icons.check_circle,
                                                          color:
                                                              AppColors.success,
                                                          size: 24),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                          '2.1 OPTIMAL PERFORMANCE',
                                                          style: AppTextStyles
                                                              .bodyMedium
                                                              .copyWith(
                                                                  color: AppColors
                                                                      .success,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600))
                                                    ]),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                        'Date: ${reportData!['best_day']['date']}',
                                                        style: AppTextStyles
                                                            .bodySmall
                                                            .copyWith(
                                                                color: AppColors
                                                                    .textSecondary)),
                                                    Text(
                                                        'Average Blood Glucose: ${reportData!['best_day']['avg_glucose']} mg/dL',
                                                        style: AppTextStyles
                                                            .bodySmall
                                                            .copyWith(
                                                                color: AppColors
                                                                    .textSecondary)),
                                                    const SizedBox(height: 8),
                                                    Text('Positive Contributing Factors:',
                                                        style: AppTextStyles
                                                            .bodySmall
                                                            .copyWith(
                                                                color: AppColors
                                                                    .textPrimary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600)),
                                                    Text(
                                                        '• Regular exercise routine',
                                                        style: AppTextStyles
                                                            .bodySmall
                                                            .copyWith(
                                                                color: AppColors
                                                                    .textSecondary)),
                                                    Text(
                                                        '• Proper hydration habits',
                                                        style: AppTextStyles
                                                            .bodySmall
                                                            .copyWith(
                                                                color: AppColors
                                                                    .textSecondary)),
                                                    Text(
                                                        '• Adequate sleep schedule',
                                                        style: AppTextStyles
                                                            .bodySmall
                                                            .copyWith(
                                                                color: AppColors
                                                                    .textSecondary)),
                                                  ]))),
                                      const SizedBox(width: 16),
                                      Expanded(
                                          child: Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                  color: AppColors.error
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: AppColors.error
                                                          .withOpacity(0.2))),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(children: [
                                                      const Icon(Icons.warning,
                                                          color:
                                                              AppColors.error,
                                                          size: 24),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                          '2.2 REQUIRES ATTENTION',
                                                          style: AppTextStyles
                                                              .bodyMedium
                                                              .copyWith(
                                                                  color:
                                                                      AppColors
                                                                          .error,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600))
                                                    ]),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                        'Date: ${reportData!['worst_day']['date']}',
                                                        style: AppTextStyles
                                                            .bodySmall
                                                            .copyWith(
                                                                color: AppColors
                                                                    .textSecondary)),
                                                    Text(
                                                        'Average Blood Glucose: ${reportData!['worst_day']['avg_glucose']} mg/dL',
                                                        style: AppTextStyles
                                                            .bodySmall
                                                            .copyWith(
                                                                color: AppColors
                                                                    .textSecondary)),
                                                    const SizedBox(height: 8),
                                                    Text('Risk Factors Identified:',
                                                        style: AppTextStyles
                                                            .bodySmall
                                                            .copyWith(
                                                                color: AppColors
                                                                    .textPrimary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600)),
                                                    Text(
                                                        '• Irregular exercise pattern',
                                                        style: AppTextStyles
                                                            .bodySmall
                                                            .copyWith(
                                                                color: AppColors
                                                                    .textSecondary)),
                                                    Text(
                                                        '• Inadequate water intake',
                                                        style: AppTextStyles
                                                            .bodySmall
                                                            .copyWith(
                                                                color: AppColors
                                                                    .textSecondary)),
                                                    Text('• Poor sleep quality',
                                                        style: AppTextStyles
                                                            .bodySmall
                                                            .copyWith(
                                                                color: AppColors
                                                                    .textSecondary)),
                                                  ]))),
                                    ]),
                                  ]),
                            )
                                .animate()
                                .fadeIn(duration: 600.ms, delay: 800.ms)
                                .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 16),

                          // Daily Logs
                          CustomCard(
                            padding: const EdgeInsets.all(20),
                            borderRadius: BorderRadius.circular(16),
                            elevation: 3,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Section 3: DAILY LOG SUMMARY',
                                      style: AppTextStyles.heading4.copyWith(
                                          color: AppColors.textPrimary)),
                                  const SizedBox(height: 16),
                                  Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Row(children: [
                                        Expanded(
                                            child: Text('Date',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                        Expanded(
                                            child: Text('Morning',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                        Expanded(
                                            child: Text('Evening',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                        Expanded(
                                            child: Text('Exercise',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                        Expanded(
                                            child: Text('Sleep',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                        Expanded(
                                            child: Text('Water',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                        Expanded(
                                            child: Text('Status',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                      ])),
                                  _buildDailyLogs(),
                                ]),
                          )
                              .animate()
                              .fadeIn(duration: 600.ms, delay: 1000.ms)
                              .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 16),

                          // Achievements & Recommendations
                          Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Expanded(
                                    child: CustomCard(
                                  padding: const EdgeInsets.all(20),
                                  backgroundColor:
                                      AppColors.warning.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color:
                                          AppColors.warning.withOpacity(0.2)),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          const Icon(Icons.emoji_events,
                                              color: AppColors.warning,
                                              size: 24),
                                          const SizedBox(width: 8),
                                          Text('Section 4: ACHIEVEMENTS',
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                      color: AppColors.warning,
                                                      fontWeight:
                                                          FontWeight.w600))
                                        ]),
                                        const SizedBox(height: 12),
                                        ...(reportData?['achievements']
                                                    as List? ??
                                                ['No achievements recorded'])
                                            .map((achievement) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 4),
                                                child: Text(achievement,
                                                    style: AppTextStyles
                                                        .bodySmall
                                                        .copyWith(
                                                            color: AppColors
                                                                .textSecondary))))
                                            .toList(),
                                      ]),
                                )),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: CustomCard(
                                  padding: const EdgeInsets.all(20),
                                  backgroundColor:
                                      AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color:
                                          AppColors.success.withOpacity(0.2)),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          const Icon(Icons.check_circle,
                                              color: AppColors.success,
                                              size: 24),
                                          const SizedBox(width: 8),
                                          Text('Section 5: RECOMMENDATIONS',
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                      color: AppColors.success,
                                                      fontWeight:
                                                          FontWeight.w600))
                                        ]),
                                        const SizedBox(height: 12),
                                        Text(
                                            reportData?['recommendations'] ??
                                                'Continue maintaining healthy habits.',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                    color: AppColors
                                                        .textSecondary)),
                                      ]),
                                )),
                              ])
                              .animate()
                              .fadeIn(duration: 600.ms, delay: 1200.ms)
                              .slideY(begin: 0.2, end: 0),

                          // AI Analysis Section
                          _buildAIAnalysisSection(),

                          const SizedBox(height: 24),

                          // Disclaimer
                          CustomCard(
                            padding: const EdgeInsets.all(20),
                            backgroundColor:
                                AppColors.textHint.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.textHint.withOpacity(0.2)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('MEDICAL DISCLAIMER',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                          color: AppColors.textHint,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Text(
                                      'This report is computer-generated for informational purposes only and is not a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition.',
                                      style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textHint,
                                          height: 1.4)),
                                  const SizedBox(height: 16),
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            'Generated: ${reportData?['generated_at'] ?? '-'}',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                    color:
                                                        AppColors.textPrimary)),
                                        Text(
                                            'Report ID: ${reportData?['report_id'] ?? '-'}',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                    color:
                                                        AppColors.textPrimary)),
                                      ]),
                                  const SizedBox(height: 8),
                                  Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                          'NutriCare © 2025 Diabetes Management System v1.0',
                                          style: AppTextStyles.caption.copyWith(
                                              color: AppColors.textHint))),
                                ]),
                          )
                              .animate()
                              .fadeIn(duration: 600.ms, delay: 1400.ms)
                              .slideY(begin: 0.2, end: 0),
                        ]),
                  ),
                ),
    );
  }
}

// ═══════════════════════════════════════
// GAUGE PAINTER
// ═══════════════════════════════════════

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final Color backgroundColor;

  _GaugePainter(
      {required this.value,
      required this.color,
      required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi,
        math.pi, false, bgPaint);

    final valuePaint = Paint()
      ..color = color
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi,
        -math.pi + (math.pi * 2 * value.clamp(0.0, 1.0)), false, valuePaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}
