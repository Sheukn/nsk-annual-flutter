import 'package:flutter/material.dart';
import 'package:flutter_pa_snk/features/postit/postit_edit_view.dart';
import 'package:flutter_pa_snk/models/board_item.dart';
import 'widgets/board_item_widget.dart';
import 'widgets/control_sliders.dart';
import 'widgets/board_action_menu.dart';

class BoardView extends StatefulWidget {
  const BoardView({super.key});

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  final List<BoardItem> _items = [];
  final List<BoardItem> _selectedItem = [];

  BoardItem? get activeItem =>
      _selectedItem.length == 1 ? _selectedItem.first : null;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mon Tableau de Bord")),
      body: Stack(
        children: [
          InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(500),
            minScale: 0.1,
            maxScale: 2.5,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap:
                  () => {
                    setState(() {
                      _selectedItem.clear();
                    }),
                  },
              child: Container(
                color: const Color.fromARGB(255, 182, 168, 81),
                width: 1000,
                height: 1000,
                child: Stack(
                  children:
                      _items
                          .map(
                            (item) => BoardItemWidget(
                              item: item,
                              isSelected: _selectedItem.contains(item),
                              onTap: () => _handleItemTap(item),
                              onLongPress: () => _handleItemLongPress(item),
                              onScaleStart:
                                  (details) =>
                                      _handleItemScaleStart(item, details),
                              onScaleUpdate:
                                  (details) =>
                                      _handleItemScaleUpdate(item, details),
                            ),
                          )
                          .toList(),
                ),
              ),
            ),
          ),
          if (_selectedItem.length == 1 && activeItem != null) ...[
            RotationSlider(
              rotation: activeItem!.rotation,
              onChanged:
                  (value) => setState(() => activeItem!.rotation = value),
            ),
            SizeSlider(
              width: activeItem!.size.width,
              onChanged:
                  (value) => setState(() {
                    activeItem!.size = Size(
                      width: value,
                      height:
                          value *
                          (activeItem!.size.height / activeItem!.size.width),
                    );
                  }),
            ),
          ],
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: BoardActionMenu(
                selectedItems: _selectedItem,
                onAddImage: _addImage,
                onAddPostIt: _addPostIt,
                onDelete: _deleteSelected,
                onChangeColor: _changeColor,
                onBringToFront: _bringToFront,
                onSendToBack: _sendToBack,
                onEdit:
                    _selectedItem.length == 1 && !_selectedItem.first.isImage
                        ? _editPostIt
                        : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleItemTap(BoardItem item) {
    setState(() {
      if (_selectedItem.length == 1 && !_selectedItem.contains(item)) {
        _selectedItem.clear();
        _selectedItem.add(item);
      } else {
        if (_selectedItem.contains(item)) {
          _selectedItem.remove(item);
        } else {
          _selectedItem.add(item);
        }
      }
    });
  }

  void _handleItemLongPress(BoardItem item) {
    setState(() {
      if (_selectedItem.contains(item)) {
        _selectedItem.remove(item);
      } else {
        _selectedItem.add(item);
      }
    });
  }

  void _handleItemScaleStart(BoardItem item, ScaleStartDetails details) {
    if (_selectedItem.contains(item) && _selectedItem.length == 1) {
      item.size = Size(width: item.size.width, height: item.size.height);
      item.position = Position(x: item.position.x, y: item.position.y);
    }
  }

  void _handleItemScaleUpdate(BoardItem item, ScaleUpdateDetails details) {
    setState(() {
      item.position.x += details.focalPointDelta.dx;
      item.position.y += details.focalPointDelta.dy;
    });
  }

  void _addImage() {
    setState(() {
      _items.add(
        BoardItem(
          id: 'Image ${_items.length + 1}',
          position: Position(x: 400, y: 400),
          size: Size(width: 200, height: 150),
          color: Colors.grey,
          rotation: 0,
          isImage: true,
        ),
      );
    });
  }

  void _addPostIt() {
    setState(() {
      _items.add(
        BoardItem(
          id: 'Post-it ${_items.length + 1}',
          position: Position(x: 400, y: 400),
          size: Size(width: 150, height: 150),
          color: Colors.yellow,
          rotation: 0,
          isImage: false,
        ),
      );
    });
  }

  void _deleteSelected() {
    setState(() {
      _items.removeWhere((item) => _selectedItem.contains(item));
      _selectedItem.clear();
    });
  }

  void _changeColor() {
    setState(() {
      for (var item in _selectedItem) {
        item.color =
            Colors.primaries[DateTime.now().millisecondsSinceEpoch %
                Colors.primaries.length];
      }
    });
  }

  void _bringToFront() {
    setState(() {
      for (var item in _selectedItem) {
        _items.remove(item);
        _items.add(item);
      }
    });
  }

  void _sendToBack() {
    setState(() {
      for (var item in _selectedItem) {
        _items.remove(item);
        _items.insert(0, item);
      }
    });
  }

  void _editPostIt() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PostItEditView()),
    );
  }
}
