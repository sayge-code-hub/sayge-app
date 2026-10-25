import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/core/theme/app_theme.dart';
import 'package:sayge_app/core/widgets/app_filter_dropdown.dart';

void main() {
  testWidgets('filter dropdown uses shared control height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final label in ['All', 'Active', 'Draft', 'Exited'])
                  FilterChip(
                    label: Text(label),
                    selected: label == 'Active',
                    onSelected: (_) {},
                    showCheckmark: false,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    visualDensity: const VisualDensity(horizontal: 0, vertical: 0.5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppFilterDropdown.radius,
                      ),
                    ),
                    labelStyle: const TextStyle(fontSize: 13, height: 1.1),
                  ),
                const SizedBox(
                  width: 220,
                  child: AppFilterDropdown<String?>(
                    value: null,
                    options: [
                      AppFilterOption(value: null, label: 'All clients'),
                      AppFilterOption(
                        value: 'Mahindra Finance',
                        label: 'Mahindra Finance',
                      ),
                    ],
                    onChanged: _ignore,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final dropdown = find.byType(AppFilterDropdown<String?>);

    expect(AppFilterDropdown.height, 44);
    expect(tester.getSize(dropdown).height, AppFilterDropdown.height);
    expect(find.text('All clients'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _ignore(String? _) {}
