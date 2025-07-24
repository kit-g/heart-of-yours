import 'package:heart_models/heart_models.dart';

abstract interface class TemplateService {
  Future<Iterable<Template>> getTemplates(String? userId , ExerciseLookup lookup);

  Future<Template> startTemplate({int? order, String? userId});

  Future<void> updateTemplate(Template template);

  Future<void> deleteTemplate(String templateId);

  Future<void> storeTemplates(Iterable<Template> templates, {String? userId});
}

abstract interface class RemoteTemplateService {
  Future<Iterable<Template>?> getTemplates(ExerciseLookup lookForExercise);

  Future<bool> saveTemplate(Template template);

  Future<bool> deleteTemplate(String templateId);
}
