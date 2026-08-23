import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Prefix embedded in the QR payload so the scanner can tell a room QR
/// code apart from any other QR code someone might point the camera at.
const roomQrPrefix = 'QUIZELIM-ROOM:';

String roomQrPayload(String code) => '$roomQrPrefix$code';

/// Extracts the room code from a scanned QR payload, or null if the
/// payload isn't one of our room QR codes.
String? roomCodeFromQrPayload(String payload) {
  if (!payload.startsWith(roomQrPrefix)) return null;
  final code = payload.substring(roomQrPrefix.length).trim();
  return code.isEmpty ? null : code;
}

/// Small QR code shown in a game's waiting room so other players can join
/// by scanning instead of typing the code.
class RoomQrCode extends StatelessWidget {
  final String code;

  const RoomQrCode({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: QrImageView(
        data: roomQrPayload(code),
        version: QrVersions.auto,
        size: 120,
        backgroundColor: Colors.white,
      ),
    );
  }
}
