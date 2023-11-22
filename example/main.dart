import 'dart:convert';
import 'package:datapacker/datapacker.dart';

void main() async {
  var dataPacker = DataPacker();

  var payload = {
    'sender': {
      'name': 'Alice',
    },
    'message': 'Hi',
    'sent_at': DateTime.now().toIso8601String(),
    'is_delivered': false
  };

  var datapackerSerialized = dataPacker.serialize(payload);
  // var datapackerDeserialized = dataPacker.deserialize(datapackerSerialized);

  var jsonSerialized = jsonEncode(payload);
  // var jsonDeserialized = jsonDecode(jsonSerialized);

  print(datapackerSerialized.length); // <---- 75 bytes
  // (Dates preprocessed to ISO-8601, Uint8List preprocessed to Base64)
  print(jsonSerialized.length); // <---- 102 bytes
}
