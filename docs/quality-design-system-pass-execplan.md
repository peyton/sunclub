# Quality Design System Pass ExecPlan

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Bring the current Timeline-first Sunclub app closer to the attached design references while preserving the new Timeline tab and top timeline scrubber. The pass focuses on shared design-system primitives, dark mode, scroll/safe-area behavior, widget/watch compact surfaces, and data-preservation guardrails.

## Progress

- [x] Created a dedicated branch for the quality pass.
- [x] Ran parallel subagent audits for visual design, widgets/watch, migration/data handling, and release validation.
- [x] Reworked shared `AppColor` tokens so base components adapt in dark appearance.
- [x] Reworked shared screen headers so screen titles are large and left-aligned.
- [x] Removed the root scroll clipping that made backgrounds and bottom content feel cut off.
- [x] Preserved the Timeline tab name and top timeline scrubber.
- [x] Expanded the Timeline exposure card with peak UV and elevated-hour context.
- [x] Updated the shared UV card so the meter is larger and overlaps the card edge.
- [x] Added widget decoding and stale-timer tests for data safety.
- [x] Updated support, privacy, and insights surfaces to use flatter shared components.

## Surprises & Discoveries

- Observation: The renamed Timeline tab and top scrubber already existed and needed preservation, not a rollback to the older Today tab.
  Evidence: `AppRoute.AppTab.today.title` returns `Timeline`, and `TimelineHomeView` owns `timelineSelector`.
- Observation: Dark mode was split between adaptive `AppPalette` and light-only `AppColor`, so shared primitives could still render light-only colors.
  Evidence: `AppDesignSystem.swift` used fixed RGB colors before this pass.
- Observation: Widget and Watch reapply surfaces could ask for a reapply from stale previous-day state if called through the lower-level snapshot deadline helper.
  Evidence: `SunclubWidgetSnapshot.reapplyDeadline` did not verify that the latest log belonged to the current day.

## Decision Log

- Decision: Keep this pass centered on shared design tokens and compact high-risk screens instead of rewriting every screen.
  Rationale: Shared primitives affect Timeline, History, Settings, Support, Privacy, widgets, and Watch without creating a broad restyle branch.
  Date/Author: 2026-05-08 / Codex
- Decision: Treat dark mode as semantic token work first.
  Rationale: Fixing `AppColor` protects older reusable components and Watch-adjacent surfaces that do not yet use all of `AppPalette`.
  Date/Author: 2026-05-08 / Codex
- Decision: Keep the Timeline scrubber and enrich the selected-day content below it.
  Rationale: The scrubber is now core navigation; the missing piece was detailed daily sun-exposure context.
  Date/Author: 2026-05-08 / Codex

## Implemented Improvement Ledger

- [x] [Shared Design System] 001. Added adaptive base text tokens for dark appearance.
- [x] [Shared Design System] 002. Added adaptive background token for warm dark canvas.
- [x] [Shared Design System] 003. Added adaptive warm background token.
- [x] [Shared Design System] 004. Added adaptive base surface token.
- [x] [Shared Design System] 005. Added adaptive elevated surface token.
- [x] [Shared Design System] 006. Added adaptive control fill token.
- [x] [Shared Design System] 007. Added adaptive blue accent token.
- [x] [Shared Design System] 008. Added adaptive soft accent token.
- [x] [Shared Design System] 009. Added adaptive sun token.
- [x] [Shared Design System] 010. Added adaptive soft sun token.
- [x] [Shared Design System] 011. Added adaptive success token.
- [x] [Shared Design System] 012. Added adaptive warning token.
- [x] [Shared Design System] 013. Added adaptive muted token.
- [x] [Shared Design System] 014. Added adaptive stroke token.
- [x] [Shared Design System] 015. Added dedicated primary action fill token.
- [x] [Shared Design System] 016. Added dedicated primary action foreground token.
- [x] [Shared Design System] 017. Updated `PrimaryButton` to use action foreground semantics.
- [x] [Shared Design System] 018. Updated `AppPrimaryButtonStyle` fill semantics.
- [x] [Shared Design System] 019. Updated `AppPrimaryButtonStyle` foreground semantics.
- [x] [Shared Design System] 020. Updated `SunPrimaryButtonStyle` fill semantics.
- [x] [Shared Design System] 021. Updated `SunPrimaryButtonStyle` foreground semantics.
- [x] [Shared Design System] 022. Centralized UV severity tint mapping.
- [x] [Shared Design System] 023. Reused UV severity mapping in forecast symbols.
- [x] [Shared Design System] 024. Reused UV severity mapping in forecast numbers.
- [x] [Shared Design System] 025. Reused UV severity mapping in Timeline chart bars.
- [x] [Shared Design System] 026. Kept color token implementation compatible with non-UIKit targets.
- [x] [Shared Design System] 027. Added contrast tests for adaptive base text colors.
- [x] [Shared Design System] 028. Added contrast tests for adaptive primary action colors.
- [x] [Shared Design System] 029. Documented dark-mode token intent in the design system.
- [x] [Shared Design System] 030. Documented the design-system-first path for future screen work.
- [x] [Timeline] 031. Preserved the Timeline tab title.
- [x] [Timeline] 032. Preserved the top timeline day scrubber.
- [x] [Timeline] 033. Preserved horizontal page snapping below the scrubber.
- [x] [Timeline] 034. Kept offscreen Timeline pages hidden from accessibility.
- [x] [Timeline] 035. Expanded the selected-day UV content into sun-exposure context.
- [x] [Timeline] 036. Renamed the daily forecast card to `Today's Sun Exposure` for today.
- [x] [Timeline] 037. Added selected-day exposure titles for past days.
- [x] [Timeline] 038. Added selected-day exposure titles for future days.
- [x] [Timeline] 039. Added peak UV metric to the exposure card.
- [x] [Timeline] 040. Added peak time copy to the exposure card.
- [x] [Timeline] 041. Added elevated-hours metric to the exposure card.
- [x] [Timeline] 042. Added low-UV fallback copy to the exposure card.
- [x] [Timeline] 043. Added high-intensity hour count copy.
- [x] [Timeline] 044. Added elevated-window copy.
- [x] [Timeline] 045. Kept WeatherKit source labeling visible.
- [x] [Timeline] 046. Kept forecast source labeling visible when estimated.
- [x] [Timeline] 047. Kept sunscreen log summary directly below UV context.
- [x] [Timeline] 048. Preserved direct edit route from the sunscreen log summary.
- [x] [Timeline] 049. Preserved forecast drill-in from the UV card.
- [x] [Timeline] 050. Enlarged the shared UV meter.
- [x] [Timeline] 051. Made the UV meter overlap the card top-left.
- [x] [Timeline] 052. Kept UV card recommendation copy visible.
- [x] [Timeline] 053. Kept UV card accessibility label combined.
- [x] [Timeline] 054. Preserved `home.uvIndexCard` identifiers.
- [x] [Timeline] 055. Added metric identifiers for exposure-card UI tests.
- [x] [Scroll/Nav] 056. Removed root scroll clipping.
- [x] [Scroll/Nav] 057. Added footerless-screen bottom padding from the shared screen wrapper.
- [x] [Scroll/Nav] 058. Removed duplicate Settings bottom padding.
- [x] [Scroll/Nav] 059. Preserved root safe-area inset tab bar behavior.
- [x] [Scroll/Nav] 060. Preserved keyboard-dismiss behavior in root scrolls.
- [x] [Scroll/Nav] 061. Made `SunLightHeader` left-aligned.
- [x] [Scroll/Nav] 062. Made `SunLightHeader` use the large screen-title token.
- [x] [Scroll/Nav] 063. Removed fake leading spacer from root headers.
- [x] [Scroll/Nav] 064. Removed fake trailing spacer from root headers.
- [x] [Scroll/Nav] 065. Preserved `screen.back` identifier.
- [x] [Scroll/Nav] 066. Preserved visible chevron back affordance.
- [x] [Scroll/Nav] 067. Allowed long screen titles to wrap to two lines.
- [x] [Scroll/Nav] 068. Kept root headers leading aligned with content.
- [x] [Scroll/Nav] 069. Kept compact back-button tap target size.
- [x] [Scroll/Nav] 070. Kept trailing icon support for future headers.
- [x] [Scroll/Nav] 071. Reduced Settings bottom whitespace.
- [x] [Scroll/Nav] 072. Reduced Timeline bottom cutoff risk.
- [x] [Scroll/Nav] 073. Reduced Insights bottom cutoff risk.
- [x] [Scroll/Nav] 074. Reduced History bottom cutoff risk.
- [x] [Scroll/Nav] 075. Centralized future tab-underlap fixes in one wrapper.
- [x] [Dark Mode] 076. Added adaptive shared card surface.
- [x] [Dark Mode] 077. Added adaptive shared elevated surface.
- [x] [Dark Mode] 078. Added adaptive shared control fill.
- [x] [Dark Mode] 079. Added adaptive shared stroke.
- [x] [Dark Mode] 080. Added adaptive shared muted color.
- [x] [Dark Mode] 081. Added adaptive action colors for dark primary buttons.
- [x] [Dark Mode] 082. Kept dark action foreground navy on amber.
- [x] [Dark Mode] 083. Kept light action foreground white on navy.
- [x] [Dark Mode] 084. Ensured AppCard borders resolve in dark mode.
- [x] [Dark Mode] 085. Ensured StatCard surfaces resolve in dark mode.
- [x] [Dark Mode] 086. Ensured FeatureIcon surfaces resolve in dark mode.
- [x] [Dark Mode] 087. Ensured InfoRow chevrons inherit adaptive secondary text.
- [x] [Dark Mode] 088. Ensured DayCapsule future fill inherits adaptive surface.
- [x] [Dark Mode] 089. Ensured DayCapsule selected stroke inherits adaptive text.
- [x] [Dark Mode] 090. Ensured AppShadow derives from adaptive primary text.
- [x] [Dark Mode] 091. Added dark contrast coverage for design-system text.
- [x] [Dark Mode] 092. Added dark contrast coverage for controls.
- [x] [Dark Mode] 093. Added dark contrast coverage for action buttons.
- [x] [Dark Mode] 094. Rebalanced Insights postcard dark gradient.
- [x] [Dark Mode] 095. Reduced Insights art opacity in dark mode.
- [x] [Dark Mode] 096. Kept Insights postcard warm in light mode.
- [x] [Dark Mode] 097. Added Watch dark background fallback.
- [x] [Dark Mode] 098. Added Watch dark card fallback.
- [x] [Dark Mode] 099. Added Watch dark primary text fallback.
- [x] [Dark Mode] 100. Added Watch dark secondary text fallback.
- [x] [Widget/Watch] 101. Added detail copy to the small Today widget.
- [x] [Widget/Watch] 102. Reduced small widget icon size to fit detail copy.
- [x] [Widget/Watch] 103. Reduced small widget title size to fit detail copy.
- [x] [Widget/Watch] 104. Hid small widget decorative motif from accessibility.
- [x] [Widget/Watch] 105. Hid streak widget decorative motif from accessibility.
- [x] [Widget/Watch] 106. Preserved small widget action pill.
- [x] [Widget/Watch] 107. Preserved widget open-log intent routing.
- [x] [Widget/Watch] 108. Preserved widget logged-state deep link routing.
- [x] [Widget/Watch] 109. Added stale reapply deadline guard.
- [x] [Widget/Watch] 110. Added same-day base-date guard for reapply deadline.
- [x] [Widget/Watch] 111. Preserved widget timeline refresh before a valid reapply deadline.
- [x] [Widget/Watch] 112. Prevented previous-day reapply deadlines from driving Watch copy.
- [x] [Widget/Watch] 113. Added Watch severity tinting for low UV.
- [x] [Widget/Watch] 114. Added Watch severity tinting for moderate UV.
- [x] [Widget/Watch] 115. Added Watch severity tinting for high UV.
- [x] [Widget/Watch] 116. Added Watch severity tinting for very high UV.
- [x] [Widget/Watch] 117. Added Watch severity tinting for extreme UV.
- [x] [Widget/Watch] 118. Preserved Watch quick log button.
- [x] [Widget/Watch] 119. Preserved Watch sync status filtering.
- [x] [Widget/Watch] 120. Preserved Watch open URL routes.
- [x] [Widget/Watch] 121. Kept Watch log button accessibility label.
- [x] [Widget/Watch] 122. Kept Watch log button accessibility hint.
- [x] [Widget/Watch] 123. Kept Today widget presentation family coverage.
- [x] [Widget/Watch] 124. Added test coverage for stale widget reapply state.
- [x] [Widget/Watch] 125. Kept pending widget route compatibility tests intact.
- [x] [Data Handling] 126. Made widget snapshot decoding tolerate missing onboarding state.
- [x] [Data Handling] 127. Made widget snapshot decoding tolerate missing recorded days.
- [x] [Data Handling] 128. Made widget snapshot decoding tolerate missing current streak.
- [x] [Data Handling] 129. Made widget snapshot decoding tolerate missing longest streak.
- [x] [Data Handling] 130. Made widget snapshot decoding tolerate missing weekly count.
- [x] [Data Handling] 131. Made widget snapshot decoding tolerate missing monthly applied count.
- [x] [Data Handling] 132. Made widget snapshot decoding tolerate missing monthly day count.
- [x] [Data Handling] 133. Made widget snapshot decoding tolerate missing reapply enabled flag.
- [x] [Data Handling] 134. Made widget snapshot decoding default missing reapply interval.
- [x] [Data Handling] 135. Clamped decoded reapply interval to a positive value.
- [x] [Data Handling] 136. Preserved optional SPF decoding.
- [x] [Data Handling] 137. Preserved optional UV decoding.
- [x] [Data Handling] 138. Preserved optional accountability decoding.
- [x] [Data Handling] 139. Added minimal legacy widget payload decode test.
- [x] [Data Handling] 140. Kept import/export backup tests as release-gate coverage.
- [x] [Privacy/Support/Insights] 141. Flattened Support out of a card-within-card layout.
- [x] [Privacy/Support/Insights] 142. Added shared support title block.
- [x] [Privacy/Support/Insights] 143. Kept support action rows in shared row styling.
- [x] [Privacy/Support/Insights] 144. Flattened Privacy out of a card-within-card layout.
- [x] [Privacy/Support/Insights] 145. Added shared privacy title block.
- [x] [Privacy/Support/Insights] 146. Added row surfaces for privacy proof rows.
- [x] [Privacy/Support/Insights] 147. Added row surfaces for privacy action rows.
- [x] [Privacy/Support/Insights] 148. Kept destructive privacy action behind confirmation.
- [x] [Privacy/Support/Insights] 149. Hid Insights decorative postcard motif from accessibility.
- [x] [Privacy/Support/Insights] 150. Updated this ExecPlan as the pass ledger.

## Validation and Acceptance

Expected local validation:

    just lint
    uv run pytest
    just test-unit
    just test-ui
    just ci-build

Expected PR validation:

    gh pr checks --watch

Acceptance requires the Timeline tab and scrubber to remain, dark mode to pass contrast tests, widget stale-timer tests to pass, and screenshots to show no clipped root content on Timeline, History, Insights, Settings, Support, or Privacy.

## Outcomes & Retrospective

Local validation completed on 2026-05-08:

- `just lint` passed at the current SwiftLint warning baseline.
- `uv run pytest` passed with 186 tests.
- `just ci-build` passed with Swift compile caching disabled for this Xcode 26 environment.
- `just test-ui` passed with 61 simulator UI tests.
- `just test-unit` passed with 299 Swift unit tests.
- Simulator screenshots for Timeline, History, Insights, Settings, Privacy, Support, and Timeline dark mode were captured under `.build/quality-design-screenshots/` for visual review.
