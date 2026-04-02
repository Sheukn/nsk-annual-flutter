import 'package:flutter/material.dart';
import 'package:flutter_pa_snk/models/board_item.dart';

class BoardActionMenu extends StatelessWidget {
  final List<BoardItem> selectedItems;
  final VoidCallback onAddImage;
  final VoidCallback onAddPostIt;
  final VoidCallback onDelete;
  final VoidCallback onBringToFront;
  final VoidCallback onSendToBack;
  final VoidCallback? onEdit;

  const BoardActionMenu({
    super.key,
    required this.selectedItems,
    required this.onAddImage,
    required this.onAddPostIt,
    required this.onDelete,
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
          selectedItems.length == 1 && onEdit != null
              ? 320
              : selectedItems.isNotEmpty
              ? 240
              : 140,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade600,
            Colors.blue.shade400,
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            color: Colors.blue.withAlpha(100),
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            blurRadius: 8,
            color: Colors.black.withAlpha(50),
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.white10,
          width: 1,
        ),
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
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
            onPressed: onAddImage,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.sticky_note_2, color: Colors.white),
            onPressed: onAddPostIt,
          ),
        ),
      ],
    );
  }

  Widget _buildEditActions() {
    return Row(
      key: const ValueKey('edit'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.redAccent.withAlpha(150),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: onDelete,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_upward, color: Colors.white),
            onPressed: onBringToFront,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_downward, color: Colors.white),
            onPressed: onSendToBack,
          ),
        ),
        if (selectedItems.length == 1 && onEdit != null)
          Container(
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(150),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                selectedItems.first.isImage ? Icons.add_photo_alternate : Icons.edit,
                color: Colors.white,
              ),
              onPressed: onEdit,
            ),
          ),
      ],
    );
  }
}
