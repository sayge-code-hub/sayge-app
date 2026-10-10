part of 'profitability_bloc.dart';

abstract class ProfitabilityEvent extends Equatable {
  const ProfitabilityEvent();

  @override
  List<Object?> get props => [];
}

class ProfitabilityStarted extends ProfitabilityEvent {
  const ProfitabilityStarted();
}

class ProfitabilitySearchChanged extends ProfitabilityEvent {
  const ProfitabilitySearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class ProfitabilityFyChanged extends ProfitabilityEvent {
  const ProfitabilityFyChanged(this.fyStartYear);

  final int fyStartYear;

  @override
  List<Object?> get props => [fyStartYear];
}

class ProfitabilityExportRequested extends ProfitabilityEvent {
  const ProfitabilityExportRequested();
}
