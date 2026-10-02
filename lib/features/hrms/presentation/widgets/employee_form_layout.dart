import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// When true, [EmployeeDetailField] right-aligns label and value.
class DetailFieldAlign extends InheritedWidget {
  const DetailFieldAlign({
    super.key,
    required this.end,
    required super.child,
  });

  final bool end;

  static bool of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DetailFieldAlign>()?.end ??
        false;
  }

  @override
  bool updateShouldNotify(DetailFieldAlign oldWidget) => end != oldWidget.end;
}

/// Two-column field grid used by add / detail employee screens.
class EmployeeFormGrid extends StatelessWidget {
  const EmployeeFormGrid({
    super.key,
    required this.children,
    required this.isDesktop,
    this.rowGap = 14,
    this.columnGap = 24,
  });

  final List<Widget> children;
  final bool isDesktop;
  final double rowGap;
  final double columnGap;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: rowGap),
            children[i],
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final left = children[i];
      final right = i + 1 < children.length ? children[i + 1] : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            SizedBox(width: columnGap),
            Expanded(
              child: right == null
                  ? const SizedBox.shrink()
                  : DetailFieldAlign(end: true, child: right),
            ),
          ],
        ),
      );
      if (i + 2 < children.length) {
        rows.add(SizedBox(height: rowGap));
      }
    }

    return Column(children: rows);
  }
}

/// Places up to two detail sections side-by-side on desktop.
class EmployeeDetailSectionRow extends StatelessWidget {
  const EmployeeDetailSectionRow({
    super.key,
    required this.isDesktop,
    required this.left,
    this.right,
    this.gap = 12,
  });

  final bool isDesktop;
  final Widget left;
  final Widget? right;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop || right == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          if (right != null) ...[
            SizedBox(height: gap),
            right!,
          ],
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          SizedBox(width: gap),
          Expanded(child: right!),
        ],
      ),
    );
  }
}

/// Grouped read-only section with a short title and field grid.
class EmployeeDetailSection extends StatelessWidget {
  const EmployeeDetailSection({
    super.key,
    required this.title,
    required this.children,
    required this.isDesktop,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final bool isDesktop;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 22 : 16,
        isDesktop ? 18 : 16,
        isDesktop ? 22 : 16,
        isDesktop ? 20 : 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.highlight,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          EmployeeFormGrid(
            isDesktop: isDesktop,
            children: children,
          ),
        ],
      ),
    );
  }
}

/// Read-only labeled value — plain text, no field chrome.
class EmployeeDetailField extends StatelessWidget {
  const EmployeeDetailField({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final display = value.trim().isEmpty ? '—' : value;
    final end = DetailFieldAlign.of(context);
    final align = end ? TextAlign.right : TextAlign.left;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment:
            end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textAlign: align,
            style: textTheme.labelLarge?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            display,
            textAlign: align,
            style: textTheme.bodyLarge?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky bottom action bar aligned to the right.
class EmployeeStickyActions extends StatelessWidget {
  const EmployeeStickyActions({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.border,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
