part of 'ledger_bloc.dart';

enum LedgerStatus { initial, loading, ready, failure }

class LedgerState extends Equatable {
  const LedgerState({
    this.status = LedgerStatus.initial,
    this.entries = const [],
    this.errorMessage,
  });

  final LedgerStatus status;
  final List<ActivityLogEntry> entries;
  final String? errorMessage;

  LedgerState copyWith({
    LedgerStatus? status,
    List<ActivityLogEntry>? entries,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LedgerState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, entries, errorMessage];
}
