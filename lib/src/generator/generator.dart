import 'dart:convert';

import '../constants/constants.dart';
import 'label.dart';
import 'templates.dart';
import 'intl_translation_helper.dart';
import 'generator_exception.dart';
import '../config/pubspec_config.dart';
import '../utils/utils.dart';
import '../utils/file_utils.dart';

class Generator {
  String _className;
  String _mainLocale;
  bool _otaEnabled;
  String _dirPath;

  Generator() {
    var pubspecConfig = PubspecConfig();

    _className = defaultClassName;
    _dirPath = deafultGeneratedDirPath;
    if (pubspecConfig.className != null) {
      if (isValidClassName(pubspecConfig.className)) {
        _className = pubspecConfig.className;
      } else {
        warning(
            "Config parameter 'class_name' requires valid 'UpperCamelCase' value.");
      }
    }

    if (pubspecConfig.path != null) {
      _dirPath = pubspecConfig.path;
    }

    _mainLocale = defaultMainLocale;
    if (pubspecConfig.mainLocale != null) {
      if (isValidLocale(pubspecConfig.mainLocale)) {
        _mainLocale = pubspecConfig.mainLocale;
      } else {
        warning(
            "Config parameter 'main_locale' requires value consisted of language code and optional script and country codes separated with underscore (e.g. 'en', 'en_GB', 'zh_Hans', 'zh_Hans_CN').");
      }
    }

    _otaEnabled =
        pubspecConfig.localizelyConfig?.otaEnabled ?? defaultOtaEnabled;
  }

  Future<void> generateAsync() async {
    await _updateL10nDir();
    await _updateGeneratedDir();
    await _generateDartFiles();
  }

  Future<void> _updateL10nDir() async {
    var mainArbFile = getArbFileForLocale(_mainLocale);
    if (mainArbFile == null) {
      await createArbFileForLocale(_mainLocale);
    }
  }

  Future<void> _updateGeneratedDir() async {
    var labels = _getLabelsFromMainArbFile();
    var locales = _orderLocales(getLocales());
    var content =
        generateL10nDartFileContent(_className, labels, locales, _otaEnabled);
    await updateL10nDartFile(content, _dirPath);

    var intlDir = getIntlDirectory(_dirPath);
    if (intlDir == null) {
      await createIntlDirectory(_dirPath);
    }

    await removeUnusedGeneratedDartFiles(locales, _dirPath);
  }

  List<Label> _getLabelsFromMainArbFile() {
    var mainArbFile = getArbFileForLocale(_mainLocale);
    if (mainArbFile == null) {
      throw GeneratorException(
          "Can't find ARB file for the '$_mainLocale' locale.");
    }

    var content = mainArbFile.readAsStringSync();
    var decodedContent = json.decode(content) as Map<String, dynamic>;

    var labels =
        decodedContent.keys.where((key) => !key.startsWith('@')).map((key) {
      var name = key;
      var content = decodedContent[key];

      var meta = decodedContent['@$key'] ?? {};
      var type = meta['type'];
      var description = meta['description'];
      var placeholders = meta['placeholders'] != null
          ? (meta['placeholders'] as Map<String, dynamic>).keys.toList()
          : null;

      return Label(name, content,
          type: type, description: description, placeholders: placeholders);
    }).toList();

    return labels;
  }

  List<String> _orderLocales(List<String> locales) {
    var index = locales.indexOf(_mainLocale);
    return index != -1
        ? [
            locales.elementAt(index),
            ...locales.sublist(0, index),
            ...locales.sublist(index + 1)
          ]
        : locales;
  }

  Future<void> _generateDartFiles() async {
    var outputDir = getIntlDirectoryPath(_dirPath);
    var dartFiles = [getL10nDartFilePath(_dirPath)];
    var arbFiles = getArbFiles().map((file) => file.path).toList();

    var helper = IntlTranslationHelper();
    helper.generateFromArb(outputDir, dartFiles, arbFiles);
  }
}
