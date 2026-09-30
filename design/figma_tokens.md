# VitalUp — Figma tokens reference

**Source:** https://www.figma.com/design/CbY8DZfkfu8MG63OPvZSYv/Vitalup
- File key: `CbY8DZfkfu8MG63OPvZSYv`
- Light-theme section: `206:4919`
- Components section: `823:5479`

These tokens are implemented in:
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_dimens.dart` (also holds `AppShadows` and `AppDurations`)
- `lib/core/theme/app_text_styles.dart`
- `lib/core/theme/app_theme.dart` (`VitalUpColors`, `ThemeData`)
- `lib/core/utils/responsive.dart`

**Product override:** the page gutter is **16dp**. Figma frames use 20dp.

## Colours
| Token | Value |
|---|---|
| primary | `#19C3E0` |
| primary active text | `#149CB3` |
| teal (secondary text) | `#0F7586` |
| darker (text) | `#1C1C1C` |
| lighter (bg) | `#FEFEFE` |
| grey text | `#757575` |
| button text | `#0C0C0C` |
| secondary button border | `#B9B9B9` |
| glass fill | `rgba(186,186,186,.13)` |
| glass border | `rgba(186,186,186,.27)` |
| divider | `#BABABA @ 30%` |
| progress track | `rgba(186,186,186,.2)` |
| primary fill | `rgba(25,195,224,.13)` |
| primary tint (icon badge) | `rgba(25,195,224,.2)` |
| error | `#E24B4A` |
| error fill | `rgba(226,75,74,.13)` |
| success | `#4CAF50` |
| success tint | `rgba(76,175,80,.2)` |
| hairline (toast) | `#D8D8D8` |

## Typography (SF Pro Rounded)
| Figma style | Size / weight | TextTheme slot |
|---|---|---|
| Large Title | 36 / 600 | `displayLarge` |
| heading 1 | 32 / 600 | `headlineLarge` |
| heading 2 | 26 / 500 | `headlineMedium`, `displayMedium` |
| heading 3 | 20 / 500 | `headlineSmall`, `titleMedium`, `displaySmall` |
| body 16 med | 16 / 500 | `titleSmall`, `labelLarge` |
| body reg 16 | 16 / 400, ls 0.24 | `bodyLarge` |
| small reg 14 | 14 / 400 | `bodyMedium`, `labelMedium` |
| small reg 12 | 12 / 400 | `bodySmall`, `labelSmall` |
| caption 12 | JetBrains Mono 12 / 500, uppercase | `AppTextStyles.caption` / `AppCaption` |
| metric | 36 / 300 | `AppTextStyles.metric` |
| metric large | 48 / 400 | `AppTextStyles.metricLarge` |

## Components
**Primary button** (`AppPrimaryButton`)
- 48h, radius 14, primary fill, `#0C0C0C` label (body 16 med).
- Padding 16/12, full width.

**Secondary button** (`AppSecondaryButton`)
- 48h, radius 14, transparent fill, 1px `#B9B9B9` border, teal label.

**Back button** (`BackIcon`)
- 48 circle, white @ 50% fill, "shadow black y", 24 arrow.

**Input** (theme `inputDecorationTheme`)
- 56h, radius 20, padding 16/20.
- Label: body 16 med, 6dp above the field.
- Hint: small 14, grey.
- States:
  - Default: glass fill, glass border.
  - Active: 2px primary border plus glow, text `#149CB3`.
  - Filled: primary fill.
  - Error: 2px `#E24B4A` border, error fill, red text.

**Card** (`AppCard`)
- Radius 16, glass fill plus cyan sheen gradient, glass border.
- Padding: `card/big` 12/20, `card/small` 20/16.
- Inner gap 16.
- `highlighted` gives the cyan insight card.

**Icon badge** (`AppIconBadge`)
- 40 circle, accent @ 20%, icon at half size.

**Progress bar** (`AppProgressBar`)
- 8h pill, success fill, track colour.

**Info note** (`AppInfoNote`, Figma `toast/info`)
- Radius 12, `#D8D8D8` hairline, 18 info icon, small 14 grey text.

**Page header** (`AppPageHeader`)
- Glass bar with bottom border and 16 vertical padding.
- Back button, then 12 gap, then heading 2 title (+ small 14 grey subtitle).
- Optional 44 circle `AppHeaderAction` (primary fill, primary border, primary icon).

**Bottom nav** (Figma `bars & panels/tab`)
- Lighter fill, radius 58, "elevated" shadow, padding 32/8.
- Items are 51h with 32 icons and 4 gap.
- Label: small 12, grey; the selected label is darker with a soft cyan glow behind the icon.

**Segmented tabs** (Move / Rest / Fuel / Vitals)
- Glass container, radius 16, padding 8.
- Selected segment: primary fill, radius 10, 41h, segment shadow.
- Label: 14 / 500, darker.

**Quick-action tile**
- 80w glass tile, radius 16, padding 20, 12 gap.
- 40 icon badge, then small 12 label.

**Layout**
- Section gap 24, card gap 12.
- Content capped at 600dp on tablets (`ResponsiveCenter` / `AppScaffold`).

## Screen map (light theme, `206:4919`)
| Area | Figma section | Notes |
|---|---|---|
| Splash | `57:139` | |
| Welcome | `68:123` | |
| Sign up | `49:33` | |
| Login | `52:310` | |
| Loader | `724:5289` | |
| Onboarding | `1018:6350` | frames named `onboarding/<step>/<state>` |
| Food scanner | `1172:7765` | |
| Track (home dashboard, detail pages, edit sheets) | `1297:16722` | |
| Health coach (includes diet plan) | `1893:14544` | |
| Components | `823:5479` | |
