import 'package:equatable/equatable.dart';

class Client extends Equatable {
  const Client({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}
