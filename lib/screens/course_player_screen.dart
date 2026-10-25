import '../widgets/kaida_loader.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';
import '../services/course_player_service.dart';
import '../widgets/kaida_empty_state.dart';

class CoursePlayerScreen extends StatefulWidget {
  final int courseId;
  final String courseTitle;

  const CoursePlayerScreen({Key? key, required this.courseId, required this.courseTitle}) : super(key: key);

  @override
  _CoursePlayerScreenState createState() => _CoursePlayerScreenState();
}

class _CoursePlayerScreenState extends State<CoursePlayerScreen> {
  final CoursePlayerService _service = CoursePlayerService();
  bool _isLoading = true;
  
  List<dynamic> _sections = [];
  Map<String, dynamic>? _currentLesson;
  
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  Timer? _progressTimer;

  final Set<String> _completed = {};
  Map<String, String> _downloadedLessons = {};
  Map<String, double> _downloadProgress = {};
  final Map<String, CancelToken> _cancelTokens = {};

  List<dynamic> get _allLessons {
    List<dynamic> list = [];
    for (var s in _sections) {
      list.addAll(s['lessons'] ?? s['items'] ?? []);
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadCourseData();
  }

  void _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    final String? downloadsJson = prefs.getString('offline_downloads');
    if (downloadsJson != null) {
      if (mounted) {
        setState(() {
          Map<String, dynamic> decoded = json.decode(downloadsJson);
          _downloadedLessons = decoded.map((key, value) => MapEntry(key, value.toString()));
        });
      }
    }
  }

  void _loadCourseData() async {
    final data = await _service.getCourseDetails(widget.courseId);
    if (data != null) {
      List<dynamic> parsedSections = [];
      if (data is List) parsedSections = data;
      else if (data is Map && data.containsKey('sections')) parsedSections = data['sections'];
      else if (data is Map && data.containsKey('curriculum')) parsedSections = data['curriculum'];
      else if (data is Map && data.containsKey('data')) parsedSections = data['data'];

      if (mounted) {
        setState(() {
          _sections = parsedSections;
          _isLoading = false;
        });
        for (final l in _allLessons) {
          if ('${l['is_completed']}' == '1') _completed.add(l['id'].toString());
        }
        if (_allLessons.isNotEmpty) _playLesson(_allLessons.first);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isYoutubeOrVimeo(String url) {
    String lowerUrl = url.toLowerCase();
    return lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be') || lowerUrl.contains('vimeo.com');
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_currentLesson != null && _videoController != null && _videoController!.value.isPlaying) {
        _service.saveVideoProgress(
          int.parse(_currentLesson!['id'].toString()), 
          _videoController!.value.position.inSeconds.toDouble()
        );
      }
    });
  }

  Future<void> _downloadLesson(dynamic lesson) async {
    String id = lesson['id'].toString();
    String url = lesson['content']?.toString() ?? lesson['video_url']?.toString() ?? '';
    String type = lesson['content_type']?.toString() ?? lesson['lesson_type']?.toString() ?? 'video';
    
    if (type != 'video' || url.isEmpty || _isYoutubeOrVimeo(url)) return;
    if (_downloadedLessons.containsKey(id) || _downloadProgress.containsKey(id)) return;

    setState(() => _downloadProgress[id] = 0.01);
    CancelToken cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;

    try {
      if (!url.startsWith('http')) url = 'https://academy.kainuwa.africa/' + url;

      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/lesson_$id.mp4';

      final dio = Dio();
      await dio.download(
        url, savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() => _downloadProgress[id] = received / total);
          }
        },
      );

      final prefs = await SharedPreferences.getInstance();
      _downloadedLessons[id] = savePath;
      await prefs.setString('offline_downloads', json.encode(_downloadedLessons));

      if (mounted) {
        setState(() {
          _downloadProgress.remove(id);
          _cancelTokens.remove(id);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lesson['title']} downloaded!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        debugPrint("Download cancelled by user.");
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download failed.'), backgroundColor: Colors.red));
      }
      
      if (mounted) {
        setState(() {
          _downloadProgress.remove(id);
          _cancelTokens.remove(id);
        });
      }
    }
  }

  void _cancelDownload(String id) {
    if (_cancelTokens.containsKey(id)) {
      _cancelTokens[id]?.cancel();
      _cancelTokens.remove(id);
      setState(() => _downloadProgress.remove(id));
    }
  }

  void _downloadSection(dynamic section) {
    List items = section['lessons'] ?? section['items'] ?? [];
    for (var lesson in items) {
      _downloadLesson(lesson);
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Section added to download queue!'), backgroundColor: AppTheme.primaryColor));
  }

  void _downloadEntireCourse() {
    for (var sec in _sections) {
      _downloadSection(sec);
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entire course added to download queue!'), backgroundColor: AppTheme.primaryColor));
  }

  void _playLesson(dynamic lesson) async {
    if (_currentLesson != null && _videoController != null) {
      _service.saveVideoProgress(int.parse(_currentLesson!['id'].toString()), _videoController!.value.position.inSeconds.toDouble());
    }

    _progressTimer?.cancel();
    String id = lesson['id'].toString();
    String url = lesson['content']?.toString() ?? lesson['video_url']?.toString() ?? '';
    String type = lesson['content_type']?.toString() ?? lesson['lesson_type']?.toString() ?? 'video';

    setState(() {
      _currentLesson = Map<String, dynamic>.from(lesson);
      if (_chewieController != null) {
        _chewieController!.dispose();
        _chewieController = null;
      }
      if (_videoController != null) {
        _videoController!.dispose();
        _videoController = null;
      }
    });

    if (type == 'video' && url.isNotEmpty) {
      if (!_isYoutubeOrVimeo(url)) {
        if (_downloadedLessons.containsKey(id)) {
          File localFile = File(_downloadedLessons[id]!);
          if (await localFile.exists()) {
             _videoController = VideoPlayerController.file(localFile);
          } else {
             _downloadedLessons.remove(id);
             if (!url.startsWith('http')) url = 'https://academy.kainuwa.africa/' + url;
             _videoController = VideoPlayerController.network(url);
          }
        } else {
          if (!url.startsWith('http')) url = 'https://academy.kainuwa.africa/' + url;
          _videoController = VideoPlayerController.network(url);
        }

        await _videoController!.initialize();

        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: false,
          materialProgressColors: ChewieProgressColors(
            playedColor: AppTheme.primaryColor,
            handleColor: AppTheme.primaryColor,
            backgroundColor: Colors.grey.shade800,
            bufferedColor: Colors.grey.shade400,
          ),
        );

        _startProgressTimer();

        _videoController!.addListener(() {
          if (_videoController!.value.isInitialized && 
              !_videoController!.value.isPlaying &&
              _videoController!.value.position >= _videoController!.value.duration && 
              _videoController!.value.position > Duration.zero) {
            _markDone();
            _playNextLesson();
          }
        });

        if (mounted) setState(() {});
      }
    }
  }

  void _markDone() {
    if (_currentLesson == null) return;
    final id = _currentLesson!['id'].toString();
    if (_completed.add(id) && mounted) setState(() {});
  }

  void _playNextLesson() {
    if (_currentLesson == null) return;
    final currentIndex = _allLessons.indexWhere((l) => l['id'].toString() == _currentLesson!['id'].toString());
    if (currentIndex >= 0 && currentIndex < _allLessons.length - 1) {
      if (_chewieController != null && _chewieController!.isFullScreen) {
        _chewieController!.exitFullScreen();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _playLesson(_allLessons[currentIndex + 1]);
        });
      } else {
        _playLesson(_allLessons[currentIndex + 1]);
      }
    }
  }

  void _playPrevLesson() {
    if (_currentLesson == null) return;
    final currentIndex = _allLessons.indexWhere((l) => l['id'].toString() == _currentLesson!['id'].toString());
    if (currentIndex > 0) {
      if (_chewieController != null && _chewieController!.isFullScreen) {
        _chewieController!.exitFullScreen();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _playLesson(_allLessons[currentIndex - 1]);
        });
      } else {
        _playLesson(_allLessons[currentIndex - 1]);
      }
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _cancelTokens.forEach((key, token) => token.cancel());
    if (_currentLesson != null && _videoController != null) {
      _service.saveVideoProgress(int.parse(_currentLesson!['id'].toString()), _videoController!.value.position.inSeconds.toDouble());
    }
    _chewieController?.dispose();
    _videoController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Widget _buildDownloadStateWidget(dynamic lesson, bool isDark) {
    String id = lesson['id'].toString();
    String url = lesson['content']?.toString() ?? lesson['video_url']?.toString() ?? '';
    String type = lesson['content_type']?.toString() ?? lesson['lesson_type']?.toString() ?? 'video';

    if (type != 'video' || url.isEmpty || _isYoutubeOrVimeo(url)) return const SizedBox();
    
    if (_downloadedLessons.containsKey(id)) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 24);
    }
    
    if (_downloadProgress.containsKey(id)) {
      return GestureDetector(
        onTap: () => _cancelDownload(id),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(value: _downloadProgress[id], strokeWidth: 3, color: AppTheme.primaryColor),
            ),
            const Icon(Icons.close, size: 14, color: AppTheme.primaryColor),
          ],
        ),
      );
    }
    
    return IconButton(
      icon: Icon(Icons.cloud_download_outlined, color: isDark ? Colors.grey.shade400 : Colors.grey),
      onPressed: () => _downloadLesson(lesson),
      tooltip: 'Download Lesson',
    );
  }

  // ---------------- new look ----------------
  String _clean(String t) => t
      .replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#039;', "'").replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<').replaceAll('&gt;', '>');

  String _sectionOf(dynamic lesson) {
    for (final sec in _sections) {
      final items = sec['lessons'] ?? sec['items'] ?? [];
      for (final l in items) {
        if (l['id'].toString() == lesson['id'].toString()) return _clean('${sec['title'] ?? ''}');
      }
    }
    return '';
  }

  Widget _header(bool isDark) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 12),
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF3A22C4), Color(0xFF6B47F5)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle), child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 19)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_clean(widget.courseTitle), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w900)),
                Text('${_completed.length}/${_allLessons.length} lessons completed', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _downloadEntireCourse,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(20)),
              child: const Row(children: [
                Icon(Icons.download_for_offline_rounded, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text('Save all', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerBox(bool wide) {
    final player = _currentLesson == null
        ? const Center(child: Text('Select a lesson', style: TextStyle(color: Colors.white)))
        : _buildPlayerArea();
    return Container(color: Colors.black, child: wide ? AspectRatio(aspectRatio: 16 / 9, child: player) : AspectRatio(aspectRatio: 16 / 9, child: player));
  }

  Widget _lessonInfo(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF16123A);
    final cur = _currentLesson;
    final done = cur != null && _completed.contains(cur['id'].toString());
    final idx = cur == null ? -1 : _allLessons.indexWhere((l) => l['id'].toString() == cur['id'].toString());

    Widget navBtn(IconData icon, String label, VoidCallback? onTap, {bool right = false}) => Expanded(
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (!right) Icon(icon, size: 20, color: AppTheme.primaryColor),
              if (!right) const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
              if (right) const SizedBox(width: 4),
              if (right) Icon(icon, size: 20, color: AppTheme.primaryColor),
            ]),
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_clean('${cur?['title'] ?? widget.courseTitle}'), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, height: 1.25, color: textColor)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (cur != null && _sectionOf(cur).isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.folder_open_rounded, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Flexible(child: Text(_sectionOf(cur), style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600))),
                ]),
              if (done)
                const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_rounded, size: 17, color: Color(0xFF22A06B)),
                  SizedBox(width: 4),
                  Text('Completed', style: TextStyle(fontSize: 12.5, color: Color(0xFF22A06B), fontWeight: FontWeight.w800)),
                ]),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            navBtn(Icons.skip_previous_rounded, 'Prev', idx > 0 ? _playPrevLesson : null),
            const SizedBox(width: 10),
            navBtn(Icons.skip_next_rounded, 'Next', (idx >= 0 && idx < _allLessons.length - 1) ? _playNextLesson : null, right: true),
          ]),
          if (cur != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _downloadLesson(cur),
                style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade400), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                icon: Icon(Icons.download_rounded, size: 19, color: isDark ? Colors.white70 : Colors.black87),
                label: Text('Download this lesson', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _curriculum(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF16123A);
    final surfaceColor = isDark ? AppTheme.darkSurfaceColor : Colors.white;
    if (_sections.isEmpty) {
      return const SizedBox(height: 320, child: KaidaEmptyState(kind: KaidaEmptyKind.courses, title: 'No lessons yet', message: 'Lessons will appear here once the instructor adds them.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Text('Lessons', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
        ),
        ...List.generate(_sections.length, (index) {
          final section = _sections[index];
          final List items = section['lessons'] ?? section['items'] ?? [];
          final doneCount = items.where((l) => _completed.contains(l['id'].toString())).length;
          return Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 3))]),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: index == 0,
                tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                iconColor: AppTheme.primaryColor,
                title: Text(_clean('${section['title'] ?? 'Section'}'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: textColor)),
                subtitle: Text('$doneCount/${items.length} lessons', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: () => _downloadSection(section),
                    child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.download_rounded, color: AppTheme.primaryColor, size: 21)),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                ]),
                children: items.map<Widget>((lesson) {
                  final isPlaying = _currentLesson?['id'].toString() == lesson['id'].toString();
                  final type = lesson['content_type']?.toString() ?? lesson['lesson_type']?.toString() ?? 'video';
                  final url = lesson['content']?.toString() ?? lesson['video_url']?.toString() ?? '';
                  final hasAccess = url.isNotEmpty;
                  final isDone = _completed.contains(lesson['id'].toString());

                  Widget lead;
                  if (isPlaying) {
                    lead = const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryColor, size: 28);
                  } else if (isDone) {
                    lead = const Icon(Icons.check_circle_rounded, color: Color(0xFF22A06B), size: 26);
                  } else if (!hasAccess) {
                    lead = Icon(Icons.lock_rounded, color: Colors.grey.shade500, size: 24);
                  } else {
                    lead = Icon(type == 'video' ? Icons.play_circle_outline_rounded : Icons.description_outlined, color: Colors.grey.shade600, size: 26);
                  }

                  return InkWell(
                    onTap: hasAccess
                        ? () => _playLesson(lesson)
                        : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enroll to view this lesson.'), backgroundColor: Colors.orange)),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(color: isPlaying ? AppTheme.primaryColor.withOpacity(isDark ? 0.2 : 0.09) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          lead,
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('${index + 1}.${items.indexOf(lesson) + 1}  ${_clean('${lesson['title'] ?? 'Lesson'}')}',
                                style: TextStyle(fontSize: 13.5, fontWeight: isPlaying ? FontWeight.w800 : FontWeight.w600, color: isPlaying ? AppTheme.primaryColor : textColor)),
                          ),
                          if (hasAccess) _buildDownloadStateWidget(lesson, isDark),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackgroundColor : const Color(0xFFF6F5FB);
    final wide = MediaQuery.of(context).size.width >= 720; // tablet / landscape: lessons on the right

    if (_isLoading) return Scaffold(backgroundColor: bg, body: const Center(child: KaidaLoader()));

    if (wide) {
      return Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            _header(isDark),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: SingleChildScrollView(child: Column(children: [_playerBox(true), _lessonInfo(isDark)]))),
                  Expanded(flex: 4, child: SingleChildScrollView(child: _curriculum(isDark))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _header(isDark),
          _playerBox(false),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lessonInfo(isDark),
                  _curriculum(isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerArea() {
    String type = _currentLesson!['content_type']?.toString() ?? _currentLesson!['lesson_type']?.toString() ?? 'video';
    String url = _currentLesson!['content']?.toString() ?? _currentLesson!['video_url']?.toString() ?? '';
    
    if (type == 'video') {
      if (_isYoutubeOrVimeo(url)) {
        return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('YouTube/Vimeo playback requires advanced plugins (Phase 2).', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center)));
      }
      if (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized) {
        return Chewie(controller: _chewieController!);
      }
      if (_videoController != null && _videoController!.value.hasError) {
         return const Center(child: Text('Error loading video. Please check your connection.', style: TextStyle(color: Colors.red)));
      }
      return Center(child: KaidaLoader());
    } else {
      return const Center(child: Icon(Icons.article, size: 60, color: Colors.white54));
    }
  }
}