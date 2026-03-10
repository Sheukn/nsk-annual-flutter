import 'package:flutter/material.dart';
import 'package:flutter_pa_snk/models/board_item.dart';

const double pi = 3.14159;

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
                child: Stack(children: _items.map(_buildItemWidget).toList()),
              ),
            ),
          ),
          if (_selectedItem.length == 1 && activeItem != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(left: 10),
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 1,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.rotate_right,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 200,
                      width: 40,
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          value: activeItem!.rotation,
                          min: -pi,
                          max: pi,
                          activeColor: Colors.blueAccent,
                          inactiveColor: Colors.white24,
                          onChanged:
                              (value) =>
                                  setState(() => activeItem!.rotation = value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 1,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(
                    0.8,
                  ), // Fond sombre transparent
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.aspect_ratio,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(
                      height: 200,
                      width: 40,
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          value: activeItem!.size.width,
                          min: 50,
                          max: 500,
                          activeColor: Colors.blueAccent,
                          inactiveColor: Colors.white24,
                          onChanged:
                              (value) => setState(() {
                                activeItem!.size = Size(
                                  width: value,
                                  height:
                                      value *
                                      (activeItem!.size.height /
                                          activeItem!.size.width),
                                );
                              }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildAnimatedMenu(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemWidget(BoardItem item) {
    return Positioned(
      left: item.position.x,
      top: item.position.y,
      child: GestureDetector(
        onScaleStart:
            (details) => {
              if (_selectedItem.contains(item) && _selectedItem.length == 1)
                {
                  item.size = Size(
                    width: item.size.width,
                    height: item.size.height,
                  ),
                  item.position = Position(
                    x: item.position.x,
                    y: item.position.y,
                  ),
                },
            },
        onScaleUpdate: (details) {
          setState(() {
            // Drag to move
            item.position.x += details.focalPointDelta.dx;
            item.position.y += details.focalPointDelta.dy;
          });
        },
        onTap:
            () => {
              setState(() {
                if (_selectedItem.length == 1 &&
                    !_selectedItem.contains(item)) {
                  _selectedItem.clear();
                  _selectedItem.add(item);
                } else {
                  if (_selectedItem.contains(item)) {
                    _selectedItem.remove(item);
                  } else {
                    _selectedItem.add(item);
                  }
                }
              }),
            },
        onLongPress:
            () => {
              setState(() {
                if (_selectedItem.contains(item)) {
                  _selectedItem.remove(item);
                } else {
                  _selectedItem.add(item);
                }
              }),
            },
        child: Transform.rotate(
          angle: item.rotation,
          child: Container(
            width: item.size.width,
            height: item.size.height,
            decoration: BoxDecoration(
              color: item.color,
              border:
                  _selectedItem.contains(item)
                      ? Border.all(color: Colors.blue, width: 3)
                      : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(item.id, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedMenu() {
    bool isSelected = _selectedItem.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: _selectedItem.isNotEmpty && !_selectedItem.first.isImage ? 250 
        : _selectedItem.isNotEmpty ? 200 
        : 120,
      height: 56,
      decoration: BoxDecoration(
        color: _selectedItem.isNotEmpty ? Colors.blue : Colors.blue,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [const BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: Alignment.centerLeft, // keeps growth anchored nicely
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: isSelected
              ? _buildEditActions()
              : _buildAddsButton(),
        ),
      ),
    );
  }

  Widget _buildAddsButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
          onPressed: () {
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
          },
        ),
        IconButton(
          icon: const Icon(Icons.sticky_note_2, color: Colors.white),
          onPressed: () {
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
          },
        ),
      ],
    );
  }

  Widget _buildEditActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.white),
          onPressed: () {
            setState(() {
              _items.removeWhere((item) => _selectedItem.contains(item));
              _selectedItem.clear();
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.color_lens, color: Colors.white),
          onPressed: () {
            setState(() {
              for (var item in _selectedItem) {
                item.color =
                    Colors.primaries[DateTime.now().millisecondsSinceEpoch %
                        Colors.primaries.length];
              }
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.arrow_upward, color: Colors.white),
          onPressed: () {
            setState(() {
              for (var item in _selectedItem) {
                _items.remove(item);
                _items.add(item);
              }
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.arrow_downward, color: Colors.white),
          onPressed: () {
            setState(() {
              for (var item in _selectedItem) {
                _items.remove(item);
                _items.insert(0, item);
              }
            });
          },
        ),
        if (_selectedItem.length == 1 && !_selectedItem.first.isImage)
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              // Placeholder for edit action
            },
          ),
      ],
    );
  }
}
