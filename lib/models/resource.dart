import 'resource_type.dart';

class Resource {
  final ResourceType type;
  int amount;
  final bool isPassable;

  Resource({
    required this.type,
    this.amount = 0,
    this.isPassable = true,
  });

  bool get isEmpty => amount <= 0;
}
