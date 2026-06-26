import 'package:flutter_test/flutter_test.dart';
import 'package:pure_enjoy/services/api_client.dart';
import 'package:pure_enjoy/services/cancel_token.dart';

void main() {
  group('ApiResponse', () {
    test('success factory creates success response with data', () {
      final data = [
        {'id': '1', 'name': 'test'},
        {'id': '2', 'name': 'test2'},
      ];
      final response = ApiResponse.success(data, statusCode: 200);

      expect(response.isSuccess, true);
      expect(response.isError, false);
      expect(response.data, isNotNull);
      expect(response.data!.length, 2);
      expect(response.statusCode, 200);
      expect(response.error, isNull);
      expect(response.errorMessage, isNull);
    });

    test('error factory creates error response', () {
      final response = ApiResponse.error('请求失败', statusCode: 500);

      expect(response.isSuccess, false);
      expect(response.isError, true);
      expect(response.data, isNull);
      expect(response.error, '请求失败');
      expect(response.errorMessage, '请求失败');
      expect(response.statusCode, 500);
    });

    test('success with empty list', () {
      final response = ApiResponse.success([]);

      expect(response.isSuccess, true);
      expect(response.data, isEmpty);
      expect(response.statusCode, isNull);
    });

    test('error without status code', () {
      final response = ApiResponse.error('网络错误');

      expect(response.isSuccess, false);
      expect(response.statusCode, isNull);
      expect(response.error, '网络错误');
    });

    test('isError is always opposite of isSuccess', () {
      final success = ApiResponse.success([]);
      final error = ApiResponse.error('err');

      expect(success.isError, false);
      expect(error.isError, true);
    });

    test('errorMessage is alias for error', () {
      final response = ApiResponse.error('测试错误');

      expect(response.errorMessage, response.error);
      expect(response.errorMessage, '测试错误');
    });
  });

  group('CancelToken', () {
    test('initial state is not cancelled', () {
      final token = CancelToken();

      expect(token.isCancelled, false);
    });

    test('cancel sets isCancelled to true', () {
      final token = CancelToken();
      token.cancel();

      expect(token.isCancelled, true);
    });

    test('cancel is idempotent', () {
      final token = CancelToken();
      token.cancel();
      token.cancel();
      token.cancel();

      expect(token.isCancelled, true);
    });
  });

  group('RequestCancelledException', () {
    test('toString returns meaningful message', () {
      final exception = RequestCancelledException();

      expect(exception.toString(), '请求已取消');
    });

    test('is an Exception', () {
      final exception = RequestCancelledException();

      expect(exception, isA<Exception>());
    });
  });
}
