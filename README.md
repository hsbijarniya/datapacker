Serialize data into binary format.

## Features

+ Upto 30% length reduction compared to JSON.
+ No size & encoding overhead of Base64 as binary data will be directly used without any encoding/processing.

## Getting started

Initialize the class instance.

```dart
var dataPacker = DataPacker(
    dateAsString: false,
);
```

## Usage

```dart
const payload = {
    'sender': {
        'name': 'Alice'
    },
    'message': 'Hi',
    'sent_at': DateTime.now(),
    'is_delivered': false
};

var datapackerSerialized = dataPacker.serialize(payload);
var datapackerDeserialized = dataPacker.deserialize(datapackerSerialized);
```

## JSON Comparison

```dart
var jsonSerialized = jsonEncode(payload);
var jsonDeserialized = jsonDecode(jsonSerialized);

print(datapackerSerialized.length); // <---- 75 bytes
//(Dates preprocessed to ISO-8601, Uint8List preprocessed to Base64)
print(jsonSerialized.length); // <---- 102 bytes
```

## MIT License

Copyright (c) 2023 hsbijarniya@gmail.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
