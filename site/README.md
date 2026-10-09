# Tendr site

Public privacy policy and support pages for the App Store listing, served by GitHub Pages:

- https://0x63616c.github.io/tendr/privacy/
- https://0x63616c.github.io/tendr/support/

Plain HTML and CSS, styled from the app's `Theme` in `Still/StillApp.swift` (palette, card radius 24, graphite accent, teal for Health). Light and dark follow `prefers-color-scheme`.

Edit files here, then run `scripts/publish-site.sh` to copy `site/` to the `gh-pages` branch. Only this folder is published, so `docs/` stays private.
