import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_pa_snk/core/config/api_config.dart';
import 'package:flutter_pa_snk/models/board_item.dart';
import 'package:flutter_pa_snk/models/board_dto.dart';

class BoardService {
  Future<List<BoardDto>> fetchAllBoards() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.boards),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch boards: ${response.statusCode} - ${response.body}',
        );
      }

      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => BoardDto.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error fetching boards: $e');
    }
  }

  Future<void> uploadBoard({
    required String boardId,
    required String name,
    required double height,
    required double width,
    required List<BoardItem> items,
    String? previewSrc,
  }) async {
    try {
      final assets = items.map((item) {
        return {
          'asset_name': item.id,
          'src': item.imagePath ?? '',
          'scale': item.scale,
          'rotation': item.rotation,
          'x_position': item.position.x,
          'y_position': item.position.y,
        };
      }).toList();

      final body = {
        'name': name,
        'width': width,
        'height': height,
        'assets': assets,
        if (previewSrc != null) 'previewsrc': previewSrc,
      };

      final response = await http.put(
        Uri.parse('${ApiConfig.boards}/$boardId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to upload board: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error uploading board: $e');
    }
  }
}
