part of 'ledger_bloc.dart';

abstract class LedgerEvent extends Equatable {
  const LedgerEvent();

  @override
  List<Object?> get props => [];
}

class LedgerStarted extends LedgerEvent {
  const LedgerStarted();
}
