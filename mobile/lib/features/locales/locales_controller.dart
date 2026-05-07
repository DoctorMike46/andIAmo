import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/locale_models.dart';
import 'data/locales_api.dart';

class LocalesQuery {
  const LocalesQuery({this.type, this.openNow = false});
  final String? type;
  final bool openNow;

  @override
  bool operator ==(Object other) =>
      other is LocalesQuery && other.type == type && other.openNow == openNow;

  @override
  int get hashCode => Object.hash(type, openNow);
}

final localesQueryProvider = StateProvider<LocalesQuery>((ref) => const LocalesQuery());

final localesListProvider = FutureProvider.autoDispose<List<LocaleSummary>>((ref) async {
  final query = ref.watch(localesQueryProvider);
  final api = ref.watch(localesApiProvider);
  return api.list(type: query.type, openNow: query.openNow);
});

final localeDetailProvider =
    FutureProvider.autoDispose.family<LocaleDetail, String>((ref, id) async {
  final api = ref.watch(localesApiProvider);
  return api.get(id);
});
