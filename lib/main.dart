// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Image Picker Demo',
      home: MyHomePage(title: 'Image Picker Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String>? _imagePathList;

  void _setImageFileListFromFile(String? path) {
    print('image path: ${path}');
    _imagePathList = path == null ? null : <String>[path];
  }

  dynamic _pickImageError;

  String? _retrieveDataError;

  final ImagePicker _picker = ImagePicker();

  // do it when the action page is closed
  Future<void> deleteIOSImageCache() async {
    final appBaseFolder = await getApplicationDocumentsDirectory();
    final appTempFolder = appBaseFolder.path.replaceAll("/Documents", "/tmp");
    final jpegFileList = await Directory(appTempFolder).list().where((element) => element.path.endsWith(".jpg")).toList();
    for (var file in jpegFileList) {
      await file.delete();
    }
  }

  // do it when the action page is closed
  Future<void> deleteAndroidImageCache() async {
    final appTempFolder = await getTemporaryDirectory();
    final jpegFileList = await appTempFolder.list().where((element) => element.path.endsWith(".jpg")).toList();
    for (var file in jpegFileList) {
      await file.delete();
    }
  }

  Future<void> createPhotoDirectoryIfNotExists() async {
    final appBaseFolder = Platform.isAndroid ? await getExternalStorageDirectory() : await getApplicationDocumentsDirectory();
    final appBaseFolderPath = appBaseFolder?.path;
    if (appBaseFolderPath == null) return;
    final photosDirectory = Directory('$appBaseFolderPath/photos');
    if (!await photosDirectory.exists()) {
      await photosDirectory.create();
    }
  }

  Future<void> deletePhotoDirectory() async {
    final appBaseFolder = Platform.isAndroid ? await getExternalStorageDirectory() : await getApplicationDocumentsDirectory();
    final appBaseFolderPath = appBaseFolder?.path;
    if (appBaseFolderPath == null) return;
    final photosDir = Directory('$appBaseFolderPath/photos');
    if (await photosDir.exists()) {
      await photosDir.delete(recursive: true);
    }
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 0), () async {
      final appDocDir = await getExternalStorageDirectory().then((dir) => dir?.path ?? '');
      final appDocPath = '$appDocDir/photos';
      final jpegFileList = await Directory(appDocPath).list().where((element) => element.path.endsWith(".jpg")).toList();
      print('list files');
      for (var file in jpegFileList) {
        print(file.path);
      }
    });
  }

  Future<void> _pickImageFromGallery(BuildContext context) async {
    if (Platform.isIOS) {
      var status = await Permission.photos.status;
      if (status.isDenied) {
        final result = await Permission.photos.request();
        if (result.isDenied) {
          return;
        }
      } else if (status.isPermanentlyDenied) {
        await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Permission denied'),
                content: const Text('Please enable access to the photo library in settings'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              );
            });
      }
    }

    try {
      final pickedXFileList = await _picker.pickMultiImage();
      final pickedFilePathList = pickedXFileList.map((xfile) => xfile.path).toList();
      setState(() {
        _imagePathList = pickedFilePathList;
      });
    } catch (e) {
      setState(() {
        _pickImageError = e;
      });
    }
  }

  Future<void> _pickImageFromCamera(BuildContext context) async {
    if (Platform.isIOS) {
      var status = await Permission.camera.status;
      print(status);
      if (status.isDenied) {
        final result = await Permission.camera.request();
        if (result.isDenied) {
          return;
        }
      } else if (status.isPermanentlyDenied) {
        await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Permission denied'),
                content: const Text('Please enable access to the camera in settings'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            });
      }
    }

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
      );
      final appBaseFolder = Platform.isAndroid ? await getExternalStorageDirectory() : await getApplicationDocumentsDirectory();
      if (pickedFile?.path != null || appBaseFolder != null) {
        await createPhotoDirectoryIfNotExists();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final photoFilename = 'FR_$timestamp';
        final photoFilePath = '${appBaseFolder!.path}/photos/$photoFilename.jpg';
        final photoFile = await File(pickedFile!.path).copy(photoFilePath);
        await ImageGallerySaver.saveFile(pickedFile.path);
        setState(() {
          _setImageFileListFromFile(photoFile.path);
        });
      }
    } catch (e) {
      setState(() {
        _pickImageError = e;
      });
    }
  }

  Widget _previewImages() {
    final Text? retrieveError = _getRetrieveErrorWidget();
    if (retrieveError != null) {
      return retrieveError;
    }
    if (_imagePathList != null) {
      return Semantics(
        label: 'image_picker_example_picked_images',
        child: ListView.builder(
          key: UniqueKey(),
          itemBuilder: (BuildContext context, int index) {
            // Why network for web?
            // See https://pub.dev/packages/image_picker#getting-ready-for-the-web-platform
            return Semantics(
              label: 'image_picker_example_picked_image',
              child: kIsWeb ? Image.network(_imagePathList![index]) : Image.file(File(_imagePathList![index])),
            );
          },
          itemCount: _imagePathList!.length,
        ),
      );
    } else if (_pickImageError != null) {
      return Text(
        'Pick image error: $_pickImageError',
        textAlign: TextAlign.center,
      );
    } else {
      return const Text(
        'You have not yet picked an image.',
        textAlign: TextAlign.center,
      );
    }
  }

  Widget _handlePreview() {
    return _previewImages();
  }

  Future<void> retrieveLostData() async {
    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty) {
      return;
    }
    if (response.file != null) {
      setState(() {
        if (response.files == null) {
          _setImageFileListFromFile(response.file?.path);
        } else {
          _imagePathList = response.files?.map((xfile) => xfile.path).toList();
        }
      });
    } else {
      _retrieveDataError = response.exception!.code;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title!),
      ),
      body: Center(
        child: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? FutureBuilder<void>(
                future: retrieveLostData(),
                builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
                  switch (snapshot.connectionState) {
                    case ConnectionState.none:
                    case ConnectionState.waiting:
                      return const Text(
                        'You have not yet picked an image.',
                        textAlign: TextAlign.center,
                      );
                    case ConnectionState.done:
                      return _handlePreview();
                    default:
                      if (snapshot.hasError) {
                        return Text(
                          'Pick image error: ${snapshot.error}}',
                          textAlign: TextAlign.center,
                        );
                      } else {
                        return const Text(
                          'You have not yet picked an image.',
                          textAlign: TextAlign.center,
                        );
                      }
                  }
                },
              )
            : _handlePreview(),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: FloatingActionButton(
              onPressed: () async {
                if (Platform.isAndroid) {
                  await deleteAndroidImageCache();
                } else if (Platform.isIOS) {
                  await deleteIOSImageCache();
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image cache deleted')));
              },
              heroTag: 'image4',
              tooltip: 'Delete image from cache',
              child: const Icon(Icons.delete_outline),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: FloatingActionButton(
              onPressed: () async {
                await deletePhotoDirectory();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image folder deleted')));
              },
              heroTag: 'image3',
              tooltip: 'Delete image from app folder',
              child: const Icon(Icons.delete_forever),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: FloatingActionButton(
              onPressed: () => _pickImageFromGallery(context),
              heroTag: 'image1',
              tooltip: 'Pick Multiple Image from gallery',
              child: const Icon(Icons.photo_library),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: FloatingActionButton(
              onPressed: () => _pickImageFromCamera(context),
              heroTag: 'image2',
              tooltip: 'Take a Photo',
              child: const Icon(Icons.camera_alt),
            ),
          ),
        ],
      ),
    );
  }

  Text? _getRetrieveErrorWidget() {
    if (_retrieveDataError != null) {
      final Text result = Text(_retrieveDataError!);
      _retrieveDataError = null;
      return result;
    }
    return null;
  }
}

typedef OnPickImageCallback = void Function(double? maxWidth, double? maxHeight, int? quality);
