import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rume/paywall/state/paywall_cubit.dart';

PaywallCubit _cubit() => PaywallCubit(purchaseDelay: Duration.zero);

void main() {
  test('[PAY-2] episode 7 and later are locked until unlocked', () {
    const state = PaywallState();
    expect(state.isLocked(6), isFalse);
    expect(state.isLocked(7), isTrue);
    expect(state.isLocked(8), isTrue);
  });

  blocTest<PaywallCubit, PaywallState>(
    '[PAY-8] unlocking goes through a purchasing state, then unlocks',
    build: _cubit,
    act: (c) => c.unlock(),
    expect: () => const [
      PaywallState(purchasing: true),
      PaywallState(unlocked: true),
    ],
    verify: (c) => expect(c.state.isLocked(7), isFalse),
  );

  blocTest<PaywallCubit, PaywallState>(
    '[PAY-8] repeated taps purchase once',
    build: _cubit,
    act: (c) async {
      await Future.wait([c.unlock(), c.unlock(), c.unlock()]);
    },
    expect: () => const [
      PaywallState(purchasing: true),
      PaywallState(unlocked: true),
    ],
  );
}
