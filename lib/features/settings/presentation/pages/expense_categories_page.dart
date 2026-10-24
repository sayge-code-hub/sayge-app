import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/presentation/bloc/categories/expense_categories_bloc.dart';

class ExpenseCategoriesPage extends StatelessWidget {
  const ExpenseCategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<ExpenseCategoriesBloc>()..add(const ExpenseCategoriesStarted()),
      child: const _ExpenseCategoriesBody(),
    );
  }
}

class _ExpenseCategoriesBody extends StatefulWidget {
  const _ExpenseCategoriesBody();

  @override
  State<_ExpenseCategoriesBody> createState() => _ExpenseCategoriesBodyState();
}

class _ExpenseCategoriesBodyState extends State<_ExpenseCategoriesBody> {
  final _name = TextEditingController();
  String? _fieldError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _add() {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final name = _name.text.trim();
      if (name.isEmpty) {
        setState(() => _fieldError = 'Enter a category name.');
        return;
      }
      setState(() => _fieldError = null);
      context.read<ExpenseCategoriesBloc>().add(ExpenseCategoryAdded(name));
    });
  }

  Future<void> _rename(ExpenseCategory category) async {
    final next = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _RenameCategoryDialog(initial: category.name),
    );
    if (!mounted || next == null) return;
    final trimmed = next.trim();
    if (trimmed.isEmpty || trimmed == category.name) return;
    context.read<ExpenseCategoriesBloc>().add(
      ExpenseCategoryRenamed(id: category.id, name: trimmed),
    );
  }

  Future<void> _delete(ExpenseCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Text(
            'Delete category?',
            style: Theme.of(
              dialogContext,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          content: Text(
            '“${category.name}” will be removed from the expense form.',
            style: Theme.of(dialogContext).textTheme.bodyMedium,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (!mounted || confirmed != true) return;
    context.read<ExpenseCategoriesBloc>().add(
      ExpenseCategoryDeleted(category.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;
    final textTheme = Theme.of(context).textTheme;

    return BlocConsumer<ExpenseCategoriesBloc, ExpenseCategoriesState>(
      listenWhen: (prev, next) =>
          prev.saving && !next.saving && next.errorMessage == null,
      listener: (context, state) => _name.clear(),
      builder: (context, state) {
        final loading =
            state.status == ExpenseCategoriesStatus.initial ||
            state.status == ExpenseCategoriesStatus.loading;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            isDesktop ? 20 : 12,
            horizontal,
            32,
          ),
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'These names appear in the Category field on expenses.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textLight,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _name,
                            hintText: 'New category',
                            errorText: _fieldError ?? state.errorMessage,
                            enabled: !state.saving,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) {
                              if (_fieldError != null) {
                                setState(() => _fieldError = null);
                              }
                            },
                            onSubmitted: (_) => _add(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        AppButton(
                          label: 'Add',
                          expand: false,
                          isLoading: state.saving,
                          enabled: !state.saving && !loading,
                          onPressed: _add,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.text,
                          ),
                        ),
                      )
                    else if (state.status == ExpenseCategoriesStatus.failure)
                      const SizedBox.shrink()
                    else if (state.categories.isEmpty)
                      Text(
                        'No categories yet.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textLight,
                        ),
                      )
                    else ...[
                      for (final category in state.categories) ...[
                        AppListCard(
                          padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  category.name,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              AppListIconButton(
                                icon: Icons.edit_outlined,
                                tooltip: 'Rename',
                                onPressed: state.saving
                                    ? null
                                    : () => _rename(category),
                              ),
                              AppListIconButton(
                                icon: Icons.delete_outline,
                                tooltip: 'Delete',
                                onPressed: state.saving
                                    ? null
                                    : () => _delete(category),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RenameCategoryDialog extends StatefulWidget {
  const _RenameCategoryDialog({required this.initial});

  final String initial;

  @override
  State<_RenameCategoryDialog> createState() => _RenameCategoryDialogState();
}

class _RenameCategoryDialogState extends State<_RenameCategoryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text(
        'Rename category',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      content: AppTextField(
        controller: _controller,
        label: 'Name',
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => Navigator.of(context).pop(_controller.text),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
