import 'dart:convert';
import 'package:ajopay/core/errors/failure.dart';
import 'package:ajopay/core/errors/result.dart';
import 'package:ajopay/data/repositories/contribution_repository_impl.dart';
import 'package:ajopay/domain/entities/contribution.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  final fixture = {
    'today': '2026-10-09',
    'periods': [
      {'period_number': 1, 'opens_on': '2026-10-05', 'due_date': '2026-10-11'},
    ],
    'contributions': [],
    'history': [],
  };
  ContributionRepositoryImpl repo(
    http.Response Function(http.Request) callback,
  ) {
    client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      httpClient: MockClient((r) async {
        final response = callback(r);
        return http.Response(
          response.body,
          response.statusCode,
          headers: response.headers,
          request: r,
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    return ContributionRepositoryImpl(client);
  }

  tearDown(() async => client.dispose());
  test(
    'submission derives identity on server and sends exact amount and version',
    () async {
      final r = repo((request) {
        expect(request.url.path, '/rest/v1/rpc/submit_contribution_v2');
        expect(jsonDecode(request.body), {
          'p_group_id': 'group',
          'p_period': 1,
          'p_amount_kobo': 500000,
          'p_reference': 'bank-ref',
          'p_paid_on': '2026-10-09',
          'p_expected_version': 0,
          'p_receipt_path': null,
          'p_payment_note': null,
        });
        return http.Response(
          jsonEncode(fixture),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final response =
          await r.submit(
                groupId: 'group',
                period: 1,
                amountKobo: 500000,
                reference: ' bank-ref ',
                paidOn: DateTime(2026, 10, 9),
                expectedVersion: 0,
              )
              as Success<ContributionTracker>;
      expect(response.value.periods.single.isOpen(response.value.today), true);
    },
  );
  test(
    'review includes reviewed member and displayed submission version',
    () async {
      final r = repo((request) {
        expect(request.url.path, '/rest/v1/rpc/review_contribution');
        expect(jsonDecode(request.body), {
          'p_group_id': 'group',
          'p_period': 1,
          'p_user_id': 'member',
          'p_version': 2,
          'p_confirm': false,
          'p_note': 'Check reference',
        });
        return http.Response(
          jsonEncode(fixture),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      expect(
        await r.review(
          groupId: 'group',
          period: 1,
          userId: 'member',
          version: 2,
          confirm: false,
          note: 'Check reference',
        ),
        isA<Success<ContributionTracker>>(),
      );
    },
  );
  test(
    'duplicate reference returns actionable validation without database details',
    () async {
      final r = repo(
        (_) => http.Response(
          jsonEncode({'code': '23505', 'message': 'private database details'}),
          409,
          headers: {'content-type': 'application/json'},
        ),
      );
      final response =
          await r.submit(
                groupId: 'group',
                period: 1,
                amountKobo: 500000,
                reference: 'ref',
                paidOn: DateTime(2026, 10, 9),
                expectedVersion: 0,
              )
              as Error<ContributionTracker>;
      expect(response.failure, isA<ValidationFailure>());
      expect(response.failure.message, contains('reference'));
      expect(response.failure.message, isNot(contains('private database')));
    },
  );
}
