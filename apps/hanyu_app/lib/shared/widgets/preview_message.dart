import 'package:flutter/material.dart';

void showPreviewMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
