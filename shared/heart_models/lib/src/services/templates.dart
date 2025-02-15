import 'package:heart_models/heart_models.dart';

abstract interface class TemplateService {
  Future<Iterable<Template>?> getTemplates();

  Future<void> saveTemplate(Template template);

  Future<void> deleteTemplate(String templateId);
}
