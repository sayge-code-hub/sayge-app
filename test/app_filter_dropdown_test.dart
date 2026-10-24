import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/core/theme/app_theme.dart';
import 'package:sayge_app/core/widgets/app_filter_dropdown.dart';

void main() {
  testWidgets('filter dropdown matches status chip height', (tester) async {
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
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.standard,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppFilterDropdown.radius,
                      ),
                    ),
                    labelStyle: const TextStyle(fontSize: 12, height: 1),
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

    final chip = find.widgetWithText(FilterChip, 'All');
    final dropdown = find.byType(AppFilterDropdown<String?>);

    expect(tester.getSize(dropdown).height, AppFilterDropdown.height);
    expect(tester.getSize(chip).height, tester.getSize(dropdown).height);
    expect(tester.getTopLeft(chip).dy, tester.getTopLeft(dropdown).dy);
    expect(find.text('All clients'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _ignore(String? _) {}
