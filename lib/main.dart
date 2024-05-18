import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const ImageScreen(title: 'Art Box'),
    );
  }
}

class ImageScreen extends StatefulWidget {
  final String title;
  const ImageScreen({Key? key, required this.title}) : super(key: key);

  @override
  State<ImageScreen> createState() => _TestState();
}

class _TestState extends State<ImageScreen> {
  bool isTextEmpty = true;
  TextEditingController textController = TextEditingController();
  final List<ChatMessage> messages = [];
  bool isGeneratingImage = false;
  Uint8List? pickedImageBytes;
  String frontImageUrl = "";
  Future<List<Uint8List>> _generate(String query, Uint8List? backImage) async {
    textController.clear();
    setState(() {
      isTextEmpty = true;
    });
    String backImageUrl = "";
    if (backImage != null) {
      backImageUrl = "data:image/png;base64,${base64.encode(backImage)}";
    }
    String token =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiOTBkOTAyOTctYWIyNi00Yjc2LTg1ZGYtNGNkOGIyMGMyYTM5IiwidHlwZSI6ImFwaV90b2tlbiJ9.c3opsDhqMgzel_Z5z5fHs_RrDkVwN2z8Y7MIlLHo9bw";

    String url = "https://api.edenai.run/v2/image/generation";
    var headers = {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };

    var payload = {
      "providers": "openai",
      "text": "Generate 3 tattoos for $query with backgroud as $backImageUrl",
      "image": "$backImageUrl",
      "resolution": "1024x1024",
      "fallback_providers": "microsoft"
    };

    try {
      http.Response response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(payload),
      );
      print('Request response :  ${response.body}');
      if (response.statusCode == 200) {
        var result = json.decode(response.body);
        var items = result['openai']['items'];
        List<Uint8List> images = [];
        for (var item in items) {
          var img = item['image'];
          frontImageUrl = item['image_resource_url'];
          print("item : $img");
          images.add(base64.decode(img));
        }
        return images;
      } else {
        print('Request failed with status: ${response.body}');
      }
    } catch (e) {
      print('Error occurred: $e');
    }

    return [];
  }

  Future<Uint8List> _overlayImage(
      Uint8List frontImage, Uint8List backImage) async {
    String url = "https://v2.1saas.co/image/overlay";
    var headers = {
      "Content-Type": "application/json",
      "auth": "458260ad-2b00-4745-a4ee-5852a3d0a0a2",
    };

    String backImageUrl = "data:image/png;base64,${base64.encode(backImage)}";
    var payload = {
      "frontImageUrl": frontImageUrl,
      "backImageUrl": backImageUrl,
      "options": {
        "opacity": 0.6,
      },
    };

    try {
      http.Response response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(payload),
      );
      print('Overlay response: ${response.body}');
      if (response.statusCode == 200) {
        var result = json.decode(response.body);
        var items = result['openai']['items'];
        var overlayImg = items[0]['image'];
        return base64.decode(overlayImg);
      } else {
        print('Overlay failed with status: ${response.body}');
      }
    } catch (e) {
      print('Error occurred: $e');
    }

    return Uint8List(0);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      pickedImageBytes = await pickedFile.readAsBytes();
    }
  }

  @override
  void dispose() {
    textController.dispose();
    textController.clear();
    super.dispose();
  }

  void _sendMessage() async {
    final text = textController.text;
    if (text.isNotEmpty) {
      setState(() {
        messages.add(ChatMessage(text: text, isImage: false));
        isTextEmpty = false;
        isGeneratingImage = true;
      });

      final imageBytesList = await _generate(text, "" as Uint8List?);
      if (imageBytesList.isNotEmpty) {
        Uint8List? overlayedImage;
        if (pickedImageBytes != null) {
          overlayedImage =
              (await _generate(text, pickedImageBytes)) as Uint8List?;
        }
        setState(() {
          messages.add(ChatMessage(
            imageBytesList:
                pickedImageBytes != null ? [overlayedImage!] : imageBytesList,
            isImage: true,
          ));
          isGeneratingImage = false;
        });
      }

      textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: message.isImage
                      ? Column(
                          children: message.imageBytesList!.map((imageBytes) {
                            return Image.memory(imageBytes);
                          }).toList(),
                        )
                      : Container(
                          constraints: BoxConstraints(
                            minWidth: 0,
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            message.text!,
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.image),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: textController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Text',
                    ),
                    onSubmitted: (value) => _sendMessage(),
                    enabled: !isGeneratingImage,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: isGeneratingImage ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String? text;
  final List<Uint8List>? imageBytesList;
  final bool isImage;

  ChatMessage({this.text, this.imageBytesList, required this.isImage});
}
