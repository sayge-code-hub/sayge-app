import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../domain/entities/proposal.dart';

/// Opens Invoices with a draft prefilled from [proposal] (quote → invoice).
void openInvoiceFromProposal(BuildContext context, Proposal proposal) {
  context.go(AppRoutes.invoices, extra: proposal);
}
