import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AuthenticatedReceiptImage extends StatelessWidget {
  const AuthenticatedReceiptImage({
    super.key,
    required this.expenseId,
    this.fit = BoxFit.cover,
    this.errorMessage = 'Belegbild konnte nicht geladen werden.',
    this.progressIndicatorColor,
  });

  final int expenseId;
  final BoxFit fit;
  final String errorMessage;
  final Color? progressIndicatorColor;

  String _imageUrl() {
    final uri = Uri.parse('${ApiService.baseUrl}receipt_image.php').replace(
      queryParameters: {'expense_id': expenseId.toString()},
    );
    return uri.toString();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: ApiService().getToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: CircularProgressIndicator(color: progressIndicatorColor),
          );
        }

        final token = snapshot.data;
        if (token == null || token.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Sitzung fehlt. Belegbild kann nicht geladen werden.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          );
        }

        return Image.network(
          _imageUrl(),
          fit: fit,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'image/*',
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }

            return Center(
              child: CircularProgressIndicator(color: progressIndicatorColor),
            );
          },
          errorBuilder: (_, __, ___) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                errorMessage,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
