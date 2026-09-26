# Puppy animation acceptance

The animation assets use one canonical two-month-old Golden Retriever reference and preserve the same pale golden fluffy coat, floppy ears, rounded baby face, short puppy legs, and proportions across states.

Before a release, verify at menu-bar and popover size:

1. The dog reads as a young Golden Retriever puppy, not an adult dog.
2. Walk, run, play, jump, and rest are visibly different poses.
3. Walk and run have different cadences; jump reads as the break warning.
4. Rest shows a gentle breathing scale and relaxed pose.
5. No frame is an emoji, geometric drawing, generic cartoon dog, or unrelated generated dog.
6. 「我幫你看著時間」 maps to `time-watch-01…04`: the puppy stays seated and communicates attention with its head and ears, never a walking loop.
7. 「自己玩，不吵你」 maps to the `relaxing` state, which only plays `play-ball-01…10`; every frame keeps the ball visible.
8. The canonical reference is packaged with the app and every motion resource resolves from `Bundle.module`.
