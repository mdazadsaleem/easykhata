class SupportRequestModel {
  const SupportRequestModel({
    required this.id,
    required this.ownerId,
    required this.businessId,
    required this.subject,
    required this.category,
    required this.description,
    required this.screenshotUrl,
    required this.deviceInfo,
    required this.status,
  });

  final String id;
  final String ownerId;
  final String businessId;
  final String subject;
  final String category;
  final String description;
  final String screenshotUrl;
  final Map<String, String> deviceInfo;
  final String status;
}
