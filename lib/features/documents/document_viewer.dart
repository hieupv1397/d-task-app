import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/session.dart';
import '../../shared/widgets.dart';

typedef _ViewArgs = ({int id, int? versionId, bool convert});

/// Định dạng văn phòng được máy chủ chuyển tạm sang PDF để xem.
const _officeExt = {'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp', 'rtf'};

final _fileProvider = FutureProvider.autoDispose.family<Uint8List, _ViewArgs>((ref, a) async {
  final api = ref.watch(apiProvider)!;
  final bytes = a.convert ? await api.previewDocumentPdf(a.id, versionId: a.versionId) : await api.downloadDocument(a.id, versionId: a.versionId);
  return Uint8List.fromList(bytes);
});

/// Xem tệp của văn bản ngay trong app: PDF và ảnh. Định dạng khác chưa xem được.
class DocumentViewerPage extends ConsumerWidget {
  const DocumentViewerPage({super.key, required this.id, this.versionId, required this.fileName});
  final int id;
  final int? versionId;
  final String fileName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final convert = _officeExt.contains(ext);
    final isPdf = ext == 'pdf' || convert;
    final isImage = const {'png', 'jpg', 'jpeg', 'webp', 'gif'}.contains(ext);
    final args = (id: id, versionId: versionId, convert: convert);
    return Scaffold(
      appBar: AppBar(title: Text(fileName.isEmpty ? 'Tệp văn bản' : fileName, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: !isPdf && !isImage
          ? const EmptyView(icon: Icons.insert_drive_file_outlined, text: 'Định dạng này chưa xem được trong app.\nVui lòng mở bằng web để xem hoặc tải về.')
          : AsyncView<Uint8List>(
              value: ref.watch(_fileProvider(args)),
              onRetry: () => ref.invalidate(_fileProvider(args)),
              builder: (bytes) => bytes.isEmpty
                  ? const EmptyView(icon: Icons.insert_drive_file_outlined, text: 'Tệp trống hoặc không đọc được.')
                  : isPdf
                      ? _PdfPages(bytes: bytes, name: '$id-${versionId ?? 0}-${bytes.length}')
                      : InteractiveViewer(minScale: 0.8, maxScale: 6, child: Center(child: Image.memory(bytes))),
            ),
    );
  }
}

/// Hiển thị PDF cuộn dọc, chụm hai ngón để phóng to. Dùng bộ vẽ PDFium của pdfrx để thấy cả lớp chú thích:
/// chữ ký số nằm ở chú thích kiểu Widget/Sig, bộ vẽ sẵn có của Android (pdfx) bỏ qua lớp này nên chữ ký và ảnh bị mất.
class _PdfPages extends StatelessWidget {
  const _PdfPages({required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;

  @override
  Widget build(BuildContext context) {
    return PdfViewer.data(
      bytes,
      sourceName: name,
      params: PdfViewerParams(
        backgroundColor: const Color(0xFFE9EEF0),
        annotationRenderingMode: PdfAnnotationRenderingMode.annotationAndForms,
        errorBannerBuilder: (context, error, stackTrace, documentRef) => const EmptyView(icon: Icons.insert_drive_file_outlined, text: 'Không đọc được tệp PDF này.'),
      ),
    );
  }
}
