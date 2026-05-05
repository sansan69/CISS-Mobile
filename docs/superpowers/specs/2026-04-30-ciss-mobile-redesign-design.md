# CISS Mobile Redesign Design

Date: 2026-04-30
Project: `/Users/mymac/Documents/CISS-Mobile`
Status: Approved in conversation, pending final spec review

## Goal

Redesign the entire Flutter app so it feels professional, operational, and production-grade on Android-first mobile devices while preserving the current product model:

- guards use the app for attendance, profile, leave, training, incidents, evaluations, and payslips
- field officers use it for dashboards, work orders, guard oversight, and reporting

The chosen direction is:

- base visual language: `Direction B - Clear Duty`
- secondary influence: measured premium polish from `Direction A - Command Slate`
- tertiary influence: selective tactical clarity from `Direction C - Tactical Panels`
- layout density: `Balanced Operations`
- navigation: `Custom Branded Navigation`

## Product Intent

The app should feel like a serious workforce operations tool, not a generic Flutter template and not an over-styled concept app. It should prioritize:

- readability in real working conditions
- predictable screen structure
- clean, professional visual hierarchy
- clear primary actions
- role-specific information density
- strong fit on Android phones without overflow, visual crowding, or inconsistent paddings

## Scope

This redesign covers the full app:

- design tokens and theme
- shared layout system
- branded navigation and shell
- auth and entry flows
- guard dashboards and modules
- field officer dashboards and modules
- empty, loading, error, sync, and offline states

This redesign does not change the core business model or backend API contract unless a screen needs a minor presentation-oriented adjustment.

## Visual Direction

### Foundation

The redesign should be primarily bright and operational, not heavy dark-mode-first. Surfaces should use clean, soft neutrals with navy branding accents and restrained emphasis colors.

### Influence Mix

#### From Clear Duty

- clean enterprise readability
- light surfaces
- spacious but not wasteful layouts
- familiar mobile patterns
- high legibility for forms, tables, lists, and dashboards

#### From Command Slate

- sharper hierarchy in hero/header areas
- more intentional dashboard composition
- stronger typography contrast
- premium presentation of key metrics and priority cards

#### From Tactical Panels

- higher-contrast action zones for attendance and reporting
- stronger state chips and operational banners
- more assertive treatment for urgent actions and status surfaces

### Visual Rules

- default surfaces should be light
- dark treatment should be reserved for emphasis zones, top-level status, or priority banners
- accent colors should be purposeful, not decorative
- tactical styling should appear in action-heavy screens, not everywhere
- visual weight should decrease as task criticality decreases

## Design System

The redesign should be system-first. Before reworking screens, create a coherent design system that all screens use.

### Tokens

Define app-wide tokens for:

- color
- typography
- spacing
- radius
- borders
- shadows/elevation
- icon sizing
- control heights
- state colors

### Color System

Use a light operational palette:

- primary brand navy for structure and emphasis
- secondary blue/slate for supporting hierarchy
- warm amber/gold only as measured emphasis
- success green for valid/completed states
- warning amber/orange for pending/risk states
- error red for failed/blocked states
- neutral grays for surfaces, borders, and secondary text

Avoid:

- oversized dark gradients across normal content pages
- translucent glass styling as the default surface treatment
- white text on nearly every screen

### Typography

Typography should be clearer and more standard than the current implementation:

- strong heading family with disciplined weight use
- highly legible body text for operational reading
- consistent title scales across shells and cards
- better distinction between labels, values, and metadata

### Spacing and Surface Rules

The app should standardize:

- page horizontal padding
- vertical rhythm between sections
- card padding
- list row height
- form spacing
- safe-area handling
- bottom navigation clearance

All primary screens should look composed, with cards fitting naturally inside the viewport rather than floating as disconnected blocks.

## Core Component System

Build the redesign around reusable Flutter components rather than redesigning per screen.

### Required Shared Components

- `AppShellScaffold`
- `BrandedTopBar`
- `PageHeader`
- `SectionHeader`
- `MetricTile`
- `PriorityBanner`
- `ActionCard`
- `StatusChip`
- `InfoCard`
- `StructuredListRow`
- `FormSection`
- `PrimaryActionBar`
- `StateBlock` for empty/loading/error/offline
- `RoleAwareBottomNav`

### Component Behavior

Each component should have:

- consistent spacing
- predictable internal alignment
- small and medium variants where needed
- explicit support for long text wrapping and truncation
- visual states for normal, emphasis, warning, and disabled use

## App Shell and Navigation

### Navigation Model

The app should keep bottom navigation as the main mobile model for both roles, but the navigation should become branded and more intentional than default Material styling.

### Navigation Design

The bottom navigation should:

- fit cleanly inside Android safe areas
- use clearer active-state contrast
- maintain stable icon and label spacing
- avoid oversized glass effects
- feel lighter and more integrated with the page

### Top Bar Design

The top bar should:

- be more compact than the current implementation
- support title, subtitle, and action slots
- use consistent title sizing
- avoid overly decorative logo framing
- still keep brand presence visible

## Screen Templates

All app screens should map to a small set of templates.

### 1. Overview Screens

Used for:

- guard dashboard
- field officer dashboard

Structure:

- page header
- key metrics row/grid
- priority banner or main context card
- recent activity or upcoming items
- quick actions

### 2. Task Screens

Used for:

- attendance
- visit reports
- training reports
- work-order actions

Structure:

- page intro
- task context card
- primary action block
- supporting details
- history or submitted items below

### 3. Directory and Detail Screens

Used for:

- guard directory
- profile
- payslips
- leave
- training
- evaluations
- incidents

Structure:

- page header
- optional search/filter strip
- grouped cards or structured rows
- clear separation between summary and detailed information

## Role Experience Strategy

The app should look like one product with two operating modes, not two different apps.

### Guard Experience

Guard screens should prioritize:

- clarity
- reassurance
- direct primary actions
- simpler hierarchy
- less dense information

### Field Officer Experience

Field officer screens should prioritize:

- faster scanning
- more visible metrics
- better summaries across districts and guards
- denser operational lists
- stronger priority callouts

The design system should support this through composition, not by creating a totally separate visual language.

## Flow Redesign

### Auth and Entry

#### Login Hub

Redesign goals:

- cleaner first impression
- obvious guard entry point
- more professional officer/admin access presentation
- reduced decorative noise
- better spacing and CTA clarity

#### Role Login

Redesign goals:

- stronger form hierarchy
- tighter label/help/error presentation
- better input sizing and padding
- more professional action treatment

#### Permission Onboarding

Redesign goals:

- explain why permissions matter
- reduce “wall of requirement” feeling
- distinguish guard-only operational permissions from general app permissions

### Guard Dashboard

The new dashboard should become a real operational home screen.

Content priority:

- next shift
- attendance state
- site/client context
- alerts or pending items
- leave balance
- evaluation/training health
- recent activity
- quick actions

### Attendance

This should be one of the strongest redesigned screens in the app.

Redesign goals:

- stronger task focus
- obvious primary action
- clearer GPS/photo/site state
- cleaner grouping of site, shift, duty point, and proof inputs
- better handling of sync/offline states

This screen should borrow the most from `Tactical Panels`, but remain consistent with the broader app.

### Field Officer Dashboard

This should feel like a district command surface.

Content priority:

- assigned districts
- active guards
- upcoming work orders
- pending reports
- recent activity
- priority operational issues

### Work Orders and Reports

These should become denser than guard flows while staying readable.

Redesign goals:

- stronger list hierarchy
- better metadata grouping
- cleaner filters or section blocks
- more obvious priority and status indicators

### Supporting Modules

The following screens should use the systemized card/list/detail approach:

- profile
- leave
- training
- evaluations
- incidents
- payslips
- guards directory

## State Design

The redesign must explicitly handle non-happy paths.

### Required States

- loading
- empty
- error
- offline
- syncing
- stale data
- disabled action

These should be designed components, not plain centered text or default indicators.

## Interaction Rules

The following rules apply across the redesign:

- every screen has one dominant action
- every section has a clear heading or role
- metrics should be grouped and scannable
- long pages should be chunked into digestible sections
- status should always use consistent color + shape + label patterns
- user feedback should be immediate and visible

## Technical Design Approach

### Phase 1: System Layer

Build:

- redesigned theme
- token definitions
- shared shell
- navigation
- shared cards, tiles, rows, and state blocks

### Phase 2: High-Value Flows

Redesign:

- login hub
- role login
- permission onboarding
- guard dashboard
- field officer dashboard
- attendance
- work orders
- reports

### Phase 3: Supporting Modules

Redesign:

- guard profile
- leave
- training
- payslips
- evaluations
- incidents
- guards directory
- more/support screens

## Validation Criteria

The redesign is successful if:

- the app looks consistent end to end
- all key screens fit naturally on Android devices
- the UI feels professional and operational rather than experimental
- action-heavy screens are faster to parse
- both roles feel intentionally supported
- shared components reduce repetitive custom screen styling

## Recommended Implementation Approach

Use a `system-first redesign`:

1. rebuild the design system
2. rebuild app shell/navigation
3. redesign auth and dashboards
4. redesign action-heavy workflows
5. redesign supporting screens

This is the recommended path because it produces the most consistent result and avoids screen-by-screen drift.
