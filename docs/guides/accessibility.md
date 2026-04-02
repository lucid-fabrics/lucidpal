---
sidebar_position: 17
title: Accessibility
---

# Accessibility

LucidPal implements several iOS accessibility features. This page documents what is currently supported and what is not yet addressed.

---

## Reduce Motion

LucidPal respects the iOS **Reduce Motion** system setting (`Settings → Accessibility → Motion → Reduce Motion`).

All animated components read `@Environment(\.accessibilityReduceMotion)` and adapt:

| Component | With Motion | Reduce Motion |
|-----------|-------------|---------------|
| Orbital session ring (session list) | Pulsing stroke + rotating ring | Ring hidden entirely (`accessibilityHidden(true)`) |
| Session card slide-in | 8 px offset + spring animation | Instant appear, no offset |
| Message bubble slide-in | 8–12 px offset + spring animation | Instant appear, no offset |

**Relevant files:**
- `SessionListView+Subviews.swift:76` — orbital ring reads `reduceMotion`, hides ring and stops all animations
- `MessageBubbleView.swift:33` — bubble entrance skips offset and animation when `reduceMotion` is true

---

## VoiceOver

### Labelled elements

| Element | Label |
|---------|-------|
| Pinned prompt chips | `"Pinned prompt: <text>"` + hint: `"Double tap to fill input. Long press for options."` |
| Error dismiss button | `"Dismiss error"` |
| Model loading banner | `"AI model loading, please wait"` (children combined) |
| No-model banner | `"Your AI isn't set up yet. Go to Settings to download a model."` |
| AirPods auto-listen banner | `"AirPods connected, auto-listening active"` |
| Template start button | `"Start <name> chat"` |
| Reminder card | `"Reminder: <title>, scheduled for <date>"` |
| Voice overlay cancel | `"Cancel recording"` |
| Voice overlay confirm | `"Confirm recording"` |
| Temperature slider | label: `"Temperature"`, value: numeric with 2 decimal places |
| Onboarding CTA button | Dynamic label from `ctaLabel` variable |
| Onboarding progress indicator | `"Step N of N"` with `.updatesFrequently` trait |
| Model selection row | `"<name>[, Recommended][, Selected]"` with `.isSelected` trait |
| Onboarding animated text | `.accessibilityElement(children: .ignore)` + static label |

### Hidden elements (decorative/redundant)

The following are marked `accessibilityHidden(true)` because they are decorative or redundant with a parent label:

- Orbital ring in session list
- Decorative icons in `ChatView+Banners` (3 instances)
- Decorative illustrations in `UnsupportedDeviceView` (4 instances)
- Decorative images in `OnboardingCarouselView` (5 instances)

---

## Dynamic Type

LucidPal does **not** currently implement `dynamicTypeSize` overrides. Text uses system defaults and will scale with the user's preferred text size via SwiftUI's automatic Dynamic Type support for standard `Text` views.

No components explicitly opt out of Dynamic Type scaling.

---

## Known Gaps

| Area | Issue |
|------|-------|
| `ChatView+Subviews.swift` | No explicit VoiceOver labels on typing indicator or streaming state |
| `HabitDashboardView.swift` | Habit progress rings have no accessibility labels |
| `ThinkingDisclosure.swift` | Thinking disclosure triangle has no label |
| `MessageBubbleView+ImageViewer.swift` | Image viewer has no accessibility label on the image |
| Navigation order | Focus order in chat is not explicitly set; relies on SwiftUI default top-to-bottom |
| `CalendarActionPill.swift` | Calendar action pill has no explicit label |

---

## Testing VoiceOver

Enable VoiceOver on device or simulator:

```
Settings → Accessibility → VoiceOver → On
```

Or via Simulator: `Hardware → Toggle Software Keyboard` is not related — use `Xcode → Open Simulator → I/O → VoiceOver`.

Quick shortcut: triple-click the side button (if configured in `Settings → Accessibility → Accessibility Shortcut`).
