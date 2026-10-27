import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../widgets/avatar.dart';
import 'camera/selfie.dart';

/// Profil du joueur, gardé sur son téléphone pour la prochaine soirée.
class Profile {
  Profile({this.name = '', String? emoji, int? color, this.photo})
      : emoji = emoji ?? Pb.emojis[DateTime.now().millisecond % Pb.emojis.length],
        color = color ?? DateTime.now().microsecond % Pb.playerColors.length;

  String name;
  String emoji;
  int color;
  Uint8List? photo; // JPEG 192×192 déjà prêt à envoyer

  static Future<Profile> load(SharedPreferences p) async {
    final b64 = p.getString('p_photo');
    return Profile(
      name: p.getString('p_name') ?? '',
      emoji: p.getString('p_emoji'),
      color: p.getInt('p_color'),
      photo: b64 == null ? null : base64Decode(b64),
    );
  }

  Future<void> save(SharedPreferences p) async {
    await p.setString('p_name', name);
    await p.setString('p_emoji', emoji);
    await p.setInt('p_color', color);
    if (photo == null) {
      await p.remove('p_photo');
    } else {
      await p.setString('p_photo', base64Encode(photo!));
    }
  }

  Map<String, dynamic> toMessage() => {
        'name': name.trim(),
        'emoji': emoji,
        'color': color,
        'photo': photo == null ? '' : base64Encode(photo!),
      };

  Profile copy() => Profile(name: name, emoji: emoji, color: color, photo: photo);
}

/// Selfie : caméra dans la page si possible, sinon l'appli photo du téléphone.
Future<Uint8List?> takeProfileSelfie(BuildContext context) async {
  try {
    final bytes = await takeSelfie(context);
    return bytes == null ? null : squarePhoto(bytes);
  } on SelfieUnavailable {
    return pickProfilePhoto(ImageSource.camera);
  }
}

/// Prend une photo (ou la choisit), la recadre en carré et la réduit à 192 px.
Future<Uint8List?> pickProfilePhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 480,
    maxHeight: 480,
    imageQuality: 90,
    preferredCameraDevice: CameraDevice.front,
  );
  if (file == null) return null;
  return squarePhoto(await file.readAsBytes());
}

/// Recadre en carré centré et réduit à 192 px (JPEG ~10 Ko)
Uint8List squarePhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Image illisible');
  final square = img.copyResizeCropSquare(img.bakeOrientation(decoded), size: 192);
  return Uint8List.fromList(img.encodeJpg(square, quality: 80));
}

/// Formulaire pseudo + photo (ou emoji) + couleur.
class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key, required this.profile, required this.onChanged});
  final Profile profile;
  final VoidCallback onChanged;

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final _name = TextEditingController(text: widget.profile.name);
  bool _busy = false;

  Profile get p => widget.profile;

  Future<void> _pick(ImageSource src) async {
    setState(() => _busy = true);
    try {
      final bytes = src == ImageSource.camera ? await takeProfileSelfie(context) : await pickProfilePhoto(src);
      if (bytes != null) p.photo = bytes;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de lire cette photo')));
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onChanged();
  }

  void _set(VoidCallback f) {
    setState(f);
    widget.onChanged();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(
        child: Stack(alignment: Alignment.center, children: [
          PbAvatar(size: 150, emoji: p.emoji, color: p.color, photoBytes: p.photo),
          if (_busy) const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(color: Colors.white)),
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _pick(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_rounded),
            label: const Text('Selfie'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Galerie'),
          ),
        ),
      ]),
      if (p.photo != null)
        TextButton(
          onPressed: () => _set(() => p.photo = null),
          child: Text('Enlever la photo (mettre un emoji)', style: Pb.t(15, color: Pb.muted)),
        ),
      const SizedBox(height: 18),
      Text('Ton pseudo', style: Pb.t(16, weight: 600, color: Pb.muted)),
      const SizedBox(height: 8),
      TextField(
        controller: _name,
        maxLength: 16,
        textCapitalization: TextCapitalization.sentences,
        style: Pb.t(22, weight: 600),
        decoration: const InputDecoration(hintText: 'Ex : Foc', counterText: ''),
        onChanged: (v) {
          p.name = v;
          widget.onChanged();
        },
      ),
      const SizedBox(height: 18),
      Text('Ta couleur', style: Pb.t(16, weight: 600, color: Pb.muted)),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < Pb.playerColors.length; i++)
          GestureDetector(
            onTap: () => _set(() => p.color = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Pb.playerColor(i),
                shape: BoxShape.circle,
                border: Border.all(color: p.color == i ? Colors.white : Colors.transparent, width: 3),
              ),
            ),
          ),
      ]),
      if (p.photo == null) ...[
        const SizedBox(height: 18),
        Text('Ton emoji', style: Pb.t(16, weight: 600, color: Pb.muted)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in Pb.emojis)
            GestureDetector(
              onTap: () => _set(() => p.emoji = e),
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.emoji == e ? Pb.cardHi : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.emoji == e ? Pb.pink : Colors.transparent, width: 2),
                ),
                child: Text(e, style: const TextStyle(fontSize: 26)),
              ),
            ),
        ]),
      ],
    ]);
  }
}
