import 'package:heart_models/heart_models.dart';

abstract interface class TemplateService {
  Future<Iterable<Template>> getTemplates(String? userId);

  Future<Template> startTemplate({int? order, String? userId});

  Future<void> updateTemplate(Template template);

  Future<void> deleteTemplate(String templateId);

  Future<void> storeTemplates(Iterable<Template> templates, {String? userId});
}
