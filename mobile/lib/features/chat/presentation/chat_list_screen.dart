import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/text_direction.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/conversation_controller.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(chatSessionsProvider);
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chat/new'),
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(l10n.newConversation),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(chatSessionsProvider.future),
          child: sessions.when(
            loading: () => const LoadingView(),
            error: (e, _) => ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                ErrorView(
                  message: e is ApiException
                      ? describeApiException(l10n, e)
                      : l10n.errorUnexpected,
                  onRetry: () => ref.invalidate(chatSessionsProvider),
                ),
              ],
            ),
            data: (items) => items.isEmpty
                ? ListView(
                    children: [
                      EmptyView(
                        title: l10n.chatEmptyTitle,
                        message: l10n.chatEmptyBody,
                        icon: Icons.chat_bubble_outline,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.sm,
                      96,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final s = items[i];
                      return ListTile(
                        title: BidiText(
                          s.title ?? l10n.untitledConversation,
                          maxLines: 2,
                        ),
                        subtitle: Text(
                          DateFormat.yMMMd(
                            locale,
                          ).add_jm().format(s.updatedAt.toLocal()),
                        ),
                        onTap: () => context.push(
                          '/chat/c/${Uri.encodeComponent(s.id)}',
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
