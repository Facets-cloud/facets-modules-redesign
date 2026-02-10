# Facets Module Catalog -- UX Design Specification

> Dark-themed GitHub Pages catalog for browsing Facets cloud infrastructure project types.
> Users select a cloud (AWS / GCP / Azure), see what is included, and copy Raptor CLI commands or Praxis AI prompts to import them.

---

## 1. Design Tokens

### 1.1 Color Palette

```
TOKEN                     VALUE         USAGE
----------------------------------------------------------------------
--bg-primary              #0B001C       Page background
--bg-surface              #110827       Card / panel backgrounds
--bg-surface-hover        #1A0F35       Hovered card surface
--bg-surface-selected     #1E1244       Selected / active card surface
--bg-code                 #0D0620       Code block backgrounds
--bg-input                #160C30       Search / input fields

--border-default          #2A1A4E       Card borders, dividers
--border-hover            #3D2A6E       Hovered borders
--border-selected         #645DF6       Selected card border (primary)
--border-focus            #645DF6       Focus ring color

--text-primary            #F0ECF9       Headings, primary copy
--text-secondary          #A89EC8       Body text, descriptions
--text-tertiary           #6E6490       Labels, muted metadata
--text-code               #C4B5FD       Inline code, command text

--accent-primary          #645DF6       Primary actions, links, tabs
--accent-primary-hover    #7A74FF       Hovered primary
--accent-primary-muted    rgba(100, 93, 246, 0.15)   Pill backgrounds

--gradient-facets-icon    linear-gradient(135deg, #3131AD, #8343BA, #FA485D)
--gradient-praxis         linear-gradient(135deg, #60a5fa, #a78bfa, #f472b6)
--gradient-glow           radial-gradient(ellipse at center, rgba(100,93,246,0.25) 0%, transparent 70%)

--color-aws               #FF9900
--color-aws-muted         rgba(255, 153, 0, 0.12)
--color-gcp               #4285F4
--color-gcp-muted         rgba(66, 133, 244, 0.12)
--color-azure             #0078D4
--color-azure-muted       rgba(0, 120, 212, 0.12)

--color-success           #34D399       "Copied!" feedback
--color-success-muted     rgba(52, 211, 153, 0.15)
```

### 1.2 Typography

Font family: **Plus Jakarta Sans** (Google Fonts), fallback: `system-ui, -apple-system, sans-serif`.

Code font: **JetBrains Mono** (Google Fonts), fallback: `'SF Mono', 'Cascadia Code', monospace`.

```
ROLE              SIZE    WEIGHT  LINE-HEIGHT  LETTER-SPACING  TOKEN
---------------------------------------------------------------------------
Page title (h1)   32px    800     1.2          -0.02em         --type-h1
Section head (h2) 22px    700     1.3          -0.01em         --type-h2
Card title (h3)   18px    700     1.3          -0.005em        --type-h3
Subsection (h4)   14px    700     1.4          0.02em          --type-h4
Body              15px    400     1.6          0               --type-body
Body small        13px    400     1.5          0.005em         --type-sm
Code block        13px    400     1.65         0               --type-code
Code inline       13px    500     inherit      0               --type-code-inline
Pill / badge      11px    600     1.0          0.04em          --type-pill
Tab label         14px    600     1.0          0.01em          --type-tab
Stat number       36px    800     1.1          -0.02em         --type-stat
Stat label        11px    600     1.0          0.06em          --type-stat-label
```

### 1.3 Spacing (4px base grid)

```
TOKEN          VALUE    COMMON USE
-------------------------------------------
--space-1      4px      Icon padding, inline gaps
--space-2      8px      Tight element gaps, pill padding-y
--space-3      12px     Card internal padding (small), pill padding-x
--space-4      16px     Card internal padding, element margins
--space-5      20px     Section inner padding
--space-6      24px     Card padding (standard), group gaps
--space-8      32px     Section gaps
--space-10     40px     Major section spacing
--space-12     48px     Page-level vertical rhythm
--space-16     64px     Hero spacing, top/bottom page padding
```

### 1.4 Radii and Shadows

```
TOKEN                     VALUE
--------------------------------------------------------------
--radius-sm               6px          Pills, badges
--radius-md               10px         Code blocks, buttons
--radius-lg               14px         Cards
--radius-xl               20px         Tab bar container

--shadow-card             0 2px 12px rgba(0, 0, 0, 0.3)
--shadow-card-hover       0 8px 32px rgba(100, 93, 246, 0.15)
--shadow-code             inset 0 1px 4px rgba(0, 0, 0, 0.4)
--shadow-glow-aws         0 0 40px rgba(255, 153, 0, 0.12)
--shadow-glow-gcp         0 0 40px rgba(66, 133, 244, 0.12)
--shadow-glow-azure       0 0 40px rgba(0, 120, 212, 0.12)
```

---

## 2. Layout

### 2.1 Page Frame

```
+------------------------------------------------------+
|  [max-width: 1200px, margin: 0 auto]                 |
|  padding: 0 --space-6                                |
|                                                      |
|  HEADER (--space-16 top, --space-12 bottom)          |
|  TAB BAR                                             |
|  CONTENT AREA (--space-10 top)                       |
|  FOOTER (--space-16 top, --space-12 bottom)          |
+------------------------------------------------------+
```

Background: `--bg-primary` fills full viewport. A subtle top-center radial glow (`--gradient-glow`) sits behind the header area at roughly 600px diameter, 20% opacity, to add visual warmth without distraction.

### 2.2 Responsive Breakpoints

```
BREAKPOINT       WIDTH        GRID COLUMNS   CARD LAYOUT
-------------------------------------------------------------
Mobile           < 640px      1 column        Stack everything
Tablet           640-1023px   2 columns       Side-by-side cards
Desktop          >= 1024px    3 columns       Full 3-card row
```

Horizontal padding collapses:
- Desktop: `--space-6` (24px)
- Tablet: `--space-5` (20px)
- Mobile: `--space-4` (16px)

---

## 3. Component Specifications

### 3.1 Header

```
+------------------------------------------------------+
|  [Facets logo, 28px height]  FACETS MODULE CATALOG   |
|                                                      |
|  Browse project types and import them in seconds     |
|  with Raptor CLI or Praxis AI.                       |
+------------------------------------------------------+
```

- Logo: Facets logomark SVG, 28px height, positioned inline-start of title.
- Title (h1): `--type-h1`, color `--text-primary`.
- Subtitle: `--type-body`, color `--text-secondary`, max-width 560px, centered.
- Spacing: 8px between logo and title, 12px between title and subtitle.

### 3.2 Tab Bar

```
+--[ Project Types ]----[ Templates ]--+
```

- Container: `--bg-surface` background, `--radius-xl` (20px), 4px padding, inline-flex, centered on page.
- Each tab button:
  - Padding: 10px 24px
  - Font: `--type-tab`
  - Border-radius: 16px (pill shape)
  - **Default**: transparent bg, `--text-tertiary` color
  - **Hover**: `--bg-surface-hover` bg, `--text-secondary` color
  - **Active/selected**: `--accent-primary` bg, `#FFFFFF` text
  - Transition: `background 250ms ease, color 250ms ease`
- "Templates" tab shows a "Coming Soon" badge: 9px text, `--accent-primary-muted` bg, `--accent-primary` text, pill shape, margin-left 8px.

### 3.3 Cloud Selection Cards

Three cards displayed in a responsive grid (3 cols desktop, 2 tablet, 1 mobile).

```
+-----------------------------------------+
|  [AWS icon 40px]                        |
|  Amazon Web Services          40 modules|
|                                         |
|  EKS clusters, managed RDS, ElastiCache,|
|  MSK, OpenSearch, and more              |
+-----------------------------------------+
```

**Card anatomy:**
- Dimensions: Fluid width, min-height 140px
- Padding: `--space-6` (24px)
- Background: `--bg-surface`
- Border: 1px solid `--border-default`
- Border-radius: `--radius-lg` (14px)
- Box-shadow: `--shadow-card`

**Card content:**
- Row 1: Cloud icon (40px, SVG) left-aligned, module count right-aligned
  - Module count: `--type-stat` for the number, `--type-stat-label` uppercase "MODULES" below
  - Number color: respective cloud brand color (`--color-aws`, etc.)
- Row 2 (12px below): Cloud name in `--type-h3`, color `--text-primary`
- Row 3 (8px below): Highlights blurb in `--type-sm`, color `--text-secondary`, max 2 lines

**Card states:**

| State    | Border               | Background              | Shadow                    | Transform     |
|----------|----------------------|-------------------------|---------------------------|---------------|
| Default  | `--border-default`   | `--bg-surface`          | `--shadow-card`           | none          |
| Hover    | `--border-hover`     | `--bg-surface-hover`    | `--shadow-card-hover`     | translateY(-2px) |
| Selected | cloud brand color    | `--bg-surface-selected` | cloud-specific glow shadow| translateY(-2px) |
| Focus    | `--border-focus` 2px | `--bg-surface`          | `--shadow-card`           | none          |

- Selection persists on click. Only one card selected at a time.
- On selection, a 2px left border accent in the cloud's brand color appears (like existing icon catalog cards).
- Transition: `all 300ms cubic-bezier(0.4, 0, 0.2, 1)`

### 3.4 Selection Detail Panel

Appears below the card grid when a cloud is selected. Slides in with animation (see Section 4).

```
+======================================================+
|  PRAXIS AI PROMPT                                    |
|  +--------------------------------------------------+
|  | Import the official Facets AWS project type and   | [Copy]
|  | set up a new project for me.                      |
|  |                                                   |
|  | raptor import project-type --managed facets/aws   |
|  | raptor create project <my-project>                |
|  | raptor get resource-types                         |
|  +--------------------------------------------------+
|                                                      |
|  RAPTOR CLI COMMAND                                  |
|  +--------------------------------------------------+
|  | raptor import project-type --managed facets/aws   | [Copy]
|  +--------------------------------------------------+
|  | With custom name:                                 |
|  | raptor import project-type --managed facets/aws \ | [Copy]
|  |   --name "My Platform"                            |
|  +--------------------------------------------------+
|                                                      |
|  WHAT'S INCLUDED                           40 modules|
|  +--------------------------------------------------+
|  | Infrastructure                                    |
|  | [VPC] [EKS] [S3] [CloudFront] [Route53] ...      |
|  |                                                   |
|  | Managed Datastores                                |
|  | [RDS MySQL] [RDS Postgres] [ElastiCache] ...      |
|  |                                                   |
|  | Self-hosted Datastores                            |
|  | [MongoDB] [Kafka] [Cassandra] ...                 |
|  |                                                   |
|  | K8s Platform                                      |
|  | [Ingress] [Cert Manager] [External DNS] ...       |
|  |                                                   |
|  | Operators & Monitoring                            |
|  | [Prometheus] [Grafana] [Alert Manager] ...        |
|  +--------------------------------------------------+
+======================================================+
```

**Panel container:**
- Margin-top: `--space-8` (32px) from card grid
- Background: `--bg-surface`
- Border: 1px solid `--border-default`
- Border-radius: `--radius-lg`
- Padding: `--space-8` (32px)
- Max-width: 100% of content area

**Panel sections separated by** 32px vertical spacing and a 1px `--border-default` horizontal rule.

### 3.5 Code Blocks

Two variants: **Praxis prompt** (multi-line, gradient accent) and **Raptor command** (single/short, standard).

**Shared code block properties:**
- Background: `--bg-code`
- Border: 1px solid `--border-default`
- Border-radius: `--radius-md` (10px)
- Padding: `--space-4` (16px) `--space-5` (20px)
- Font: `--type-code`, color `--text-code`
- Box-shadow: `--shadow-code`
- Position: relative (for copy button)
- `overflow-x: auto` for horizontal scroll on mobile
- `white-space: pre-wrap` for Praxis prompt; `white-space: pre` for Raptor commands

**Praxis prompt block** has a 2px left border using `--gradient-praxis`.

**Section labels** above code blocks:
- Font: `--type-pill`, uppercase
- Color: `--text-tertiary`
- Margin-bottom: `--space-2` (8px)
- Praxis label: Praxis gradient applied as `-webkit-background-clip: text` for a gradient text effect
- Raptor label: plain `--text-tertiary`

### 3.6 Copy Button

Positioned absolutely at top-right of each code block.

```
[ Copy ]  -->  [ Copied! ]
```

- Position: `top: 12px; right: 12px`
- Padding: 6px 14px
- Font: `--type-pill`
- Border-radius: `--radius-sm` (6px)
- Background: `rgba(255, 255, 255, 0.06)`
- Color: `--text-tertiary`
- Border: 1px solid `rgba(255, 255, 255, 0.08)`
- Cursor: pointer

**States:**
| State   | Background                   | Color             | Border                     |
|---------|------------------------------|-------------------|----------------------------|
| Default | `rgba(255,255,255,0.06)`     | `--text-tertiary` | `rgba(255,255,255,0.08)`   |
| Hover   | `rgba(255,255,255,0.12)`     | `--text-secondary`| `rgba(255,255,255,0.15)`   |
| Active  | `rgba(255,255,255,0.08)`     | `--text-secondary`| `rgba(255,255,255,0.10)`   |
| Copied  | `--color-success-muted`      | `--color-success` | `transparent`              |

- On click: copies code to clipboard, text changes to "Copied!" with a checkmark icon, reverts after 2000ms.
- Transition: `all 200ms ease`

### 3.7 "What's Included" Module Grid

**Category header:**
- Font: `--type-h4`, uppercase
- Color: `--text-secondary`
- Margin-bottom: `--space-3` (12px)
- A small 3px-wide, 20px-tall color bar precedes each header (inline-flex), using category-specific colors:

```
CATEGORY                 ACCENT COLOR
-------------------------------------------
Infrastructure           #4A90D9  (blue)
Managed Datastores       #34D399  (green)
Self-hosted Datastores   #FBBF24  (amber)
K8s Platform             #A78BFA  (purple)
Operators & Monitoring   #F87171  (red)
```

**Module pills:**
- Display: inline-flex, flex-wrap
- Gap: `--space-2` (8px)
- Each pill:
  - Padding: 6px 14px
  - Background: `--accent-primary-muted`
  - Color: `--text-secondary`
  - Border-radius: `--radius-sm` (6px)
  - Font: `--type-pill`
  - Border: 1px solid `rgba(100, 93, 246, 0.1)`
  - Optional: 20px module icon inline-start of text (if icon available), 6px gap
  - Hover: background brightens to `rgba(100, 93, 246, 0.25)`, color shifts to `--text-primary`
  - Transition: `all 200ms ease`

**Category groups** separated by `--space-6` (24px).

### 3.8 Templates Tab (Coming Soon)

```
+------------------------------------------------------+
|                                                      |
|  [illustration: abstract grid/blocks, muted purple]  |
|                                                      |
|  Templates are coming soon                           |
|  Pre-built environment configurations for common     |
|  deployment patterns.                                |
|                                                      |
+------------------------------------------------------+
```

- Centered vertically and horizontally within content area.
- Illustration: simple SVG, 120px, using `--accent-primary` at 30% opacity.
- Title: `--type-h2`, `--text-primary`.
- Description: `--type-body`, `--text-secondary`, max-width 400px, centered.

### 3.9 Footer

```
+------------------------------------------------------+
|  Built with Facets.cloud  |  Powered by Praxis AI    |
+------------------------------------------------------+
```

- Font: `--type-sm`, color `--text-tertiary`
- Centered, flex row with a `|` separator (with `--space-3` padding around it)
- "Facets.cloud" and "Praxis AI" are links:
  - Color: `--accent-primary`
  - Hover: underline, color `--accent-primary-hover`
- Padding: `--space-12` top, `--space-8` bottom

---

## 4. Animation & Transitions

### 4.1 Timing Tokens

```
TOKEN                     VALUE                           USE
-------------------------------------------------------------------------
--ease-default            cubic-bezier(0.4, 0, 0.2, 1)   General transitions
--ease-spring             cubic-bezier(0.34, 1.56, 0.64, 1) Bouncy enter
--duration-fast           150ms                           Button feedback
--duration-normal         250ms                           Tab switches, hovers
--duration-slow           400ms                           Panel slide-in
--duration-copy-feedback  2000ms                          "Copied!" revert delay
```

### 4.2 Card Hover

```css
.cloud-card {
  transition:
    transform 300ms var(--ease-default),
    box-shadow 300ms var(--ease-default),
    border-color 300ms var(--ease-default),
    background 300ms var(--ease-default);
}
.cloud-card:hover {
  transform: translateY(-2px);
}
```

### 4.3 Card Selection Glow

When a card is selected, a soft radial glow in the cloud's brand color appears behind it. Implemented as a `::before` pseudo-element:

```css
.cloud-card.selected::before {
  content: '';
  position: absolute;
  inset: -20px;
  border-radius: 30px;
  background: var(--cloud-glow);       /* e.g. rgba(255,153,0,0.08) for AWS */
  opacity: 0;
  transition: opacity 400ms var(--ease-default);
  z-index: -1;
  pointer-events: none;
}
.cloud-card.selected::before {
  opacity: 1;
}
```

### 4.4 Detail Panel Slide-In

When a cloud card is selected, the detail panel enters from below with a combined slide + fade:

```css
.detail-panel {
  opacity: 0;
  transform: translateY(16px);
  transition:
    opacity 400ms var(--ease-default),
    transform 400ms var(--ease-spring);
}
.detail-panel.visible {
  opacity: 1;
  transform: translateY(0);
}
```

On cloud switch (already visible panel), cross-fade content: fade out 150ms, swap, fade in 250ms.

### 4.5 Tab Switch

Active indicator slides between tabs using a `transform: translateX()` on a shared highlight element:

```css
.tab-highlight {
  position: absolute;
  background: var(--accent-primary);
  border-radius: 16px;
  transition: transform 300ms var(--ease-default), width 300ms var(--ease-default);
}
```

### 4.6 Module Pills Stagger

When the "What's Included" section appears, pills fade in with a staggered delay:

```css
.module-pill {
  opacity: 0;
  transform: translateY(6px);
  animation: pill-enter 300ms var(--ease-default) forwards;
}
/* nth-child delay: 20ms increments, capped at 500ms total */
.module-pill:nth-child(1)  { animation-delay: 0ms; }
.module-pill:nth-child(2)  { animation-delay: 20ms; }
/* ... */
.module-pill:nth-child(25) { animation-delay: 480ms; }

@keyframes pill-enter {
  to { opacity: 1; transform: translateY(0); }
}
```

### 4.7 Copy Button Feedback

```css
.copy-btn.copied {
  animation: copy-flash 300ms var(--ease-default);
}
@keyframes copy-flash {
  0%   { transform: scale(1); }
  50%  { transform: scale(1.08); }
  100% { transform: scale(1); }
}
```

---

## 5. Interaction Flows

### 5.1 Primary Flow

```
  Page loads
      |
      v
  [Header + Tab Bar + 3 Cloud Cards visible]
  (No card selected -- detail panel hidden)
      |
      v
  User clicks a cloud card (e.g., AWS)
      |
      v
  Card enters "selected" state:
    - border accent = --color-aws
    - glow pseudo-element fades in
    - translateY(-2px) persists
      |
      v
  Detail panel slides in below cards:
    - Praxis AI prompt (with Copy)
    - Raptor CLI commands (with Copy)
    - "What's Included" module grid
      |
      v
  User can:
    a) Click Copy on any code block --> "Copied!" feedback
    b) Click a different cloud card --> panel cross-fades to new data
    c) Click "Templates" tab --> content area transitions to coming-soon
    d) Click same card again --> deselects, detail panel slides out
```

### 5.2 Keyboard Navigation

```
TAB         Move focus: Tab Bar --> Cloud Cards (L-R) --> Code Blocks --> Copy Buttons
ENTER/SPACE Activate focused element (select card, copy code, switch tab)
ESCAPE      Deselect current cloud card, collapse detail panel
Arrow L/R   Move between tabs when tab bar is focused
```

---

## 6. Accessibility

### 6.1 Contrast Ratios (WCAG 2.1 AA minimum 4.5:1)

```
TEXT                       FOREGROUND     BACKGROUND     RATIO
--------------------------------------------------------------
Primary text on bg         #F0ECF9        #0B001C        15.2:1
Secondary text on bg       #A89EC8        #0B001C         7.8:1
Tertiary text on bg        #6E6490        #0B001C         4.6:1
Code text on code bg       #C4B5FD        #0D0620         9.1:1
Primary text on surface    #F0ECF9        #110827        13.5:1
Accent on bg               #645DF6        #0B001C         5.2:1
Cloud brand colors         varies         #110827        checked per cloud (all > 4.5:1)
```

### 6.2 Focus States

All interactive elements show a visible focus ring:
- `outline: 2px solid var(--border-focus)`
- `outline-offset: 2px`
- No `outline: none` anywhere.

### 6.3 ARIA Attributes

```html
<nav role="tablist" aria-label="Catalog sections">
  <button role="tab" aria-selected="true" aria-controls="panel-project-types">
    Project Types
  </button>
  <button role="tab" aria-selected="false" aria-controls="panel-templates">
    Templates <span aria-label="coming soon">Coming Soon</span>
  </button>
</nav>

<div role="tabpanel" id="panel-project-types" aria-labelledby="tab-project-types">
  <div role="radiogroup" aria-label="Select a cloud provider">
    <div role="radio" aria-checked="false" tabindex="0" aria-label="AWS - 40 modules">
      ...
    </div>
    <!-- GCP, Azure similarly -->
  </div>
</div>

<div role="region" aria-label="AWS project type details" aria-live="polite">
  <!-- detail panel content announced on change -->
</div>

<button aria-label="Copy Praxis AI prompt to clipboard">Copy</button>
```

### 6.4 Reduced Motion

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

---

## 7. Data Model (Consumed by the Page)

The page reads module data from an inline JSON or external JSON file. Structure:

```json
{
  "projectTypes": {
    "aws": {
      "name": "Amazon Web Services",
      "icon": "aws.svg",
      "moduleCount": 40,
      "highlights": "EKS clusters, managed RDS, ElastiCache, MSK, OpenSearch, and more",
      "praxisPrompt": "Import the official Facets AWS project type and set up a new project for me.\n\nraptor import project-type --managed facets/aws\nraptor create project <my-project>\nraptor get resource-types",
      "raptorImport": "raptor import project-type --managed facets/aws",
      "raptorImportNamed": "raptor import project-type --managed facets/aws --name \"My Platform\"",
      "categories": {
        "Infrastructure": ["VPC", "EKS", "S3", "CloudFront", "Route53", "..."],
        "Managed Datastores": ["RDS MySQL", "RDS Postgres", "ElastiCache", "..."],
        "Self-hosted Datastores": ["MongoDB", "Kafka", "Cassandra", "..."],
        "K8s Platform": ["Ingress Controller", "Cert Manager", "External DNS", "..."],
        "Operators & Monitoring": ["Prometheus", "Grafana", "Alert Manager", "..."]
      }
    },
    "gcp": { "..." : "..." },
    "azure": { "..." : "..." }
  }
}
```

---

## 8. Responsive Behavior Detail

### 8.1 Mobile (< 640px)

- Cloud cards stack vertically (1 column), full width.
- Tab bar stays horizontal, centered; pill buttons shrink padding to `8px 18px`.
- Code blocks: font-size drops to 12px, padding to 12px 14px.
- Detail panel padding: 20px.
- Module pills: font-size 10px, padding 4px 10px.
- Category headers: font-size 12px.
- Page title (h1): 24px.
- Stat numbers: 28px.

### 8.2 Tablet (640px -- 1023px)

- Cloud cards: 2-column grid (third card wraps below, centered).
- Code blocks: no changes from desktop.
- Module pills: same as desktop.

### 8.3 Desktop (>= 1024px)

- Cloud cards: 3-column grid.
- All specs at default sizes from Section 1.

---

## 9. File Structure (Implementation Reference)

The catalog will be a single `index.html` file in `/icons/` (or a dedicated `/catalog/` directory) suitable for GitHub Pages:

```
icons/
  catalog-spec.md          <-- this file
  index.html               <-- single-file catalog page
                                (all CSS inlined in <style>)
                                (all JS inlined in <script>)
                                (module data inlined as JSON)
  internal/
    icons.html             <-- existing icon catalog (internal tool)
    graph.html             <-- existing dependency graph (internal tool)
    wiring.html            <-- existing wiring explorer (internal tool)
```

No build step required. The page should load with zero external dependencies other than Google Fonts (Plus Jakarta Sans + JetBrains Mono).

---

## 10. Visual Reference (ASCII Wireframe)

### 10.1 Desktop -- No Selection

```
+================================================================+
|                                                                |
|               [Facets logo]  FACETS MODULE CATALOG             |
|        Browse project types and import them in seconds.        |
|                                                                |
|             [  Project Types  ] [  Templates  ]                |
|                                                                |
|  +------------------+ +------------------+ +------------------+|
|  |  [AWS]      40   | |  [GCP]      35   | | [Azure]     34   ||
|  |  Amazon Web      | |  Google Cloud    | | Microsoft Azure  ||
|  |  Services        | |  Platform        | |                  ||
|  |  EKS, RDS,       | |  GKE, Cloud SQL, | | AKS, Azure SQL,  ||
|  |  ElastiCache...  | |  Memorystore...  | | Redis Cache...   ||
|  +------------------+ +------------------+ +------------------+|
|                                                                |
+================================================================+
```

### 10.2 Desktop -- AWS Selected

```
+================================================================+
|                                                                |
|               [Facets logo]  FACETS MODULE CATALOG             |
|        Browse project types and import them in seconds.        |
|                                                                |
|             [ *Project Types* ] [  Templates  ]                |
|                                                                |
|  +==================+ +------------------+ +------------------+|
|  || [AWS]      40   | |  [GCP]      35   | | [Azure]     34   ||
|  || Amazon Web      | |  Google Cloud    | | Microsoft Azure  ||
|  || Services     <--selected, glow       | |                  ||
|  || EKS, RDS,       | |  GKE, Cloud SQL, | | AKS, Azure SQL,  ||
|  || ElastiCache...  | |  Memorystore...  | | Redis Cache...   ||
|  +==================+ +------------------+ +------------------+|
|                                                                |
|  +------------------------------------------------------------+|
|  |  PRAXIS AI PROMPT                                   [Copy] ||
|  |  +------------------------------------------------------+  ||
|  |  | Import the official Facets AWS project type and      |  ||
|  |  | set up a new project for me.                         |  ||
|  |  |                                                      |  ||
|  |  | raptor import project-type --managed facets/aws      |  ||
|  |  | raptor create project <my-project>                   |  ||
|  |  | raptor get resource-types                            |  ||
|  |  +------------------------------------------------------+  ||
|  |                                                             ||
|  |  --------------------------------------------------------  ||
|  |                                                             ||
|  |  RAPTOR CLI                                         [Copy] ||
|  |  +------------------------------------------------------+  ||
|  |  | raptor import project-type --managed facets/aws      |  ||
|  |  +------------------------------------------------------+  ||
|  |  With custom name:                                  [Copy] ||
|  |  +------------------------------------------------------+  ||
|  |  | raptor import project-type --managed facets/aws \    |  ||
|  |  |   --name "My Platform"                               |  ||
|  |  +------------------------------------------------------+  ||
|  |                                                             ||
|  |  --------------------------------------------------------  ||
|  |                                                             ||
|  |  WHAT'S INCLUDED                              40 modules   ||
|  |                                                             ||
|  |  | Infrastructure                                          ||
|  |  | [VPC] [EKS] [S3] [CloudFront] [Route53] [ACM] [WAF]    ||
|  |  |                                                         ||
|  |  | Managed Datastores                                      ||
|  |  | [RDS MySQL] [RDS Postgres] [ElastiCache] [MSK]         ||
|  |  | [OpenSearch] [DynamoDB]                                 ||
|  |  |                                                         ||
|  |  | Self-hosted Datastores                                  ||
|  |  | [MongoDB] [Kafka] [Cassandra] [Redis]                  ||
|  |  |                                                         ||
|  |  | K8s Platform                                            ||
|  |  | [Ingress] [Cert Manager] [External DNS] [Cluster       ||
|  |  |  Autoscaler] [Metrics Server]                          ||
|  |  |                                                         ||
|  |  | Operators & Monitoring                                  ||
|  |  | [Prometheus] [Grafana] [Alert Manager] [Loki]          ||
|  +------------------------------------------------------------+|
|                                                                |
|         Built with Facets.cloud | Powered by Praxis AI         |
+================================================================+
```

### 10.3 Mobile -- AWS Selected

```
+=============================+
|                             |
|  [logo] FACETS MODULE       |
|         CATALOG             |
|  Browse project types and   |
|  import them in seconds.    |
|                             |
|  [Project Types][Templates] |
|                             |
|  +=========================+|
|  || [AWS]            40    ||
|  || Amazon Web Services    ||
|  || EKS, RDS, ...         ||
|  +=========================+|
|                             |
|  +-------------------------+|
|  |  [GCP]            35   ||
|  |  Google Cloud Platform  ||
|  |  GKE, Cloud SQL, ...   ||
|  +-------------------------+|
|                             |
|  +-------------------------+|
|  |  [Azure]          34   ||
|  |  Microsoft Azure        ||
|  |  AKS, Azure SQL, ...   ||
|  +-------------------------+|
|                             |
|  +-------------------------+|
|  | PRAXIS AI PROMPT [Copy] ||
|  | +---------------------+ ||
|  | | Import the official | ||
|  | | Facets AWS project  | ||
|  | | type and set up ... | ||
|  | +---------------------+ ||
|  |                         ||
|  | RAPTOR CLI       [Copy] ||
|  | +---------------------+ ||
|  | | raptor import ...   | ||
|  | +---------------------+ ||
|  |                         ||
|  | WHAT'S INCLUDED         ||
|  | Infrastructure          ||
|  | [VPC][EKS][S3]          ||
|  | [CloudFront][Route53]   ||
|  | ...                     ||
|  +-------------------------+|
|                             |
|  Facets.cloud | Praxis AI  |
+=============================+
```

---

## End of Specification

All token values, sizes, and behaviors in this document should be treated as the source of truth for implementation. If a conflict arises between this spec and any existing page (e.g., `icons.html`), this spec takes precedence for the catalog page.
