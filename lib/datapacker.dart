library datapacker;

import 'dart:convert';
import 'dart:typed_data';

class DataPacker {
  final currentVersion = 0x0;
  final compatibleVersions = [0x0];

  /// Unserialize DateTime as
  ///
  /// true: String
  ///
  /// false: DateTime
  bool dateAsString;
  int initialBufferSize;
  DataPacker({
    this.dateAsString = false,
    this.initialBufferSize = 4096,
  });

  final

      /// 00-00-00-00 = null
      TYPE_NULL = 0x00,

      /// 00-00-00-01 = date
      TYPE_DATE = 0x01,

      /// 00-00-00-10 = false
      TYPE_BOOLEAN_FALSE = 0x02,

      /// 00-00-00-11 = true
      TYPE_BOOLEAN_TRUE = 0x03,

      /// 00-00-01-BB = int
      TYPE_INT = 0x04,

      /// 00-00-10-BB = float
      TYPE_FLOAT = 0x08,

      /// 00-00-11-LL = binary
      TYPE_BINARY = 0x0c,

      /// 00-01-00-LL = string
      TYPE_STRING = 0x10,

      /// 00-01-01-LL = array
      TYPE_ARRAY = 0x14,

      /// 00-01-10-LL = map
      TYPE_MAP = 0x18,

      /// 00-01-11-BB = uint
      TYPE_UINT = 0x1c,

      /// 11-11-11-LL = extension [BYTE, EXT_OPCODE, LL, ...]
      TYPE_EXTENSION = 0xfc;

  final utf8codec = const Utf8Codec();

  /// Deserialize given binary sequence
  dynamic deserialize(Uint8List bytes) {
    dynamic json;

    List<dynamic> openOperands = [];
    var bytesView = DataWrapper(bytes: bytes);
    // ByteData.view(bytes.buffer);

    int readUint(int pos, [int w = 1]) {
      if (w == 1) {
        return bytesView.getUint8(pos);
      } else if (w == 2) {
        return bytesView.getUint16(pos);
      } else if (w == 4) {
        return bytesView.getUint32(pos);
      } else {
        return bytesView.getUint64(pos);
      }
    }

    int readInt(int pos, [int w = 1]) {
      if (w == 1) {
        return bytesView.getInt8(pos);
      } else if (w == 2) {
        return bytesView.getInt16(pos);
      } else if (w == 4) {
        return bytesView.getInt32(pos);
      } else {
        return bytesView.getInt64(pos);
      }
    }

    double readFloat(int pos, [int w = 8]) {
      if (w == 4) {
        return bytesView.getFloat32(pos);
      } else {
        return bytesView.getFloat64(pos);
      }
    }

    popProcessedListOrMap() {
      while (openOperands.isNotEmpty && openOperands.last['size'] == 0) {
        var item = openOperands.removeLast();
        var value = item['value'];

        if (openOperands.isEmpty) {
          json = value;
        } else {
          var last = openOperands.last;

          if (last['value'] is Map) {
            last['value'][last['key']] = value;
            last['key'] = null;
            last['size']--;
          } else if (last['value'] is List) {
            (last['value'] as List).add(value);
            last['size']--;
          }
        }
      }
    }

    digestData(dynamic data) {
      if (openOperands.isEmpty) return;

      var last = openOperands.last;

      if (last['value'] is Map) {
        if (last['key'] == null) {
          last['key'] = data;
        } else {
          last['size']--;

          last['value'][last['key']] = data;
          last['key'] = null;
        }
      } else if (last['value'] is List) {
        last['size']--;

        (last['value'] as List).add(data);
      }

      popProcessedListOrMap();
    }

    int decodeDataByteSize(int n) {
      return n == 0 ? 1 : (n == 1 ? 2 : (n == 2 ? 4 : 8));
    }

    if (bytes[0] != 0xD3 ||
        bytes[1] != 0x7A ||
        bytes[2] != 0xA9 ||
        bytes[3] & 0xF0 != 0x10) {
      throw Exception('INVALID_FILE');
    }

    int version = bytes[3] & 0x0F;
    if (!compatibleVersions.contains(version)) {
      throw Exception('INCOMPATIBLE_VERSION');
    }

    for (int i = 4; i < bytesView.length;) {
      var BYTE = bytesView.getUint8(i), OPCODE = BYTE & 0xFC, XX = BYTE & 0x03;

      // if (decoders.containsKey(OPCODE)) {
      //   decoders[OPCODE]();
      // }

      if (OPCODE == TYPE_MAP) {
        int L = decodeDataByteSize(XX);
        int size = readUint(i + 1, L);

        Map<dynamic, dynamic> value = {};

        openOperands.add({'key': null, 'size': size, 'value': value});

        if (size == 0) popProcessedListOrMap();

        i += 1 + L;
      } else if (OPCODE == TYPE_ARRAY) {
        int L = decodeDataByteSize(XX);
        int size = readUint(i + 1, L);

        List<dynamic> value = [];

        openOperands.add({'size': size, 'value': value});

        if (size == 0) popProcessedListOrMap();

        i += 1 + L;
      } else if (OPCODE == TYPE_BINARY) {
        int L = decodeDataByteSize(XX);

        int size = readUint(i + 1, L);
        var data = bytes.sublist(i + 1 + L, i + 1 + L + size);

        digestData(data);

        i += 1 + L + size;
      } else if (OPCODE == TYPE_STRING) {
        int L = decodeDataByteSize(XX);

        int size = readUint(i + 1, L);
        var data = utf8codec.decode(bytes.sublist(i + 1 + L, i + 1 + L + size));

        digestData(data);

        i += 1 + L + size;
      } else if (OPCODE == TYPE_FLOAT) {
        int L = decodeDataByteSize(XX);

        double data = readFloat(i + 1, L);

        digestData(data);

        i += 1 + L;
      } else if (OPCODE == TYPE_UINT) {
        int L = decodeDataByteSize(XX);

        int data = readUint(i + 1, L);

        digestData(data);

        i += 1 + L;
      } else if (OPCODE == TYPE_INT) {
        int L = decodeDataByteSize(XX);

        int data = readInt(i + 1, L);

        digestData(data);

        i += 1 + L;
      } else if (BYTE == TYPE_DATE) {
        int L = 8;

        int data = readUint(i + 1, L);

        var date = DateTime.fromMillisecondsSinceEpoch(data);
        digestData(dateAsString ? date.toIso8601String() : date);

        i += 1 + L;
      } else if (BYTE == TYPE_BOOLEAN_TRUE || BYTE == TYPE_BOOLEAN_FALSE) {
        digestData(BYTE == TYPE_BOOLEAN_TRUE);

        i += 1;
      } else if (BYTE == TYPE_NULL) {
        digestData(null);

        i += 1;
      } else {
        throw Exception(
            'Unable to deserialize due to unknown opcode $OPCODE at pos $i.');
      }
    }

    return json;
  }

  /// Serialize given Map|List
  Uint8List serialize(dynamic d) {
    int pos = 0;
    var bytes = DataWrapper(initialBufferSize: initialBufferSize);

    int encodeDataByteSize(int val) {
      return val == 1 ? 0 : (val == 2 ? 1 : (val == 4 ? 2 : 3));
    }

    /// Adjust DataWrapper to accommodate the next entry
    ensureWriteSpace(int size) {
      int totalExpectedLength = pos + size;

      if (bytes.length < totalExpectedLength) {
        bytes.resize(pos, totalExpectedLength * 2);
      }
    }

    /// Check how many bytes are required to store given num
    int intBytesRequired(int object) {
      if (object >= 0) {
        if (object < 0x100) {
          return 1;
        } else if (object < 0x10000) {
          return 2;
        } else if (object < 0x100000000) {
          return 4;
        } else {
          return 8;
        }
      } else {
        if (object >= -0x80) {
          return 1;
        } else if (object >= -0x8000) {
          return 2;
        } else if (object >= -0x80000000) {
          return 4;
        } else {
          return 8;
        }
      }
    }

    /// Write Signed integer
    writeInt(int val, [int? bytesRequired]) {
      bytesRequired ??= intBytesRequired(val);
      ensureWriteSpace(bytesRequired);

      if (bytesRequired == 1) {
        bytes.setInt8(pos, val);
      } else if (bytesRequired == 2) {
        bytes.setInt16(pos, val);
      } else if (bytesRequired == 4) {
        bytes.setInt32(pos, val);
      } else {
        bytes.setInt64(pos, val);
      }

      pos += bytesRequired;
    }

    /// Write Unsigned integer
    writeUint(int val, [int? bytesRequired]) {
      bytesRequired ??= intBytesRequired(val);
      ensureWriteSpace(bytesRequired);

      if (bytesRequired == 1) {
        bytes.setUint8(pos, val);
      } else if (bytesRequired == 2) {
        bytes.setUint16(pos, val);
      } else if (bytesRequired == 4) {
        bytes.setUint32(pos, val);
      } else {
        bytes.setUint64(pos, val);
      }

      pos += bytesRequired;
    }

    /// Write Signed double
    writeFloat(double val, [int w = 8]) {
      ensureWriteSpace(w);

      if (w == 4) {
        bytes.setFloat32(pos, val);
      } else {
        bytes.setFloat64(pos, val);
      }

      pos += w;
    }

    /// Write bytes
    writeBytes(List<int> arr) {
      ensureWriteSpace(pos + arr.length);
      bytes.setBytes(pos, arr);
      pos += arr.length;
    }

    encode(dynamic d) {
      if (d is Map) {
        var size = d.length;

        var byteSize = intBytesRequired(size);
        writeUint(TYPE_MAP + encodeDataByteSize(byteSize), 1);
        writeUint(size, byteSize);

        for (var key in d.keys) {
          encode(key);
          encode(d[key]);
        }
      } else if (d is Uint8List) {
        var size = d.length;

        var byteSize = intBytesRequired(size);
        writeUint(TYPE_BINARY + encodeDataByteSize(byteSize), 1);
        writeUint(size, byteSize);
        writeBytes(d);
      } else if (d is List) {
        var size = d.length;

        var byteSize = intBytesRequired(size);
        writeUint(TYPE_ARRAY + encodeDataByteSize(byteSize), 1);
        writeUint(size, byteSize);

        for (var item in d) {
          encode(item);
        }
      } else if (d is String) {
        var data = utf8codec.encode(d);
        var size = data.length;

        var byteSize = intBytesRequired(size);
        writeUint(TYPE_STRING + encodeDataByteSize(byteSize), 1);
        writeUint(size, byteSize);
        writeBytes(data);
      } else if (d is DateTime) {
        writeUint(TYPE_DATE, 1);
        writeUint(d.millisecondsSinceEpoch, 8);
      } else if (d is double) {
        writeUint(TYPE_FLOAT + 3, 1);
        writeFloat(d, 8);
      } else if (d is int) {
        var byteSize = intBytesRequired(d);

        if (d >= 0) {
          writeUint(TYPE_UINT + encodeDataByteSize(byteSize), 1);
          writeUint(d, byteSize);
        } else {
          writeUint(TYPE_INT + encodeDataByteSize(byteSize), 1);
          writeInt(d, byteSize);
        }
      } else if (d is bool) {
        writeUint(d == true ? TYPE_BOOLEAN_TRUE : TYPE_BOOLEAN_FALSE, 1);
      } else if (d == null) {
        writeUint(TYPE_NULL, 1);
      }
    }

    // datapacker file identifier with version
    writeBytes([0xD3, 0x7A, 0xA9, 0x10 | currentVersion]);
    encode(d);

    return bytes.view(0, pos);
  }
}

class DataWrapper {
  int initialBufferSize;
  late Uint8List bytes;
  late ByteData bytesView;

  DataWrapper({
    this.initialBufferSize = 4096,
    Uint8List? bytes,
  }) {
    this.bytes = bytes ?? Uint8List(initialBufferSize);
    bytesView = ByteData.view(this.bytes.buffer);
  }

  int getInt8(int byteOffset) => bytesView.getInt8(byteOffset);
  setInt8(int byteOffset, int value) => bytesView.setInt8(byteOffset, value);

  int getInt16(int byteOffset) => bytesView.getInt16(byteOffset);
  setInt16(int byteOffset, int value) => bytesView.setInt16(byteOffset, value);

  int getInt32(int byteOffset) => bytesView.getInt32(byteOffset);
  setInt32(int byteOffset, int value) => bytesView.setInt32(byteOffset, value);

  int getInt64(int byteOffset) => bytesView.getInt64(byteOffset);
  setInt64(int byteOffset, int value) => bytesView.setInt64(byteOffset, value);

  int getUint8(int byteOffset) => bytesView.getUint8(byteOffset);
  setUint8(int byteOffset, int value) => bytesView.setUint8(byteOffset, value);

  int getUint16(int byteOffset) => bytesView.getUint16(byteOffset);
  setUint16(int byteOffset, int value) =>
      bytesView.setUint16(byteOffset, value);

  int getUint32(int byteOffset) => bytesView.getUint32(byteOffset);
  setUint32(int byteOffset, int value) =>
      bytesView.setUint32(byteOffset, value);

  int getUint64(int byteOffset) => bytesView.getUint64(byteOffset);
  setUint64(int byteOffset, int value) =>
      bytesView.setUint64(byteOffset, value);

  // double getFloat8(int byteOffset) => bytesView.getFloat8(byteOffset);
  // setFloat8(int byteOffset, double value) => bytesView.setFloat8(byteOffset, value);

  // double getFloat16(int byteOffset) => bytesView.getFloat16(byteOffset);
  // setFloat16(int byteOffset, double value) =>
  //     bytesView.setFloat16(byteOffset, value);

  double getFloat32(int byteOffset) => bytesView.getFloat32(byteOffset);
  setFloat32(int byteOffset, double value) =>
      bytesView.setFloat32(byteOffset, value);

  double getFloat64(int byteOffset) => bytesView.getFloat64(byteOffset);
  setFloat64(int byteOffset, double value) =>
      bytesView.setFloat64(byteOffset, value);

  Uint8List getBytes(int start, [int? end]) => bytes.sublist(start, end);
  setBytes(int byteOffset, List<int> list) {
    bytes.setAll(byteOffset, list);
  }

  int get length => bytes.length;

  resize(int pos, int size) {
    // raw.add(Uint8List.view(bytes.buffer, 0, pos));
    var prevBytes = Uint8List.view(bytes.buffer, 0, pos);
    bytes = Uint8List(size);
    bytesView = ByteData.view(bytes.buffer);

    bytes.setAll(0, prevBytes);
  }

  Uint8List view(int bytesOffset, int length) {
    return Uint8List.view(bytes.buffer, bytesOffset, length);
  }
}
