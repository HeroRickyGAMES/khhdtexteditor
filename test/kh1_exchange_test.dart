// Testes de integração para kh1_exchange.dart
// Usa arquivos reais do jogo para validar decode/encode/load/save EVDL e EvMsg.
// Rodar: flutter test test/kh1_exchange_test.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kh1texteditor/kh1_exchange.dart';

const String kModsRoot = '/home/heroricky/NAS/share/steam_d/kh1_mods';
const String kFirst    = '$kModsRoot/kh1_first.hed_out';
const String kThird    = '$kModsRoot/kh1_third.hed_out';

void main() {

  // -----------------------------------------------------------------------
  // KH1Encoding: decode/encode básico
  // Tabela: maiúsculas byte+0x16→char, minúsculas byte+0x1C→char
  // -----------------------------------------------------------------------
  group('KH1Encoding', () {
    test('decode: maiúsculas e minúsculas corretas', () {
      // "The Sora "
      // T(0x54)→0x3E, h(0x68)→0x4C, e(0x65)→0x49, sp=0x01
      // S(0x53)→0x3D, o(0x6F)→0x53, r(0x72)→0x56, a(0x61)→0x45, sp=0x01
      final bytes = Uint8List.fromList([0x3E, 0x4C, 0x49, 0x01, 0x3D, 0x53, 0x56, 0x45, 0x01]);
      expect(KH1Encoding.decode(bytes), 'The Sora ');
    });

    test('decode: apóstrofe BTN 0x71 → apostrophe', () {
      // "can't" = c(0x47) a(0x45) n(0x52) '(0x71) t(0x58)
      final bytes = Uint8List.fromList([0x47, 0x45, 0x52, 0x71, 0x58]);
      expect(KH1Encoding.decode(bytes), "can't");
    });

    test('encode: apostrophe → BTN 0x71', () {
      final encoded = KH1Encoding.encode("can't");
      expect(encoded, Uint8List.fromList([0x47, 0x45, 0x52, 0x71, 0x58]));
    });

    test('round-trip: "You didn\'t see Riku?"', () {
      const text = "You didn't see Riku?";
      expect(KH1Encoding.decode(KH1Encoding.encode(text)), text);
    });

    test('round-trip: "to unlock people\'s hearts."', () {
      const text = "to unlock people's hearts.";
      expect(KH1Encoding.decode(KH1Encoding.encode(text)), text);
    });

    test('round-trip: "It\'s not that simple."', () {
      const text = "It's not that simple.";
      expect(KH1Encoding.decode(KH1Encoding.encode(text)), text);
    });

    test('decode: pontuação básica !?.,-:', () {
      // "Hi. Done!" = H(0x32) i(0x4D) .(0x68) sp S(0x3D) o(0x53) r(0x53) a(0x45) !(0x5F)
      // Only round-trip for simplicity
      const text = 'Hi. Done!';
      expect(KH1Encoding.decode(KH1Encoding.encode(text)), text);
    });
  });

  // -----------------------------------------------------------------------
  // EVDL: Station of Awakening (dh02_ard3.evdl) — terminador 0x06
  // -----------------------------------------------------------------------
  group('EVDL dh02_ard3 (Station of Awakening)', () {
    late ExchangeFile ef;
    const path = '$kFirst/remastered/dh02.ard/UK_dh02_ard3.evdl';

    setUpAll(() {
      ef = ExchangeFile(
        ukDataPath: path,
        spDataPath: path.replaceFirst('/UK_', '/SP_'),
        hasPair: false,
        isEvdl: true,
      );
      ef.load();
    });

    test('carrega sem crash', () {
      expect(ef.strings, isNotEmpty);
    });

    test('encontra "The power of the warrior."', () {
      expect(ef.strings.any((s) => s.contains('power of the warrior')), isTrue);
    });

    test('encontra "Invincible courage."', () {
      expect(ef.strings.any((s) => s.contains('Invincible courage')), isTrue);
    });

    test('nenhuma string começa com [BTN:', () {
      final bad = ef.strings.where((s) => s.startsWith('[BTN:')).toList();
      expect(bad, isEmpty, reason: 'Strings com lixo BTN no início: $bad');
    });
  });

  // -----------------------------------------------------------------------
  // EVDL: Hollow Bastion cena Riku/Malévola (pc06_ard2.evdl) — term. 0x02/0x00
  // -----------------------------------------------------------------------
  group('EVDL pc06_ard2 (Hollow Bastion — cena Riku/Malévola)', () {
    late ExchangeFile ef;
    const path = '$kThird/remastered/pc06.ard/UK_pc06_ard2.evdl';

    setUpAll(() {
      ef = ExchangeFile(
        ukDataPath: path,
        spDataPath: path.replaceFirst('/UK_', '/SP_'),
        hasPair: false,
        isEvdl: true,
      );
      ef.load();
    });

    test('carrega sem crash', () {
      expect(ef.strings, isNotEmpty);
    });

    test('encontra "this Keyblade holds the power"', () {
      expect(ef.strings.any((s) => s.contains('this Keyblade holds the power')), isTrue);
    });

    test('encontra "to unlock people\'s hearts."', () {
      expect(ef.strings.any((s) => s.contains("to unlock people's hearts")), isTrue);
    });

    test('apostrofe "didn\'t" não está como [BTN:71]', () {
      final bad = ef.strings.where((s) => s.contains('[BTN:71]')).toList();
      expect(bad, isEmpty, reason: 'Ainda tem [BTN:71] nas strings: $bad');
    });

    test('nenhuma string começa com [BTN: ou [ACC:', () {
      final bad = ef.strings
          .where((s) => s.startsWith('[BTN:') || s.startsWith('[ACC:'))
          .toList();
      expect(bad, isEmpty, reason: 'Falsos positivos: $bad');
    });
  });

  // -----------------------------------------------------------------------
  // EVDL: Hollow Bastion diálogo ambiente (pc06_ard0.evdl)
  // -----------------------------------------------------------------------
  group('EVDL pc06_ard0 (Hollow Bastion — diálogo ambiente)', () {
    late ExchangeFile ef;
    const path = '$kThird/remastered/pc06.ard/UK_pc06_ard0.evdl';

    setUpAll(() {
      ef = ExchangeFile(
        ukDataPath: path,
        spDataPath: path.replaceFirst('/UK_', '/SP_'),
        hasPair: false,
        isEvdl: true,
      );
      ef.load();
    });

    test('carrega sem crash', () {
      expect(ef.strings, isNotEmpty);
    });

    test('encontra "It was reckless to bring her here"', () {
      expect(ef.strings.any((s) => s.contains('It was reckless to bring her here')), isTrue);
    });

    test('encontra "the dark powers could cost you"', () {
      expect(ef.strings.any((s) => s.contains('the dark powers could cost you')), isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // EVDL: 100 Acre Wood / Neverland folder (pi37_ard0.evdl)
  // -----------------------------------------------------------------------
  group('EVDL pi37_ard0 (100 Acre Wood / Neverland)', () {
    late ExchangeFile ef;
    const path = '$kThird/remastered/pi37.ard/UK_pi37_ard0.evdl';

    setUpAll(() {
      ef = ExchangeFile(
        ukDataPath: path,
        spDataPath: path.replaceFirst('/UK_', '/SP_'),
        hasPair: false,
        isEvdl: true,
      );
      ef.load();
    });

    test('carrega sem crash', () {
      expect(ef.strings, isNotEmpty);
    });

    test('encontra "Will you help me get some honey"', () {
      expect(ef.strings.any((s) => s.contains('Will you help me get some honey')), isTrue);
    });

    test('encontra "Pooh\'s Hunny Hunt" (apóstrofe)', () {
      // Valida que apóstrofe em "Pooh's" está correto, não [BTN:71]
      final hunny = ef.strings.where((s) => s.contains('Hunny Hunt')).toList();
      expect(hunny, isNotEmpty, reason: 'Pooh Hunny Hunt não encontrado');
      final bad = hunny.where((s) => s.contains('[BTN:71]')).toList();
      expect(bad, isEmpty, reason: 'Apóstrofe ainda como [BTN:71]: $bad');
    });
  });

  // -----------------------------------------------------------------------
  // EVDL: End of World (ew01_ardc.evdl) — terminador 0x06
  // -----------------------------------------------------------------------
  group('EVDL ew01_ardc (End of World)', () {
    late ExchangeFile ef;
    const path = '$kThird/remastered/ew01.ard/UK_ew01_ardc.evdl';

    setUpAll(() {
      ef = ExchangeFile(
        ukDataPath: path,
        spDataPath: path.replaceFirst('/UK_', '/SP_'),
        hasPair: false,
        isEvdl: true,
      );
      ef.load();
    });

    test('carrega sem crash', () {
      expect(ef.strings, isNotEmpty);
    });

    test('encontra "Portal of Darkness"', () {
      expect(ef.strings.any((s) => s.contains('Portal of Darkness')), isTrue);
    });

    test('encontra "Burned out." (terminador 0x06)', () {
      expect(ef.strings.any((s) => s.contains('Burned out')), isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // EVDL: round-trip save/load — verifica que patch in-place não corrompe
  // -----------------------------------------------------------------------
  group('EVDL save/load round-trip', () {
    const path = '$kThird/remastered/pc06.ard/UK_pc06_ard2.evdl';

    test('save não altera tamanho do arquivo', () {
      final ef = ExchangeFile(
        ukDataPath: path,
        spDataPath: path.replaceFirst('/UK_', '/SP_'),
        hasPair: false,
        isEvdl: true,
      );
      ef.load();
      final originalSize = File(path).lengthSync();

      final tmpDir = Directory.systemTemp.createTempSync('kh1test');
      if (ef.strings.isNotEmpty) {
        ef.editString(0, 'Teste.');
      }
      ef.save(tmpDir.path);

      final relPath = 'kh1_third/remastered/pc06.ard';
      final fn = path.split('/').last;
      final savedFile = File('${tmpDir.path}/$relPath/$fn');
      expect(savedFile.existsSync(), isTrue, reason: 'Arquivo salvo não encontrado');
      expect(savedFile.lengthSync(), originalSize, reason: 'Tamanho diferente do original!');
      tmpDir.deleteSync(recursive: true);
    });

    test('terminadores 0x06/0x02/0x00 preservados após save', () {
      final ef = ExchangeFile(
        ukDataPath: path,
        spDataPath: path.replaceFirst('/UK_', '/SP_'),
        hasPair: false,
        isEvdl: true,
      );
      ef.load();
      final original = File(path).readAsBytesSync();

      final tmpDir = Directory.systemTemp.createTempSync('kh1test2');
      ef.save(tmpDir.path);

      final relPath = 'kh1_third/remastered/pc06.ard';
      final fn = path.split('/').last;
      final saved = File('${tmpDir.path}/$relPath/$fn').readAsBytesSync();

      for (final off in ef.rawOffsetsForTest) {
        final origLen = _origLen(original, off);
        final termByte = original[off + origLen];
        expect(saved[off + origLen], termByte,
            reason: 'Terminador em 0x${(off+origLen).toRadixString(16)} mudou!');
      }
      tmpDir.deleteSync(recursive: true);
    });

    test('texto padded com 0x00 após string mais curta', () {
      final ef = ExchangeFile(
        ukDataPath: path,
        spDataPath: path.replaceFirst('/UK_', '/SP_'),
        hasPair: false,
        isEvdl: true,
      );
      ef.load();
      if (ef.strings.isEmpty) return;

      final original = File(path).readAsBytesSync();
      final off = ef.rawOffsetsForTest.first;
      final origLen = _origLen(original, off);
      ef.editString(0, 'AB'); // 2 bytes — muito menor que o slot original

      final tmpDir = Directory.systemTemp.createTempSync('kh1test3');
      ef.save(tmpDir.path);

      final relPath = 'kh1_third/remastered/pc06.ard';
      final fn = path.split('/').last;
      final saved = File('${tmpDir.path}/$relPath/$fn').readAsBytesSync();

      // Após "AB" (2 bytes), posições 2..origLen-1 devem ser 0x00 (padding)
      for (int j = 2; j < origLen; j++) {
        expect(saved[off + j], 0x00,
            reason: 'Byte ${j} deveria ser padding 0x00 mas é 0x${saved[off+j].toRadixString(16)}');
      }
      tmpDir.deleteSync(recursive: true);
    });
  });

  // -----------------------------------------------------------------------
  // EvMsg BINL: diálogo de Hollow Bastion (pc06_ard3ea.binl)
  // -----------------------------------------------------------------------
  group('EvMsg pc06_ard3ea.binl (NPCs Hollow Bastion)', () {
    late ExchangeFile ef;
    const path = '$kThird/remastered/pc06.ard/UK_pc06_ard3ea.binl';

    setUpAll(() {
      if (!File(path).existsSync()) return;
      ef = ExchangeFile(
        ukDataPath: path,
        spDataPath: path.replaceFirst('/UK_', '/SP_'),
        hasPair: false,
        isEvMsg: true,
      );
      ef.load();
    });

    test('carrega sem crash', () {
      if (!File(path).existsSync()) return;
      expect(ef.strings, isNotEmpty);
    });

    test('encontra "I know this place"', () {
      if (!File(path).existsSync()) return;
      expect(ef.strings.any((s) => s.contains('I know this place')), isTrue);
    });

    test('encontra "I can\'t leave them behind" (apóstrofe em EvMsg)', () {
      if (!File(path).existsSync()) return;
      // Valida decode de 0x71→' dentro do formato EvMsg (breakOnEnd=false)
      expect(ef.strings.any((s) => s.contains("I can't leave them behind")), isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // EvMsg BINL: cutscene Destiny Islands (di08_ard3e8.binl)
  // -----------------------------------------------------------------------
  group('EvMsg di08_ard3e8.binl (Destiny Islands)', () {
    late ExchangeFile ef;
    const path = '$kFirst/remastered/di08.ard/UK_di08_ard3e8.binl';

    setUpAll(() {
      if (!File(path).existsSync()) return;
      ef = ExchangeFile(
        ukDataPath: path,
        spDataPath: path.replaceFirst('/UK_', '/SP_'),
        hasPair: false,
        isEvMsg: true,
      );
      ef.load();
    });

    test('carrega sem crash', () {
      if (!File(path).existsSync()) return;
      expect(ef.strings, isNotEmpty);
    });

    test('encontra "So, can you gather"', () {
      if (!File(path).existsSync()) return;
      expect(ef.strings.any((s) => s.contains('So, can you gather')), isTrue);
    });

    test('encontra "Yeah, I heard you"', () {
      if (!File(path).existsSync()) return;
      expect(ef.strings.any((s) => s.contains('Yeah, I heard you')), isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // EvMsg BINL: 100 Acre Wood diálogo (pi37_ard3e8.binl) — apóstrofe em EvMsg
  // -----------------------------------------------------------------------
  group('EvMsg pi37_ard3e8.binl (100 Acre Wood — apóstrofe)', () {
    late ExchangeFile ef;
    const path = '$kThird/remastered/pi37.ard/UK_pi37_ard3e8.binl';

    setUpAll(() {
      if (!File(path).existsSync()) return;
      ef = ExchangeFile(
        ukDataPath: path,
        spDataPath: path.replaceFirst('/UK_', '/SP_'),
        hasPair: false,
        isEvMsg: true,
      );
      ef.load();
    });

    test('carrega sem crash', () {
      if (!File(path).existsSync()) return;
      expect(ef.strings, isNotEmpty);
    });

    test('encontra "can\'t tell you yet" (apóstrofe BTN 0x71 em EvMsg)', () {
      if (!File(path).existsSync()) return;
      expect(ef.strings.any((s) => s.contains("can't tell you yet")), isTrue);
    });

    test('[BTN:71] não aparece — apóstrofe decodificado corretamente em EvMsg', () {
      if (!File(path).existsSync()) return;
      final bad = ef.strings.where((s) => s.contains('[BTN:71]')).toList();
      expect(bad, isEmpty, reason: 'Ainda tem [BTN:71] em EvMsg: $bad');
    });
  });
}

// Helper: comprimento original da string no buffer (até terminador)
int _origLen(Uint8List data, int off) {
  int len = 0;
  while (off + len < data.length &&
         data[off + len] != 0x00 &&
         data[off + len] != 0x06 &&
         data[off + len] != 0x02) {
    len++;
  }
  return len;
}
