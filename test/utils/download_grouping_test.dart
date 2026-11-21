import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/download_info.dart';
import 'package:flutter_test/flutter_test.dart';

BiliDownloadEntryInfo entry(int avid, int part, {int? seasonId}) =>
    BiliDownloadEntryInfo(
      avid: avid,
      bvid: 'BV$avid',
      cover: '$avid-$part',
      title: 'title $avid',
      pageData: PageInfo(
        cid: avid * 100 + part,
        page: part,
        hasAlias: false,
        tid: 1,
      ),
      seasonInfo: seasonId == null
          ? null
          : SeasonInfo(
              id: seasonId,
              index: 9,
              title: '',
              cover: '',
              mid: 0,
              uname: '',
            ),
      isCompleted: true,
      totalBytes: 0,
      downloadedBytes: 0,
      preferedVideoQuality: 0,
      guessedTotalBytes: 0,
      totalTimeMilli: 0,
      danmakuCount: 0,
    )..pageDirPath = '/$avid';

void main() {
  test('cached pages keep their order, earliest cover and legacy grouping', () {
    final first = entry(21, 3, seasonId: 6);
    final standalone = entry(45, 7);
    final secondPage = entry(33, 5, seasonId: 6);
    final legacy = entry(21, 2);
    final anotherSeason = entry(21, 4, seasonId: 7);
    final groups = DownloadSeasonInfo.groupEntries([
      first,
      standalone,
      secondPage,
      anotherSeason,
      legacy,
    ]);
    expect(groups.map((g) => g.seasonInfo?.id), [6, null, 7]);
    expect(groups.first.pages.map((p) => p.pageId), ['21', '33']);
    expect(groups.first.pages.first.entries, [first, legacy]);
    expect(groups.first.pages.first.sortKey, 2);
    expect(groups.first.pages.first.cover, legacy.cover);
    expect(groups.first.pages.last.sortKey, 9);
    expect(groups.last.pages.single.entries, [anotherSeason]);
    expect(groups[1].pages.single.entries, [standalone]);
  });
}
