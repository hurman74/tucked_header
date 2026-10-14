# tucked_header

Start a sliver hidden above the top of a scroll view, like a search field that waits above a list until you
pull it down, or start a pinned app bar collapsed. The height is measured during layout, so you don't have to
guess it.

<img src="https://raw.githubusercontent.com/hurman74/tucked_header/main/doc/demo.gif" width="340" alt="An inbox whose search field starts hidden under the app bar. A short pull snaps back, a longer pull snaps it open, and the search button brings it back after scrolling.">

## Install

```sh
flutter pub add tucked_header
```

## Usage

Wrap the sliver you want to hide in `SliverTucked` (or `SliverTucked.box` for a box widget). Put it first in
the `CustomScrollView`, or right after a pinned app bar:

```dart
import 'package:tucked_header/tucked_header.dart';

CustomScrollView(
  slivers: [
    const SliverAppBar(pinned: true, title: Text('Inbox')),
    SliverTucked.box(
      snap: true,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: SearchBar(hintText: 'Search mail'),
      ),
    ),
    SliverList.builder(itemCount: mails.length, itemBuilder: buildMail),
  ],
)
```

The first frame already has the search field scrolled out of sight under the app bar. Pull down to reveal it.

### Start a pinned app bar collapsed

```dart
const SliverTucked(
  extent: TuckExtent.toPinned,
  sliver: SliverAppBar.large(title: Text('Settings')),
)
```

`TuckExtent.toPinned` hides everything except the pinned part. The other options are `TuckExtent.full` (the
default) and `TuckExtent.pixels(n)`. You can also subclass `TuckExtent` to compute your own value from the
sliver's geometry.

### Reveal and tuck from code

```dart
final search = TuckController();

SliverTucked.box(controller: search, child: const SearchField());

IconButton(
  icon: Icon(search.isTucked ? Icons.search : Icons.keyboard_arrow_up),
  onPressed: search.toggle,
);
```

`TuckController` has `reveal()`, `tuck()` and `toggle()`, plus `isTucked`, `isRevealed`, `hiddenExtent` and
`tuckExtent`. It notifies its listeners after the frame in which `isTucked` or `isRevealed` changes, so calling
`setState` from a listener is safe.

### Options

| Parameter | Default | What it does |
| --- | --- | --- |
| `extent` | `TuckExtent.full` | How much of the sliver to hide. |
| `startTucked` | `true` | Whether to start tucked. When `false`, the sliver starts in view but still gets the other features. |
| `snap` | `false` | When scrolling stops with the sliver partly hidden, finish the movement: open if less than half is hidden, otherwise tuck. |
| `snapDuration`, `snapCurve` | 250 ms, `easeOutCubic` | The snap animation. |
| `controller` | none | A `TuckController`. |

## Why this package

The usual workaround ([flutter/flutter#53252](https://github.com/flutter/flutter/issues/53252)) is
`ScrollController(initialScrollOffset: headerHeight)`. That only works when you know the height before the
first frame. Text scale, wrapping chips, a different width or an image that loads later all change it, and a
wrong guess leaves part of the header showing or hides part of the list:

<img src="https://raw.githubusercontent.com/hurman74/tucked_header/main/doc/comparison.png" width="640" alt="Two inboxes at 130% text size. Left: initialScrollOffset 64 leaves the filter chips showing below the app bar. Right: SliverTucked hides the whole search header.">

`SliverTucked` measures the sliver while laying it out and moves the scroll position with a sliver scroll offset
correction before anything is painted. It also handles what happens next:

- **Resizing while tucked.** If the header grows or shrinks while it's out of view (an image arrives, the text
  scale changes, you rotate the device), the scroll offset moves by the same amount. The list doesn't jump and
  the header stays hidden.
- **Pinned slivers.** It counts the part covered by a pinned app bar, so a header under a pinned bar hides
  under it, and `TuckExtent.toPinned` starts a `SliverAppBar` collapsed.
- **No extra widgets.** It wraps your sliver in a single proxy render object. It doesn't add a scroll controller
  or a listener on every frame, and it works with any `ScrollController`, scroll physics and axis direction.

## Limitations

- The initial tuck happens on the sliver's first layout, and only if the sliver is visible then. Put it at the
  start of the scroll view, or after slivers that are pinned or tucked themselves. A `SliverTucked` placed
  further down won't scroll everything above it away.
- If the content is too short to scroll past the header, the scroll view springs back and the header shows.
- When a scroll view restores a saved offset (for example with `PageStorage`), the sliver is tucked again
  unless the restored offset already hides it.
- `TuckController.tuck()` and snapping assume the sliver is at the top of the scroll view. The controller only
  sees the sliver after it has been laid out at least once.
- A sliver that is already pinned or floating (like `SliverAppBar(floating: true)`) has its own scroll behavior.
  Only `TuckExtent.toPinned` on pinned app bars is tested.
