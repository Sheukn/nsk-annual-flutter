import 'package:flutter/material.dart';
import 'package:flutter_pa_snk/models/board_item.dart';

class BoardActionMenu extends StatelessWidget {
  final List<BoardItem> selectedItems;
  final VoidCallback onAddImage;
  final VoidCallback onAddPostIt;
  final VoidCallback onDelete;
  final VoidCallback onChangeColor;
  final VoidCallback onBringToFront;
  final VoidCallback onSendToBack;
  final VoidCallback? onEdit;

  const BoardActionMenu({
    super.key,
    required this.selectedItems,
    required this.onAddImage,
    required this.onAddPostIt,
    required this.onDelete,
    required this.onChangeColor,
    required this.onBringToFront,
    required this.onSendToBack,
    this.onEdit,
  });

  bool get isSelected => selectedItems.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width:
          selectedItems.isNotEmpty && !selectedItems.first.isImage
              ? 250
              : selectedItems.isNotEmpty
              ? 200
              : 120,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: Alignment.centerLeft,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder:
              (child, anim) => FadeTransition(opacity: anim, child: child),
          child: isSelected ? _buildEditActions() : _buildAddButtons(),
        ),
      ),
    );
  }

  Widget _buildAddButtons() {
    return Row(
      key: const ValueKey('add'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
          onPressed: onAddImage,
        ),
        IconButton(
          icon: const Icon(Icons.sticky_note_2, color: Colors.white),
          onPressed: onAddPostIt,
        ),
      ],
    );
  }

  Widget _buildEditActions() {
    return Row(
      key: const ValueKey('edit'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.white),
          onPressed: onDelete,
        ),
        IconButton(
          icon: const Icon(Icons.color_lens, color: Colors.white),
          onPressed: onChangeColor,
        ),
        IconButton(
          icon: const Icon(Icons.arrow_upward, color: Colors.white),
          onPressed: onBringToFront,
        ),
        IconButton(
          icon: const Icon(Icons.arrow_downward, color: Colors.white),
          onPressed: onSendToBack,
        ),
        if (selectedItems.length == 1 &&
            !selectedItems.first.isImage &&
            onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: onEdit,
          ),
      ],
    );
  }
}
