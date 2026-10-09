import 'dart:convert';
import 'package:ajopay/domain/entities/group_details.dart';
import 'dart:async';

import 'package:ajopay/core/errors/failure.dart';
import 'package:ajopay/core/errors/result.dart';
import 'package:ajopay/data/repositories/group_repository_impl.dart';
import 'package:ajopay/domain/entities/savings_group.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final date = DateTime.now().add(const Duration(days: 30));
  final draft = GroupDraft(
    name: 'Friends',
    contributionKobo: 2000050,
    memberLimit: 10,
    firstPayoutDate: date,
  );
  final row = {
    'id': 'group-id',
    'name': 'Friends',
    'contribution_kobo': 2000050,
    'member_limit': 10,
    'first_payout_date': dateOnly(date),
    'status': 'draft',
  };
  late SupabaseClient client;
  GroupRepositoryImpl repository(http.Response Function(http.Request) handle) {
    client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      httpClient: MockClient((request) async {
        final response = handle(request);
        return http.Response(
          response.body,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    return GroupRepositoryImpl(client);
  }

  tearDown(() async => client.dispose());

  test(
    'create uses one server operation with integer kobo and a stable request id',
    () async {
      final repo = repository((request) {
        expect(request.url.path, '/rest/v1/rpc/create_savings_group_v2');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map;
        expect(body['p_contribution_kobo'], 2000050);
        expect(body['p_request_id'], 'request-id');
        expect(body['p_first_payout_date'], dateOnly(date));
        expect(body.containsKey('created_by'), isFalse);
        return http.Response(
          jsonEncode(row),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final result =
          await repo.createGroup(draft, 'request-id') as Success<SavingsGroup>;
      expect(result.value.id, 'group-id');
    },
  );

  test('join normalizes code and uses controlled server operation', () async {
    final repo = repository((request) {
      expect(request.url.path, '/rest/v1/rpc/join_savings_group');
      expect(jsonDecode(request.body), {'p_invite_code': 'abc'});
      return http.Response(
        jsonEncode(row),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    expect(await repo.joinGroup(' ABC '), isA<Success<SavingsGroup>>());
  });
  test('agreement sends displayed version and decodes group details', () async {
    final repo = repository((request) {
      expect(request.url.path, '/rest/v1/rpc/accept_group_terms');
      expect(jsonDecode(request.body), {
        'p_group_id': 'group-id',
        'p_terms_version': 3,
      });
      return http.Response(
        jsonEncode({
          'group': {
            ...row,
            'created_by': 'owner',
            'terms_version': 3,
            'order_prepared': true,
          },
          'members': [
            {
              'user_id': 'owner',
              'name': 'Ada',
              'role': 'owner',
              'rotation_position': 1,
              'accepted_terms_version': 3,
            },
          ],
          'periods': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final result =
        await repo.acceptTerms('group-id', 3) as Success<GroupDetails>;
    expect(result.value.members.single.acceptedVersion, 3);
    expect(result.value.allAgreed, isFalse);
  });

  test('list decodes real group rows', () async {
    final repo = repository((request) {
      expect(request.url.path, '/rest/v1/savings_groups');
      expect(request.method, 'GET');
      return http.Response(
        jsonEncode([row]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final result = await repo.listGroups() as Success<List<SavingsGroup>>;
    expect(result.value.single.contributionKobo, 2000050);
  });

  test('permission failure does not expose raw database details', () async {
    final repo = repository(
      (_) => http.Response(
        jsonEncode({'code': '42501', 'message': 'private database detail'}),
        403,
        headers: {'content-type': 'application/json'},
      ),
    );
    final result =
        await repo.createGroup(draft, 'request-id') as Error<SavingsGroup>;
    expect(result.failure, isA<PermissionFailure>());
    expect(result.failure.message, isNot(contains('private database detail')));
  });

  test(
    'an already-saved request with changed terms points back to the dashboard',
    () async {
      final repo = repository(
        (_) => http.Response(
          jsonEncode({'code': '23505', 'message': 'Request already used'}),
          409,
          headers: {'content-type': 'application/json'},
        ),
      );
      final result =
          await repo.createGroup(draft, 'request-id') as Error<SavingsGroup>;
      expect(result.failure, isA<ValidationFailure>());
      expect(result.failure.message, contains('already saved'));
    },
  );
  test(
    'a stalled group request returns a retryable failure instead of loading forever',
    () async {
      final pending = Completer<http.Response>();
      client = SupabaseClient(
        'https://test.invalid',
        'test-key',
        httpClient: MockClient((_) => pending.future),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final repo = GroupRepositoryImpl(
        client,
        requestTimeout: const Duration(milliseconds: 10),
      );
      final result = await repo.listGroups() as Error<List<SavingsGroup>>;
      expect(result.failure, isA<NetworkFailure>());
      expect(result.failure.message, contains('try again'));
      pending.complete(
        http.Response('[]', 200, headers: {'content-type': 'application/json'}),
      );
    },
  );
}
