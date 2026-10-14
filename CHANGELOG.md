## 0.1.0

* Initial release.
* `SliverTucked` and `SliverTucked.box`: start a sliver tucked above the top of the scroll view, measured
  during layout. While tucked, the scroll offset follows the sliver's size so the content doesn't jump.
* `TuckExtent.full`, `TuckExtent.toPinned` (start a pinned app bar collapsed) and `TuckExtent.pixels`.
* Optional `snap` to finish a partial reveal when scrolling stops.
* `TuckController` with `reveal`, `tuck`, `toggle`, `isTucked`, `isRevealed` and `hiddenExtent`.
