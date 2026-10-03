// ShercoRemoto: tokens of the ShercoIT API, encrypted with Windows DPAPI
// (CryptProtectData, current user) and kept in the local options.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../models/platform_model.dart';

final class _DataBlob extends Struct {
  @Uint32()
  external int cbData;
  external Pointer<Uint8> pbData;
}

typedef _CryptNative = Int32 Function(Pointer<_DataBlob>, Pointer<Utf16>,
    Pointer<_DataBlob>, Pointer<Void>, Pointer<Void>, Uint32, Pointer<_DataBlob>);
typedef _CryptDart = int Function(Pointer<_DataBlob>, Pointer<Utf16>,
    Pointer<_DataBlob>, Pointer<Void>, Pointer<Void>, int, Pointer<_DataBlob>);
typedef _LocalFreeNative = Pointer<Void> Function(Pointer<Void>);
typedef _LocalFreeDart = Pointer<Void> Function(Pointer<Void>);

const _kUiForbidden = 0x1;

Uint8List? _dpapi(Uint8List input, bool protect) {
  final crypt32 = DynamicLibrary.open('crypt32.dll');
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final fn = crypt32.lookupFunction<_CryptNative, _CryptDart>(
      protect ? 'CryptProtectData' : 'CryptUnprotectData');
  final localFree =
      kernel32.lookupFunction<_LocalFreeNative, _LocalFreeDart>('LocalFree');
  final inBlob = calloc<_DataBlob>();
  final outBlob = calloc<_DataBlob>();
  final data = calloc<Uint8>(input.isEmpty ? 1 : input.length);
  try {
    data.asTypedList(input.length).setAll(0, input);
    inBlob.ref
      ..cbData = input.length
      ..pbData = data;
    final ok = fn(inBlob, nullptr, nullptr, nullptr, nullptr, _kUiForbidden,
        outBlob);
    if (ok == 0) return null;
    final out =
        Uint8List.fromList(outBlob.ref.pbData.asTypedList(outBlob.ref.cbData));
    localFree(outBlob.ref.pbData.cast());
    return out;
  } finally {
    calloc.free(data);
    calloc.free(inBlob);
    calloc.free(outBlob);
  }
}

class ShercoSecureStore {
  static const _prefix = 'shercoremoto-';

  static Future<void> write(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await bind.mainSetLocalOption(key: '$_prefix$key', value: '');
      return;
    }
    String stored;
    if (Platform.isWindows) {
      final enc = _dpapi(Uint8List.fromList(utf8.encode(value)), true);
      if (enc == null) return; // never fall back to plain text
      stored = 'dpapi:${base64Encode(enc)}';
    } else {
      stored = 'plain:$value';
    }
    await bind.mainSetLocalOption(key: '$_prefix$key', value: stored);
  }

  static String? read(String key) {
    final stored = bind.mainGetLocalOption(key: '$_prefix$key');
    if (stored.isEmpty) return null;
    try {
      if (stored.startsWith('dpapi:') && Platform.isWindows) {
        final dec = _dpapi(base64Decode(stored.substring(6)), false);
        return dec == null ? null : utf8.decode(dec);
      }
      if (stored.startsWith('plain:')) return stored.substring(6);
    } catch (_) {}
    return null;
  }
}
