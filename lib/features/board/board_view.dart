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

  BoardItem? get activeItem => _selectedItem.length == 1 ? _selectedItem.first : null;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mon Tableau de Bord")),
      body: Stack(
        children: [
          InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(
              500,
            ),
            minScale: 0.1,
            maxScale: 2.5,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () => {
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
                  color: Colors.grey.withOpacity(
                    0.8,
                  ), 
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
                          onChanged: (value) =>
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
                          onChanged: (value) => setState(() {
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
        onScaleStart: (details) => {
          if (_selectedItem.contains(item) && _selectedItem.length == 1)
            {
              item.size = Size(
                width: item.size.width,
                height: item.size.height,
              ),
              item.position = Position(x: item.position.x, y: item.position.y),
            },
        },
        onScaleUpdate: (details) {
          setState(() {
            // Drag to move
            item.position.x += details.focalPointDelta.dx;
            item.position.y += details.focalPointDelta.dy;
          });
        },
        onLongPress: () => {
          setState(() {
            if (_selectedItem.contains(item)) {
              _selectedItem.remove(item);
            } else {
              _selectedItem.add(item);
            }
          }),
        },
        onTap: () => {
          setState(() {
            print(item.id);
          }),
        },
        child: Transform.rotate(
          angle: item.rotation,
          child: Container(
            width: item.size.width,
            height: item.size.height,
            decoration: BoxDecoration(
              color: item.color,
              border: _selectedItem.contains(item)
                  ? Border.all(color: Colors.blue, width: 3)
                  : null,
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
      // Largeur dynamique : 56 si rien, sinon environ 250 pour les icônes
      width: isSelected ? 260 : 56,
      height: 56,
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue : Colors.blue,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [const BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isSelected
            ? _buildEditActions() // Ton Row avec les icônes blanches
            : _buildAddButton(), // Juste l'icône +
      ),
    );
  }

  Widget _buildAddButton() {
    return FloatingActionButton(
      onPressed: () {
        setState(() {
          _items.add(
            BoardItem(
              id: "Item ${_items.length + 1}",
              color:
                  Colors.primaries[DateTime.now().millisecondsSinceEpoch %
                      Colors.primaries.length],
              position: Position(x: 100, y: 100),
              size: Size(width: 100, height: 100),
            ),
          );
        });
      },
      child: const Icon(Icons.add),
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
      ],
    );
  }
}
