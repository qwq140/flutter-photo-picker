import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_photo_select_example/permission_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

void showPhotoPickerModal(BuildContext context, {bool multiSelect = false, required Function(List<XFile>) onSelectedImages}) {
  final mediaQuery = MediaQuery.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
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
  final Function(List<XFile>) onSelectImages;

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
  Map<AssetEntity, Uint8List?> _imageCache = {};

  int _currentPage = 0; // 현재 페이지
  final int _pageSize = 30; // 한 번에 로드할 이미지 개수
  bool _isLoading = false;

  final ScrollController _scrollController = ScrollController();

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
    if(_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if(_selectedAlbum == null) return;
      _loadImageList(_selectedAlbum!);
    }
  }

  // 권한 체크
  Future<bool> _checkPermission() async {
    return await PermissionUtils.checkGalleryPermission(context, mounted);
  }

  // 앨범 목록 불러오기
  Future<void> _loadAlbumList() async {
    final fetchedAlbumList = await PhotoManager.getAssetPathList(type: RequestType.image);

    if (fetchedAlbumList.isEmpty) return;

    setState(() {
      _albumList = fetchedAlbumList;
      _selectedAlbum = _albumList.first;
    });
    _loadImageList(_selectedAlbum!, albumChanged: true);
  }

  // 해당 앨범의 이미지 불러오기
  Future<void> _loadImageList(AssetPathEntity album, {bool albumChanged = false}) async {
    if(_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    if(albumChanged) {
      _currentPage = 0;
    }

    final assets = await album.getAssetListPaged(page: _currentPage, size: _pageSize);
    final Map<AssetEntity, Uint8List?> newCache = {};

    for (var asset in assets) {
      newCache[asset] = await asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
    }

    setState(() {
      if(albumChanged) {
        _imageList = assets;
        _imageCache = newCache;
      } else {
        _imageList.addAll(assets);
        _imageCache.addAll(newCache);
      }
      _isLoading = false;
      _currentPage++;
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
        _selectedImageList = [image];
      });
    }
  }

  void _onCameraTap() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      widget.onSelectImages.call([pickedFile]);
      Navigator.of(context).pop();
    }
  }

  void _onComplete() async {
    List<XFile> imageFiles = [];
    for(var image in _selectedImageList) {
      final file = await image.file;
      if(file != null) {
        imageFiles.add(XFile(file.path));
      }
    }
    widget.onSelectImages.call(imageFiles);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            child: _PhotoGridView(
              imageList: _imageList,
              selectedImageList: _selectedImageList,
              imageCache: _imageCache,
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
    return Row(
      children: [
        IconButton(
          onPressed: onClose,
          icon: Icon(Icons.close),
        ),
        Spacer(),
        Container(
          child: albumList.isNotEmpty
              ? DropdownButton(
                  value: selectedAlbum,
                  items: albumList.map((album) {
                    return DropdownMenuItem(
                      value: album,
                      child: Text(album.isAll ? '모든 사진' : album.name),
                    );
                  }).toList(),
                  onChanged: onAlbumChanged,
                )
              : const SizedBox(),
        ),
        Spacer(),
        TextButton(
          onPressed: onComplete,
          child: Text('완료'),
        ),
      ],
    );
  }
}

class _PhotoGridView extends StatelessWidget {
  final List<AssetEntity> imageList;
  final List<AssetEntity> selectedImageList;
  final Map<AssetEntity, Uint8List?> imageCache;
  final ScrollController scrollController;
  final Function(AssetEntity) onImageTap;
  final VoidCallback onCameraTap;

  const _PhotoGridView({
    super.key,
    required this.imageList,
    required this.selectedImageList,
    required this.imageCache,
    required this.scrollController,
    required this.onImageTap,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      controller: scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: imageList.length + 1,
      itemBuilder: (context, index) {
        if(index == 0) {
          return GestureDetector(
            onTap: () => onCameraTap.call(),
            child: Icon(Icons.camera_alt),
          );
        }

        final image = imageList[index - 1];
        final isSelected = selectedImageList.contains(image);
        final imageData = imageCache[image];

        return GestureDetector(
          onTap: imageData != null ? () => onImageTap(image) : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageData == null)
                const Center(child: Icon(Icons.image_not_supported, size: 40))
              else
                Image.memory(imageData, fit: BoxFit.cover),
              if (imageData != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      color: isSelected ? Colors.blue : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
