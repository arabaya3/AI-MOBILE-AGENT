import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../spaces/application/space_controller.dart';
import '../data/documents_api.dart';
import 'documents_controller.dart';

class DocumentSelection {
  const DocumentSelection({
    this.ids = const [],
    this.names = const {},
    this.removed = const [],
  });

  /// Explicitly selected documents, in selection order. Empty means "all my ready documents".
  final List<String> ids;

  /// Names captured at selection time, so a document that vanishes can still be named.
  final Map<String, String> names;

  /// Names of documents taken out of the selection because they stopped being available.
  final List<String> removed;
}

/// Chat document selection for the current account and space. It never broadens silently:
/// documents that disappear or stop being ready are removed and reported in [DocumentSelection.removed].
class DocumentSelectionController extends Notifier<DocumentSelection> {
  @override
  DocumentSelection build() {
    ref.watch(spaceScopeProvider);
    ref.listen(documentsControllerProvider.select((s) => s.items), (_, items) {
      if (items != null) _prune(items);
    });
    return const DocumentSelection();
  }

  void toggle(DocumentItem document) {
    if (!document.isReady) return;
    final ids = [...state.ids];
    final names = {...state.names};
    if (ids.remove(document.id)) {
      names.remove(document.id);
    } else {
      ids.add(document.id);
      names[document.id] = document.filename;
    }
    state = DocumentSelection(ids: ids, names: names, removed: state.removed);
  }

  void remove(String id) => state = DocumentSelection(
    ids: state.ids.where((i) => i != id).toList(),
    names: {...state.names}..remove(id),
    removed: state.removed,
  );

  void clear() => state = const DocumentSelection();

  void acknowledgeRemoval() =>
      state = DocumentSelection(ids: state.ids, names: state.names);

  void _prune(List<DocumentItem> items) {
    final byId = {for (final d in items) d.id: d};
    final kept = state.ids.where((id) => byId[id]?.isReady ?? false).toList();
    if (kept.length == state.ids.length) return;
    final removed = [
      for (final id in state.ids)
        if (!kept.contains(id)) byId[id]?.filename ?? state.names[id] ?? '',
    ];
    state = DocumentSelection(
      ids: kept,
      names: {for (final id in kept) id: state.names[id] ?? ''},
      removed: [...state.removed, ...removed],
    );
  }
}

final documentSelectionProvider =
    NotifierProvider<DocumentSelectionController, DocumentSelection>(
      DocumentSelectionController.new,
    );
