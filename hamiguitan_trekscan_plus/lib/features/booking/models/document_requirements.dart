/// Defines document requirements and discounts for each trekker category
/// Centralized configuration for easy updates when new resolutions are passed
class DocumentRequirements {
  static const Map<String, DocumentType> categoryDocuments = {
    'student': DocumentType(
      name: 'Student',
      discount: 50,
      discountDescription: '50% discount',
      requiredDocs: [
        DocumentField(
          name: 'Medical Certificate',
          description: 'Original medical certificate',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
        DocumentField(
          name: 'Valid Government ID',
          description: 'Photocopy of valid government ID',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
        DocumentField(
          name: 'Student ID',
          description: 'School or University Student ID',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
        DocumentField(
          name: 'Certificate of Registration',
          description: 'School/University Certificate of Registration',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
      ],
    ),
    'senior_citizen': DocumentType(
      name: 'Senior Citizen',
      discount: 20,
      discountDescription: '20% discount (if outside Davao Oriental resident)',
      requiredDocs: [
        DocumentField(
          name: 'Medical Certificate',
          description: 'Original medical certificate',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
        DocumentField(
          name: 'Valid Government ID',
          description: 'Photocopy of valid government ID',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
        DocumentField(
          name: 'Senior Citizen ID',
          description: 'Official Senior Citizen ID',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
      ],
    ),
    'dav_oriental_resident': DocumentType(
      name: 'Davao Oriental Resident',
      discount: 50,
      discountDescription: '50% discount for Davao Oriental residents',
      requiredDocs: [
        DocumentField(
          name: 'Medical Certificate',
          description: 'Original medical certificate',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
        DocumentField(
          name: 'Valid Government ID',
          description: 'Photocopy of valid government ID',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
        DocumentField(
          name: 'Barangay Certificate of Residency',
          description:
              'Barangay Certificate of Residency (Inside Davao Oriental)',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
      ],
    ),
    'outdoor_club_federation': DocumentType(
      name: 'Outdoor Club Federation Member',
      discount: 67,
      discountDescription: '67% discount (equivalent to 2,000 pesos)',
      requiredDocs: [
        DocumentField(
          name: 'Medical Certificate',
          description: 'Original medical certificate',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
        DocumentField(
          name: 'Valid Government ID',
          description: 'Valid Government ID',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
        DocumentField(
          name: 'OCF ID',
          description: 'Official Outdoor Club Federation ID',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
      ],
    ),
    'children': DocumentType(
      name: 'Children (8-15 years old)',
      discount: 50,
      discountDescription:
          '50% discount for 15-17 years old, variable pricing for 8-14 years',
      requiredDocs: [
        DocumentField(
          name: 'Medical Certificate',
          description: 'Original medical certificate',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
        DocumentField(
          name: 'Valid Government ID',
          description: 'Photocopy of valid government ID',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
        DocumentField(
          name: 'Parent Consent',
          description: 'Parent/Guardian Consent Form',
          extension: ['pdf', 'docx', 'jpg', 'jpeg', 'png'],
        ),
      ],
    ),
    'mfsm': DocumentType(
      name: 'MFSM Member',
      discount: 25,
      discountDescription: '25% discount (equivalent to 750 pesos)',
      requiredDocs: [
        DocumentField(
          name: 'Medical Certificate',
          description: 'Original medical certificate',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
        DocumentField(
          name: 'Valid Government ID',
          description: 'Photocopy of valid government ID',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
        DocumentField(
          name: 'MFSM ID',
          description: 'Official MFSM ID',
          extension: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
      ],
    ),
  };

  /// Get documents for a specific category
  static DocumentType? getDocumentsForCategory(String category) {
    return categoryDocuments[category.toLowerCase()];
  }

  /// Get all required document field names for a category
  static List<String> getRequiredDocumentsForCategory(String category) {
    final docType = getDocumentsForCategory(category);
    return docType?.requiredDocs.map((d) => d.name).toList() ?? [];
  }

  /// Get discount percentage for a category
  static int? getDiscountForCategory(String category) {
    return getDocumentsForCategory(category)?.discount;
  }

  /// Get discount description for a category
  static String? getDiscountDescriptionForCategory(String category) {
    return getDocumentsForCategory(category)?.discountDescription;
  }

  /// Get all available categories
  static List<String> getAllCategories() {
    return categoryDocuments.keys.toList();
  }

  /// Get category display name
  static String getCategoryDisplayName(String category) {
    return getDocumentsForCategory(category)?.name ?? category;
  }
}

/// Represents a document type with required fields
class DocumentType {
  final String name;
  final int discount;
  final String discountDescription;
  final List<DocumentField> requiredDocs;

  const DocumentType({
    required this.name,
    required this.discount,
    required this.discountDescription,
    required this.requiredDocs,
  });
}

/// Represents a single document field
class DocumentField {
  final String name;
  final String description;
  final List<String> extension;

  const DocumentField({
    required this.name,
    required this.description,
    required this.extension,
  });
}
