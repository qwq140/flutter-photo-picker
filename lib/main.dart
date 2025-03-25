import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_photo_select_example/photo_picker_modal.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? selectImage;
  List<File> selectImages = [];

  void _showModal(BuildContext context) {
    showPhotoPickerModal(
      context,
      onSelectedImages: (images) {
        setState(() {
          selectImage = images.first;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('단일 이미지 선택'),
              GestureDetector(
                onTap: () => _showModal(context),
                child: selectImage == null
                    ? CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.black,
                      )
                    : Image.file(
                        File(selectImage!.path),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
              ),
              Text('여러 이미지 선택'),
              ...selectImages.map((e) => Image.file(
                File(e.path),
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),),

            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showPhotoPickerModal(
            context,
            multiSelect: true,
            onSelectedImages: (images) {
              setState(() {
                selectImages = images;
              });
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
