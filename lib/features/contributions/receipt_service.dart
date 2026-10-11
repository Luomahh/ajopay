import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/result.dart';
import '../../core/errors/failure.dart';
import '../../core/utils/request_id.dart';
import '../../domain/entities/receipt_image.dart';
import '../../data/datasources/supabase_client_provider.dart';

abstract class ReceiptService {
  Future<Result<ReceiptImage?>> pick();
  Future<Result<String>> upload(String groupId, ReceiptImage image);
  Future<Result<String>> signedUrl(String path);
}

final receiptServiceProvider = Provider<ReceiptService>(
  (ref) => SupabaseReceiptService(ref.watch(supabaseClientProvider)),
);

class SupabaseReceiptService implements ReceiptService {
  SupabaseReceiptService(this.client);
  final SupabaseClient client;
  @override
  Future<Result<ReceiptImage?>> pick() async {
    try {
      final selected = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      if (selected == null) return const Result.success(null);
      final bytes = selected.files.single.bytes;
      final image = bytes == null ? null : ReceiptImage.parse(bytes);
      if (image == null) {
        return const Result.failure(
          ValidationFailure(
            'Choose a PNG, JPG or WebP screenshot no larger than 5 MB.',
          ),
        );
      }
      return Result.success(image);
    } catch (_) {
      return const Result.failure(
        ServerFailure('Could not open the image picker. Please try again.'),
      );
    }
  }

  @override
  Future<Result<String>> upload(String groupId, ReceiptImage image) async {
    final user = client.auth.currentUser?.id;
    if (user == null) {
      return const Result.failure(PermissionFailure('Please sign in again.'));
    }
    final path = '$groupId/$user/${newRequestId()}.${image.extension}';
    try {
      await client.storage
          .from('payment-receipts')
          .uploadBinary(
            path,
            image.bytes,
            fileOptions: FileOptions(
              contentType: image.contentType,
              upsert: false,
            ),
          )
          .timeout(const Duration(seconds: 45));
      return Result.success(path);
    } catch (_) {
      return const Result.failure(
        NetworkFailure(
          'Screenshot upload failed. Your payment has not been submitted. Please retry.',
        ),
      );
    }
  }

  @override
  Future<Result<String>> signedUrl(String path) async {
    try {
      return Result.success(
        await client.storage
            .from('payment-receipts')
            .createSignedUrl(path, 60)
            .timeout(const Duration(seconds: 15)),
      );
    } catch (_) {
      return const Result.failure(
        ServerFailure('Could not open this receipt. Refresh and try again.'),
      );
    }
  }
}
