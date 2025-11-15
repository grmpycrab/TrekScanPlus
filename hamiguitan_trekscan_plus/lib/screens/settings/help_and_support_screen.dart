import 'package:flutter/material.dart';

class HelpAndSupportScreen extends StatelessWidget {
  const HelpAndSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF252B30),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We\'re Here to Help',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF252B30),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Have questions or need assistance? Our dedicated support team is ready to help you make the most of Trek Scan Plus.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF252B30),
                ),
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                'How do I book a trek?',
                'You can easily book a trek by navigating to the Trek Schedule section, selecting your preferred date, and following the booking process. Check the calendar for available slots.',
              ),
              _buildFAQItem(
                'What is the badge system?',
                'The badge system rewards your trekking achievements and engagement. Earn badges by reaching different stations, scanning QR codes, and practicing sustainable trekking habits.',
              ),
              _buildFAQItem(
                'How do I scan QR codes?',
                'Use the Scanner feature in the bottom navigation menu. Point your camera at the QR codes located along the trekking route to learn interesting facts about Mt. Hamiguitan.',
              ),
              _buildFAQItem(
                'Is my booking data secure?',
                'Yes! Trek Scan Plus uses Firebase security protocols to protect your personal and booking information with industry-standard encryption.',
              ),
              _buildFAQItem(
                'Can I cancel or modify my booking?',
                'You can manage your bookings through your profile. For assistance with cancellations or modifications, please contact our support team.',
              ),
              const SizedBox(height: 32),
              const Text(
                'Contact Us',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF252B30),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reach out to our support team through any of these channels:',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              _buildContactItem(
                icon: Icons.email,
                label: 'Email Support',
                value: 'keyntharly@gmail.com',
              ),
              _buildContactItem(
                icon: Icons.email,
                label: 'Email Support',
                value: 'shannenmendoza.310@gmail.com',
              ),
              _buildContactItem(
                icon: Icons.school,
                label: 'University',
                value: 'dorsuunacom@gmail.com',
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF252B30).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF252B30).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Support Hours',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF252B30),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Monday - Friday: 9:00 AM - 5:00 PM (PST)\nWeekends: 10:00 AM - 3:00 PM (PST)\n\nWe typically respond to inquiries within 24 business hours.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Additional Resources',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF252B30),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Visit our website and documentation for additional guides, tutorials, and resources to help you get the most out of Trek Scan Plus.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF252B30),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              answer,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF252B30).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF252B30), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF252B30),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
