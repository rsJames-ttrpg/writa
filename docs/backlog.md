# Backlog

Tracked tech-debt and not-yet-done items that don't fit a single spec.

## Make `project_roots` configurable

`lua/plugins/writing/projects/init.lua` hardcodes the discovery root for `:WritaOpenProject` to `{ "~/writing" }`. Should be exposed via plugin opts so users can scan additional roots (e.g., `~/Documents/writing`, network drives).

Sketch:
- Accept `opts.project_roots` on the plugin spec
- Default to `{ "~/writing" }` if unset
- Pass through to `open.run(...)`

Touches: `lua/plugins/writing/projects/init.lua`. Update `docs/projects.md` "Discovery" + "Limitations" sections once shipped.
