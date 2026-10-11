import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/widgets/ajo_ui.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      const AjoBrand(),
                      TextButton(
                        onPressed: () => context.go('/sign-in'),
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  LayoutBuilder(
                    builder: (context, box) {
                      final intro = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR PEOPLE. YOUR PLANS.',
                            style: TextStyle(
                              color: AjoColors.emerald,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Small steps.\nShared possibilities.',
                            style: TextStyle(
                              fontSize: box.maxWidth > 700 ? 58 : 38,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                              color: AjoColors.forest,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Bring your ajo circle together. Agree the plan, keep track of contributions, and know whose turn comes next.',
                            style: TextStyle(fontSize: 18, height: 1.6),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton(
                                onPressed: () => context.go('/sign-up'),
                                child: const Text('Start your circle'),
                              ),
                              OutlinedButton(
                                onPressed: () => context.go('/sign-in'),
                                child: const Text('I have an invite'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Early access · external bank transfers only',
                            style: TextStyle(color: AjoColors.muted),
                          ),
                        ],
                      );
                      final preview = AjoPanel(
                        color: AjoColors.forest,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'A PLAN THAT FITS YOUR CIRCLE',
                              style: TextStyle(
                                color: AjoColors.mint,
                                letterSpacing: 1.2,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Together, with clarity.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 24),
                            for (final item in const [
                              (
                                '01',
                                'Agree your terms',
                                'Choose an amount, a rhythm and your people.',
                              ),
                              (
                                '02',
                                'Keep everyone in the picture',
                                'Share payment evidence and review it together.',
                              ),
                              (
                                '03',
                                'Follow every payout',
                                'Record transfers and acknowledge receipt.',
                              ),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 22),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AjoColors.mint,
                                      child: Text(item.$1),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.$2,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.$3,
                                            style: const TextStyle(
                                              color: AjoColors.mint,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                      return box.maxWidth >= 800
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: intro),
                                const SizedBox(width: 48),
                                Expanded(child: preview),
                              ],
                            )
                          : Column(
                              children: [
                                intro,
                                const SizedBox(height: 32),
                                preview,
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 40),
                  LayoutBuilder(
                    builder: (context, box) {
                      final cards = [
                        _plan(
                          'Take turns. Move forward.',
                          'Rotating ajo keeps each contribution fixed. Your circle agrees when the accumulated money goes to the next member.',
                          Icons.groups_rounded,
                        ),
                        _plan(
                          'Save towards a date.',
                          'Set a minimum regular contribution. Members can save more towards their own final payout. No promised interest.',
                          Icons.savings_outlined,
                        ),
                      ];
                      return box.maxWidth >= 700
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: cards[0]),
                                const SizedBox(width: 20),
                                Expanded(child: cards[1]),
                              ],
                            )
                          : Column(
                              children: [
                                cards[0],
                                const SizedBox(height: 20),
                                cards[1],
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Built for conversations, not confusion.',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Each group has its own chat, agreed schedule and payment history. Members see their contributions; leaders review the circle’s reports.',
                  ),
                  const SizedBox(height: 24),
                  const AjoPanel(
                    child: Text(
                      'AjoPay currently coordinates savings records. It does not hold funds, create bank accounts, verify identities or collect fees. Use people you trust and confirm bank details before transferring.',
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'AjoPay · Save together, clearly.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _plan(String title, String body, IconData icon) => AjoPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AjoColors.emerald, size: 32),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(body),
      ],
    ),
  );
}
