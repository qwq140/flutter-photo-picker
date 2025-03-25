import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_photo_select_example/permission_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

void showPhotoPickerModal(BuildContext context,
    {bool multiSelect = false,
    required Function(List<File>) onSelectedImages}) {
  final mediaQuery = MediaQuery.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 1,
        builder: (context, scrollController) {
          return PhotoPickerModal(
            mediaQuery: mediaQuery,
            multiSelect: multiSelect,
            onSelectImages: onSelectedImages,
          );
        },
      );
    },
  );
}

class PhotoPickerModal extends StatefulWidget {
  final MediaQueryData mediaQuery;
  final bool multiSelect;
  final Function(List<File>) onSelectImages;

  const PhotoPickerModal(
      {super.key,
      required this.multiSelect,
      required this.onSelectImages,
      required this.mediaQuery});

  @override
  _PhotoPickerModalState createState() => _PhotoPickerModalState();
}

class _PhotoPickerModalState extends State<PhotoPickerModal> {
  List<AssetEntity> _imageList = [];
  List<AssetEntity> _selectedImageList = [];
  List<AssetPathEntity> _albumList = [];
  AssetPathEntity? _selectedAlbum;

  int _currentPage = 0; // 현재 페이지
  final int _pageSize = 30; // 한 번에 로드할 이미지 개수

  final ScrollController _scrollController = ScrollController();

  bool _isRefresh = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        bool isGranted = await _checkPermission();
        if (isGranted) {
          _loadAlbumList();
        } else {
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (_selectedAlbum == null) return;
      _loadImageList(_selectedAlbum!);
    }
  }

  // 권한 체크
  Future<bool> _checkPermission() async {
    bool isCameraGranted = await PermissionUtils.checkCameraPermission(context, mounted);
    bool isGalleryGranted =  await PermissionUtils.checkGalleryPermission(context, mounted);
    return isCameraGranted && isGalleryGranted;
  }

  // 앨범 목록 불러오기
  Future<void> _loadAlbumList() async {
    final fetchedAlbumList =
        await PhotoManager.getAssetPathList(type: RequestType.image);

    if (fetchedAlbumList.isEmpty) return;

    setState(() {
      _albumList = fetchedAlbumList;
      _selectedAlbum = _albumList.first;
    });
    _loadImageList(_selectedAlbum!, albumChanged: true);
  }

  // 해당 앨범의 이미지 불러오기
  Future<void> _loadImageList(AssetPathEntity album,
      {bool albumChanged = false}) async {
    if (albumChanged) {
      _isRefresh = true;
      _currentPage = 0;
    } else {
      // 앨범 변경을 안한 경우는 스크롤을 내려서 불러오는 경우
      final totalImagesCount = await album.assetCountAsync;
      if (_imageList.length == totalImagesCount) {
        return;
      }
    }

    final assets =
        await album.getAssetListPaged(page: _currentPage, size: _pageSize);

    setState(() {
      if (albumChanged) {
        _imageList = assets;
      } else {
        _imageList.addAll(assets);
      }
      _currentPage++;
      _isRefresh = false;
    });
  }

  void _onImageTap(AssetEntity image) {
    if (widget.multiSelect) {
      setState(() {
        _selectedImageList.contains(image)
            ? _selectedImageList.remove(image)
            : _selectedImageList.add(image);
      });
    } else {
      setState(() {
        _selectedImageList.contains(image)
            ? _selectedImageList.remove(image)
            : _selectedImageList = [image];
      });
    }
  }

  void _onCameraTap() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      widget.onSelectImages.call([File(pickedFile.path)]);
      Navigator.of(context).pop();
    }
  }

  void _onComplete() async {
    List<File> imageFiles = [];
    for (var image in _selectedImageList) {
      final file = await image.file;
      if (file != null) {
        imageFiles.add(file);
      }
    }
    widget.onSelectImages.call(imageFiles);

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: widget.mediaQuery.padding.top,
        bottom: widget.mediaQuery.padding.bottom,
      ),
      child: Column(
        children: [
          _AppBar(
            albumList: _albumList,
            selectedAlbum: _selectedAlbum,
            onComplete: _selectedImageList.isNotEmpty ? _onComplete : null,
            onAlbumChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedAlbum = value;
                });
                _loadImageList(value, albumChanged: true);
              }
            },
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: _isRefresh
                ? Center(child: CircularProgressIndicator())
                : _PhotoGridView(
                    imageList: _imageList,
                    selectedImageList: _selectedImageList,
                    scrollController: _scrollController,
                    onImageTap: _onImageTap,
                    onCameraTap: _onCameraTap,
                  ),
          ),
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  final AssetPathEntity? selectedAlbum;
  final List<AssetPathEntity> albumList;
  final ValueChanged<AssetPathEntity?> onAlbumChanged;
  final VoidCallback onClose;
  final VoidCallback? onComplete;

  const _AppBar({
    super.key,
    this.selectedAlbum,
    required this.albumList,
    required this.onAlbumChanged,
    required this.onClose,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 24),
            ),
            TextButton(
              onPressed: onComplete,
              child: Text('완료'),
            ),
          ],
        ),
        Align(
          alignment: Alignment.center,
          child: Container(
            child: albumList.isNotEmpty
                ? DropdownButton(
                    value: selectedAlbum,
                    dropdownColor: Colors.white,
                    items: albumList.map((album) {
                      return DropdownMenuItem(
                        value: album,
                        child: Text(
                          album.isAll ? '최근항목' : album.name,
                        ),
                      );
                    }).toList(),
                    onChanged: onAlbumChanged,
                    underline: const SizedBox.shrink(),
                  )
                : const SizedBox(),
          ),
        ),
      ],
    );
  }
}

class _PhotoGridView extends StatelessWidget {
  final List<AssetEntity> imageList;
  final List<AssetEntity> selectedImageList;
  final ScrollController scrollController;
  final Function(AssetEntity) onImageTap;
  final VoidCallback onCameraTap;

  const _PhotoGridView({
    super.key,
    required this.imageList,
    required this.selectedImageList,
    required this.scrollController,
    required this.onImageTap,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8.5),
      controller: scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: imageList.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return GestureDetector(
            onTap: () => onCameraTap.call(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.grey,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt),
                    Text('촬영하기')
                  ],
                ),
              ),
            ),
          );
        }

        final image = imageList[index - 1];
        final isSelected = selectedImageList.contains(image);

        return GestureDetector(
          onTap: () => onImageTap(image),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AssetEntityImage(
                  image,
                  isOriginal: false,
                  thumbnailSize: const ThumbnailSize.square(200),
                  fit: BoxFit.cover,
                ),
              ),
              if (isSelected)
                Container(
                  decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber, width: 3)),
                ),
              Positioned(
                top: 0,
                right: 0,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (value) {},
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)
                  ),
                  checkColor: Colors.white,
                  activeColor: Colors.amber,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
