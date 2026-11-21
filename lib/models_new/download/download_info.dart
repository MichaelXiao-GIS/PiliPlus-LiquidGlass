import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart'
    show MultiSelectData;

class DownloadPageInfo with MultiSelectData {
  final String pageId;
  final String dirPath;
  final String title;
  String cover;
  int sortKey;
  final int? seasonType;
  final List<BiliDownloadEntryInfo> entries;

  DownloadPageInfo({
    required this.pageId,
    required this.dirPath,
    required this.title,
    required this.cover,
    required this.sortKey,
    this.seasonType,
    required this.entries,
  });
}

class DownloadSeasonInfo with MultiSelectData {
  SeasonInfo? seasonInfo;
  final String pageId;
  final List<DownloadPageInfo> pages;

  DownloadSeasonInfo({
    required this.seasonInfo,
    required this.pageId,
    required this.pages,
  });

  static List<DownloadSeasonInfo> groupEntries(
    Iterable<BiliDownloadEntryInfo> entries,
  ) {
    final groups = <DownloadSeasonInfo>[];
    final bySeason = <int, DownloadSeasonInfo>{};
    final byFirstPage = <String, DownloadSeasonInfo>{};
    final pages = <(DownloadSeasonInfo, String), DownloadPageInfo>{};
    for (final entry in entries) {
      final pageId = entry.pageId;
      final season = entry.seasonInfo;
      var group = season == null ? byFirstPage[pageId] : bySeason[season.id];
      if (group == null) {
        group = DownloadSeasonInfo(
          pageId: pageId,
          seasonInfo: season,
          pages: [],
        );
        groups.add(group);
        if (season != null) bySeason[season.id] = group;
        // Older entries without season metadata use the first group's page ID.
        byFirstPage[pageId] ??= group;
      }
      final key = (group, pageId);
      final page = pages[key];
      if (page == null) {
        final newPage = entry.toDownloadPageInfo(
          pageId,
          sortKey: season?.index,
        );
        group.pages.add(newPage);
        pages[key] = newPage;
      } else {
        if (entry.sortKey < page.sortKey) {
          page
            ..sortKey = entry.sortKey
            ..cover = entry.cover;
        }
        page.entries.add(entry);
      }
    }
    return groups;
  }
}
