# Marriage4Life App - Style Guide for Liveness Package

This document contains the design system and styling guidelines for the Marriage4Life app, to ensure the liveness detection package matches the app's look and feel.

---

## Color Palette

### Brand Colors (Gradient Button)

| Name | Hex Code | RGB | Usage |
|------|----------|-----|-------|
| CTA Blue | `#5A8FD4` | `rgb(90, 143, 212)` | Gradient start, primary CTA |
| CTA Pink | `#D47A9E` | `rgb(212, 122, 158)` | Gradient end, secondary accent |

### Primary Colors

| Name | Hex Code | Usage |
|------|----------|-------|
| Primary Blue | `#2563EB` | Links, interactive elements, focus states |
| Primary Blue Pressed | `#1D4ED8` | Button pressed state |
| Primary Blue Hover | `#1E40AF` | Button hover state |

### Neutral Colors

| Name | Hex Code | Usage |
|------|----------|-------|
| Text Primary | `#1F2937` | Headlines, primary text |
| Text Secondary | `#374151` | Body text |
| Text Tertiary | `#4B5563` | Subtitles, less emphasis |
| Text Muted | `#6B7280` | Labels, placeholders |
| Text Disabled | `#9CA3AF` | Disabled states |
| Border Light | `#E5E7EB` | Input borders, dividers |
| Border Disabled | `#D1D5DB` | Disabled borders, disabled button bg |
| Background | `#FAFAFA` | Page backgrounds |
| Surface | `#FFFFFF` | Cards, inputs, dialogs |
| Divider | `#F1F5F9` | Subtle dividers |

### Feedback Colors

| Name | Hex Code | Usage |
|------|----------|-------|
| Error | `#EF4444` | Error states, validation errors |
| Success | (use CTA gradient) | Success states |

---

## Typography

### Font Weights

```dart
FontWeight.w400  // Regular - body text
FontWeight.w500  // Medium - labels, titleMedium
FontWeight.w600  // SemiBold - headings, emphasis
FontWeight.w700  // Bold - headlines, buttons
```

### Text Styles

| Style Name | Size | Weight | Color | Line Height | Usage |
|------------|------|--------|-------|-------------|-------|
| displayLarge | 32 | w700 | #1F2937 | - | Large hero text |
| displayMedium | 28 | w600 | #1F2937 | - | Section headers |
| headlineLarge | 24 | w600 | #1F2937 | - | Page titles |
| headlineMedium | 20 | w600 | #1F2937 | - | Card titles |
| headlineSmall | ~18 | w700 (bold) | #1F2937 | - | Subsection titles |
| titleLarge | 18 | w600 | #1F2937 | - | List headers |
| titleMedium | 16 | w500 | #1F2937 | - | Button text, emphasis |
| bodyLarge | 16 | w400 | #374151 | 1.5 | Large body text |
| bodyMedium | 14 | w400 | #374151 | 1.5 | Default body text |
| labelLarge | 14 | w500 | #374151 | - | Form labels |
| labelSmall | ~12 | w600 | varies | - | Badges, chips |

### Common Text Style Patterns

```dart
// Headlines
theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)

// Subtitles (muted)
theme.textTheme.bodyLarge?.copyWith(color: const Color(0xFF374151), height: 1.5)

// Section titles
theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)

// Muted/secondary text
theme.textTheme.bodyMedium?.copyWith(
  color: theme.colorScheme.onSurface.withValues(alpha: 0.7)
)
```

---

## Spacing

### Standard Spacing Scale

| Name | Value | Usage |
|------|-------|-------|
| xs | 4 | Tight spacing between related items |
| sm | 8 | Small gaps |
| md | 12 | Medium gaps |
| lg | 16 | Section spacing |
| xl | 24 | Major section gaps, page padding |
| xxl | 32 | Large section breaks |
| xxxl | 48 | Hero spacing |

### Page Padding

```dart
const EdgeInsets.all(24)  // Standard page padding
const EdgeInsets.symmetric(horizontal: 24)  // Horizontal padding
```

---

## Border Radius

| Usage | Radius |
|-------|--------|
| Buttons | 16 |
| Cards | 16 |
| Inputs | 12-14 |
| Chips/Tags | 12 |
| Dialogs | 16 |
| Bottom sheets | 20-24 (top only) |
| Small elements | 6-8 |

---

## Shadows

### Button Glow Effect (Gradient Button)

```dart
boxShadow: [
  BoxShadow(
    color: const Color(0xFF5A8FD4).withValues(alpha: 0.4),  // ctaBlue
    blurRadius: 16,
    offset: const Offset(0, 6),
  ),
  BoxShadow(
    color: const Color(0xFFD47A9E).withValues(alpha: 0.25),  // ctaPink
    blurRadius: 20,
    offset: const Offset(0, 10),
  ),
],
```

### Card/Dialog Shadow

```dart
boxShadow: [
  BoxShadow(
    color: const Color(0x14000000),  // Very subtle black
    blurRadius: 6,
    offset: const Offset(0, 2),
  ),
],
```

---

## Gradients

### Primary CTA Gradient

```dart
LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    const Color(0xFF5A8FD4),  // ctaBlue
    const Color(0xFFD47A9E),  // ctaPink
  ],
)
```

### Subtle Background Gradient

```dart
LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    const Color(0xFF5A8FD4).withValues(alpha: 0.3),
    const Color(0xFFD47A9E).withValues(alpha: 0.3),
  ],
)
```

---

## Component Patterns

### Primary Button (GradientButton)

```dart
// Full width gradient button with glow
Container(
  width: double.infinity,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF5A8FD4), Color(0xFFD47A9E)],
    ),
    boxShadow: [/* glow shadows */],
  ),
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Text(
          'Button Label',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    ),
  ),
)
```

### Tip Card

```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
  ),
  child: Row(
    children: [
      Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(child: Text('Tip text here')),
    ],
  ),
)
```

### Dark Overlay Screen

```dart
Container(
  color: Colors.black.withValues(alpha: 0.85),
  child: SafeArea(
    child: Column(
      children: [
        // Content centered
      ],
    ),
  ),
)
```

### Dark Mode Text

```dart
// Primary text on dark
TextStyle(
  color: Colors.white,
  fontSize: 24,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.5,
)

// Secondary text on dark
TextStyle(
  color: Colors.white.withValues(alpha: 0.7),
  fontSize: 16,
  fontWeight: FontWeight.w400,
  height: 1.5,
)

// Muted text on dark
TextStyle(
  color: Colors.white.withValues(alpha: 0.5),
  fontSize: 14,
)
```

---

## Icon Sizes

| Context | Size |
|---------|------|
| Standard inline | 20-24 |
| List item leading | 20 |
| Large feature icon | 56 |
| Hero/splash icon | 80-96 |
| Button icon | 22 |
| Close/action buttons | 28 |

---

## Animations

### Duration Standards

| Type | Duration |
|------|----------|
| Micro interactions | 150-200ms |
| State changes | 200-300ms |
| Page transitions | 300-400ms |
| Complex animations | 500-800ms |
| Countdown animations | 300ms per tick |

### Easing Curves

```dart
Curves.easeInOut      // Default for most animations
Curves.easeOutCubic   // Slide animations
Curves.easeIn         // Fade in
Curves.elasticOut     // Bounce/spring effects
```

---

## Dark Mode Considerations

When displaying UI over camera preview or dark backgrounds:

1. **Text**: Use `Colors.white` or `Colors.white.withValues(alpha: 0.7)` for secondary
2. **Backgrounds**: Use `Colors.black.withValues(alpha: 0.85)` for overlays
3. **Borders**: Use `Colors.white.withValues(alpha: 0.2)` for subtle borders
4. **Icons**: Use white icons with appropriate alpha for hierarchy
5. **Buttons**: Keep the gradient colors, they work well on dark

---

## Quick Reference Code Snippets

### Import Colors in Fork

```dart
// Brand gradient colors
const Color ctaBlue = Color(0xFF5A8FD4);
const Color ctaPink = Color(0xFFD47A9E);

// Text colors for dark backgrounds
const Color textPrimaryDark = Colors.white;
final Color textSecondaryDark = Colors.white.withValues(alpha: 0.7);
final Color textMutedDark = Colors.white.withValues(alpha: 0.5);

// Overlay background
final Color overlayBackground = Colors.black.withValues(alpha: 0.85);
```

### Standard Container on Dark

```dart
Container(
  margin: const EdgeInsets.symmetric(horizontal: 32),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
  ),
  child: /* content */,
)
```
