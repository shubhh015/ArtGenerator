import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
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
      home: const HomeScreen(title: 'Art Generator'),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String title;
  const HomeScreen({Key? key, required this.title}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  bool isTextEmpty = true;
  TextEditingController textController = TextEditingController();
  final List<ChatMessage> messages = [];
  bool isGeneratingImage = false;
  Uint8List? pickedImageBytes;
  String frontImageUrl = "";
  Future<List<Uint8List>> _generate(String query) async {
    textController.clear();
    setState(() {
      isTextEmpty = true;
    });

    String token =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYzg5MWUxYWMtN2Y0Ni00YmVhLWJhMTQtOWFjMTBhNDkyZjVhIiwidHlwZSI6ImZyb250X2FwaV90b2tlbiJ9.--uMX1nPxhW2iq1AUy0apZcWYUNi1XFnd-cImcXYBuQ";

    String url = "https://api.edenai.run/v2/image/generation";
    var headers = {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };

    var payload = {
      "providers": "openai",
      "text": "Generate  $query",
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

  Future<Uint8List> mergeImages(
      Uint8List image1Bytes, Uint8List image2Bytes) async {
    img.Image image1 = img.decodeImage(image1Bytes)!;
    img.Image image2 = img.decodeImage(image2Bytes)!;

    // Create a new image with the dimensions of image2
    img.Image mergedImage =
        img.Image(width: image2.width, height: image2.height);
    img.Image resizedImage1 =
        img.copyResize(image1, width: (image2.width * 0.5).toInt());

    img.compositeImage(mergedImage, image2, dstX: 0, dstY: 0);
    img.compositeImage(mergedImage, resizedImage1,
        dstX: (image2.width / 2 - resizedImage1.width / 2).toInt(),
        dstY: (image2.height / 2 - resizedImage1.height / 2).toInt());

    // Encode the merged image to a Uint8List
    return Uint8List.fromList(img.encodeJpg(mergedImage));
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

      final imageBytesList = await _generate(text);
      if (imageBytesList.isNotEmpty) {
        Uint8List? overlayedImage;
        if (pickedImageBytes != null) {
          overlayedImage =
              await mergeImages(imageBytesList.first, pickedImageBytes!);
          ;
        }
        setState(() {
          messages.add(ChatMessage(
            imageBytesList:
                pickedImageBytes != null ? [overlayedImage!] : imageBytesList,
            isImage: true,
          ));
          pickedImageBytes = null;
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
        backgroundColor: Colors.redAccent[200],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.format_list_bulleted),
            onPressed: () => {},
          ),
        ],
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
                            color: const Color.fromARGB(255, 200, 215, 200),
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
                  icon: const Icon(Icons.image_rounded),
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
                  icon: const Icon(Icons.send),
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
