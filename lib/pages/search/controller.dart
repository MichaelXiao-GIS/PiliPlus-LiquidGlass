import 'dart:async';

import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/search/suggest.dart';
import 'package:PiliPlus/models_new/search/search_rcmd/data.dart';
import 'package:PiliPlus/models_new/search/search_trending/data.dart';
import 'package:PiliPlus/pages/search/suggestion_request.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stream_transform/stream_transform.dart';

mixin DebounceStreamMixin<T> {
  final Duration duration = const Duration(milliseconds: 200);
  StreamController<T>? ctr;
  StreamSubscription<T>? _sub;
  void onValueChanged(T value);

  void subInit() {
    _sub = (ctr = StreamController<T>()).stream
        .debounce(duration, trailing: true)
        .listen(onValueChanged);
  }

  void subDispose() {
    _sub?.cancel();
    ctr?.close();
    _sub = null;
    ctr = null;
  }
}

abstract class DebounceStreamState<T extends StatefulWidget, S> extends State<T>
    with DebounceStreamMixin<S> {
  @override
  void dispose() {
    subDispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    subInit();
  }
}

class BaseSearchController extends GetxController {
  final historyList = List<String>.from(
    GStorage.historyWord.get('cacheList') ?? const <String>[],
  ).obs;

  late final Rx<LoadingState<SearchTrendingData>> trendingState;

  final recordSearchHistory = Pref.recordSearchHistory.obs;
  final searchSuggestion = Pref.searchSuggestion;
  final enableTrending = Pref.enableTrending;
  final enableSearchRcmd = Pref.enableSearchRcmd;

  @override
  void onInit() {
    super.onInit();

    if (enableTrending) {
      trendingState = LoadingState<SearchTrendingData>.loading().obs;
      queryTrendingList();
    }
  }

  // 获取热搜关键词
  Future<void> queryTrendingList() async {
    trendingState.value = await SearchHttp.searchTrending(limit: 10);
  }
}

class SSearchController extends GetxController {
  SSearchController(this.tag);
  final String tag;

  final searchFocusNode = FocusNode();
  final controller = TextEditingController();
  final _baseCtr = Get.putOrFind(BaseSearchController.new);

  String? hintText;

  int initIndex = 0;

  // uid
  final RxBool showUidBtn = false.obs;

  // history
  RxBool get recordSearchHistory => _baseCtr.recordSearchHistory;
  RxList<String> get historyList => _baseCtr.historyList;

  // suggestion
  bool get searchSuggestion => _baseCtr.searchSuggestion;
  late final RxList<SearchSuggestItem> searchSuggestList;

  late final _suggestions = SuggestionRequest<LoadingState<SearchSuggestModel>>(
    (term) => SearchHttp.searchSuggest(term: term),
    (result) {
      if (result case Success(:final response)) {
        searchSuggestList.value = response.tag ?? [];
      }
    },
  );

  // trending
  bool get enableTrending => _baseCtr.enableTrending;
  Rx<LoadingState<SearchTrendingData>> get trendingState =>
      _baseCtr.trendingState;

  // rcmd
  bool get enableSearchRcmd => _baseCtr.enableSearchRcmd;
  late final Rx<LoadingState<SearchRcmdData>> recommendData;

  Future<void> Function() get queryTrendingList => _baseCtr.queryTrendingList;

  @override
  void onInit() {
    super.onInit();
    final params = Get.parameters;
    hintText = params['hintText'];
    final text = params['text'];
    if (text != null) {
      controller.text = text;
    }

    if (searchSuggestion) {
      searchSuggestList = <SearchSuggestItem>[].obs;
      if (text != null) _suggestions.update(text, immediate: true);
    }

    if (enableSearchRcmd) {
      recommendData = LoadingState<SearchRcmdData>.loading().obs;
      queryRecommendList();
    }
  }

  void validateUid() {
    showUidBtn.value = IdUtils.digitOnlyRegExp.hasMatch(controller.text);
  }

  void onChange(String value) {
    validateUid();
    if (searchSuggestion) {
      _suggestions.update(value);
      if (value.isEmpty) searchSuggestList.clear();
    }
  }

  void onClear() {
    if (controller.value.text != '') {
      controller.clear();
      if (searchSuggestion) {
        _suggestions.cancel();
        searchSuggestList.clear();
      }
      searchFocusNode.requestFocus();
      showUidBtn.value = false;
    } else {
      Get.back();
    }
  }

  // 搜索
  Future<void> submit() async {
    if (controller.text.isEmpty) {
      if (hintText.isNullOrEmpty) return;
      if (searchSuggestion) _suggestions.cancel();
      controller.text = hintText!;
      validateUid();
    }

    final text = controller.text;

    if (await PiliScheme.routePushFromUrl(text, selfHandle: true)) {
      return;
    }

    if (recordSearchHistory.value) {
      final index = historyList.indexOf(text);
      if (index != 0) {
        if (index != -1) historyList.removeAt(index);
        historyList.insert(0, text);
        GStorage.historyWord.put('cacheList', historyList);
      }
    }

    searchFocusNode.unfocus();
    Get.toNamed(
      '/searchResult',
      parameters: {'tag': tag, 'keyword': text},
      arguments: {'initIndex': initIndex, 'fromSearch': true},
    )?.then((val) {
      if (isClosed) return;
      searchFocusNode.requestFocus();
      if (searchSuggestion && val == true) {
        _suggestions.update(controller.text, immediate: true);
      }
    });
  }

  Future<void> queryRecommendList() async {
    recommendData.value = await SearchHttp.searchRecommend();
  }

  void onClickKeyword(String keyword, {bool clearSuggest = true}) {
    controller.text = keyword;
    validateUid();

    if (searchSuggestion) {
      _suggestions.cancel();
      if (clearSuggest) searchSuggestList.clear();
    }
    submit();
  }

  void onLongSelect(String word) {
    historyList.remove(word);
    GStorage.historyWord.put('cacheList', historyList);
  }

  void onClearHistory() {
    showConfirmDialog(
      context: Get.context!,
      title: const Text('确定清空搜索历史？'),
      onConfirm: () {
        historyList.clear();
        GStorage.historyWord.delete('cacheList');
      },
    );
  }

  @override
  void onClose() {
    if (searchSuggestion) _suggestions.cancel();
    searchFocusNode.dispose();
    controller.dispose();
    super.onClose();
  }
}
