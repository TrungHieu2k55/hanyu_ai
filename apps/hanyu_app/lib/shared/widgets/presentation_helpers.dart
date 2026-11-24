import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';

Widget buildPageTitle(String title, String subtitle) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      title,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: brandInk,
      ),
    ),
    const SizedBox(height: 10),
    Text(subtitle, style: const TextStyle(color: mutedText)),
  ],
);
Widget buildSectionHeading(
  String text, {
  String? action,
  VoidCallback? onTap,
}) => Wrap(
  alignment: WrapAlignment.spaceBetween,
  crossAxisAlignment: WrapCrossAlignment.center,
  spacing: 16,
  children: [
    Text(
      text,
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
    ),
    if (action != null) TextButton(onPressed: onTap, child: Text(action)),
  ],
);
Widget buildActionTile(
  IconData icon,
  String title,
  String subtitle,
  VoidCallback onTap,
) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
    leading: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: softSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: brandTeal),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right, color: mutedText),
    onTap: onTap,
  ),
);
