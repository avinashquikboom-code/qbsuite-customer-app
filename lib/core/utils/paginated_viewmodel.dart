import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PageResult<T> {
  PageResult({required List<T> items, this.nextCursor})
    : items = List.unmodifiable(items);
  final List<T> items;
  final String? nextCursor;
}

class PagedState<T> {
  PagedState({
    required List<T> items,
    this.nextCursor,
    this.loadingMore = false,
    this.moreError,
  }) : items = List.unmodifiable(items);
  final List<T> items;
  final String? nextCursor;
  final bool loadingMore;
  final Object? moreError;
}

/// Subclass in a feature and expose with AsyncNotifierProvider.autoDispose.
/// Implement fetchPage by delegating to the feature repository.
abstract class PaginatedViewModel<T> extends AsyncNotifier<PagedState<T>> {
  CancelToken? _cancel;
  int? _moreGeneration;
  int _generation = 0;
  Future<PageResult<T>> fetchPage(String? cursor, CancelToken cancelToken);
  @override
  Future<PagedState<T>> build() async {
    final generation = ++_generation;
    final cancel = _cancel = CancelToken();
    ref.onDispose(() {
      _generation++;
      cancel.cancel();
    });
    final page = await fetchPage(null, cancel);
    if (generation != _generation) throw StateError('Superseded request');
    return PagedState(items: page.items, nextCursor: page.nextCursor);
  }

  void refresh() {
    _cancel?.cancel();
    ref.invalidateSelf();
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (_moreGeneration == _generation ||
        current == null ||
        current.nextCursor == null) {
      return;
    }
    _moreGeneration = _generation;
    final generation = _generation;
    state = AsyncData(
      PagedState(
        items: current.items,
        nextCursor: current.nextCursor,
        loadingMore: true,
      ),
    );
    try {
      final page = await fetchPage(current.nextCursor, _cancel!);
      if (ref.mounted && generation == _generation) {
        state = AsyncData(
          PagedState(
            items: [...current.items, ...page.items],
            nextCursor: page.nextCursor,
          ),
        );
      }
    } catch (error) {
      if (ref.mounted && generation == _generation) {
        state = AsyncData(
          PagedState(
            items: current.items,
            nextCursor: current.nextCursor,
            moreError: error,
          ),
        );
      }
    } finally {
      if (_moreGeneration == generation) _moreGeneration = null;
    }
  }
}
