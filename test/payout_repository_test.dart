import 'dart:async';
import 'dart:convert';
import 'package:ajopay/core/errors/result.dart';
import 'package:ajopay/core/errors/failure.dart';
import 'package:ajopay/data/repositories/payout_repository_impl.dart';
import 'package:ajopay/domain/entities/payout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/fake_payout_repository.dart';

void main() {
  late SupabaseClient client;
  PayoutRepositoryImpl repo(
    Future<http.Response> Function(http.Request) action, {
    Duration timeout = const Duration(seconds: 2),
  }) {
    client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      httpClient: MockClient((request) async {
        final response = await action(request);
        return http.Response(
          response.body,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    return PayoutRepositoryImpl(client, timeout: timeout);
  }

  tearDown(() => client.dispose());
  http.Response response() => http.Response(
    jsonEncode(trackerFixture()),
    200,
    headers: {'content-type': 'application/json'},
  );
  test(
    'record sends frozen amount recipient date and expected version',
    () async {
      final r = repo((req) async {
        expect(req.url.path, '/rest/v1/rpc/record_payout');
        expect(jsonDecode(req.body), {
          'p_group_id': 'group',
          'p_slot': 2,
          'p_recipient_id': 'member',
          'p_amount_kobo': 2000000,
          'p_reference': 'bank-ref',
          'p_paid_on': '2026-10-10',
          'p_expected_version': 1,
          'p_note': 'Corrected',
        });
        return response();
      });
      expect(
        await r.record(
          groupId: 'group',
          slot: 2,
          recipientId: 'member',
          amountKobo: 2000000,
          reference: ' bank-ref ',
          paidOn: DateTime(2026, 10, 10),
          expectedVersion: 1,
          note: ' Corrected ',
        ),
        isA<Success<PayoutTracker>>(),
      );
    },
  );
  test(
    'acknowledgement identity comes from server session, never a supplied recipient',
    () async {
      final r = repo((req) async {
        expect(req.url.path, '/rest/v1/rpc/acknowledge_payout');
        expect(jsonDecode(req.body), {
          'p_group_id': 'group',
          'p_slot': 0,
          'p_version': 2,
          'p_received': false,
          'p_note': 'Not received',
        });
        return response();
      });
      expect(
        await r.acknowledge(
          groupId: 'group',
          slot: 0,
          version: 2,
          received: false,
          note: ' Not received ',
        ),
        isA<Success<PayoutTracker>>(),
      );
    },
  );
  test('server authorization failure is a typed permission failure', () async {
    final r = repo(
      (_) async => http.Response(
        jsonEncode({'code': '42501', 'message': 'denied'}),
        403,
        headers: {'content-type': 'application/json'},
      ),
    );
    final result = await r.getTracker('group') as Error<PayoutTracker>;
    expect(result.failure, isA<PermissionFailure>());
  });
  test('timeout warns against sending money again', () async {
    final r = repo(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 5),
    );
    final result = await r.getTracker('group') as Error<PayoutTracker>;
    expect(result.failure, isA<NetworkFailure>());
    expect(result.failure.message, contains('do not send the money again'));
  });
}
