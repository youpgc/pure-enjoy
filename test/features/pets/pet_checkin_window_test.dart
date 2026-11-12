import 'package:flutter_test/flutter_test.dart';
import 'package:pure_enjoy/features/pets/utils/pet_checkin_window.dart';

void main() {
  group('petCheckinCollapsedWindow 收起窗口', () {
    // 锚点组（含今日）+ 其后一组：不论今日是否签到的“今日对应槽”都落在同一组
    test('12 次签到今日已签（锚定 12）→ 9-16，而非 13-20', () {
      final (start, end) = petCheckinCollapsedWindow(12, 30);
      expect(start, 9);
      expect(end, 16);
      // 9-12（含今日进度）+ 13-16（下一个待签组）
      expect(12 >= start && 12 <= end, isTrue);
      expect(13 >= start && 13 <= end, isTrue);
    });

    test('第 9 次签到今日已签（锚定 9）→ 9-16，而非 5-12', () {
      // 旧逻辑（前组+锚点组）会给出 5-12，错误；应锚定今日组 9-12 + 后组 13-16
      final (start, end) = petCheckinCollapsedWindow(9, 30);
      expect(start, 9);
      expect(end, 16);
      expect(9 >= start && 9 <= end, isTrue);
      expect(13 >= start && 13 <= end, isTrue);
    });

    test('第 9 次签到今日未签（锚定 10）同样展示 9-16', () {
      final (start, end) = petCheckinCollapsedWindow(10, 30);
      expect(start, 9);
      expect(end, 16);
    });

    test('未签到日（锚定 1）展示首两组 1-8', () {
      final (start, end) = petCheckinCollapsedWindow(1, 30);
      expect(start, 1);
      expect(end, 8);
    });

    test('锚点组已是月末最后一组时回退到月内最后两组', () {
      // 30 天月，今日对应槽 29（组 29-30 为末组）
      final (start, end) = petCheckinCollapsedWindow(29, 30);
      expect(start, 25);
      expect(end, 30);
      expect(29 >= start && 29 <= end, isTrue);
    });

    test('全部签完（锚定 30）窗口落在月末两组且含最后一天', () {
      final (start, end) = petCheckinCollapsedWindow(30, 30);
      expect(start, 25);
      expect(end, 30);
      expect(30 >= start && 30 <= end, isTrue);
    });

    test('末尾不满两整组的小月按实际天数收口', () {
      // 5 天月、今日对应槽 4
      final (start, end) = petCheckinCollapsedWindow(4, 5);
      expect(start, 1);
      expect(end, 5);
    });
  });
}
