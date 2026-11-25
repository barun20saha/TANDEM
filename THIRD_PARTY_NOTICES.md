# Third-Party Notices and Licences

This project incorporates open-source software and font resources. This document records all dependencies, their source locations, and their respective licences in compliance with Section 2.3 of the Tandem Agent Guide.

---

## 1. Syncthing Core Engine

- **Project:** Syncthing
- **Pinned Version:** `v2.1.7` (`https://github.com/syncthing/syncthing/releases/tag/v2.1.7`)
- **Repository:** https://github.com/syncthing/syncthing
- **Licence:** Mozilla Public License 2.0 (MPL-2.0)
- **Role in Tandem:** Sync engine, Block Exchange Protocol (BEP v1), local/global discovery, TLS mutual authentication, relay protocol.
- **Pinned SHA-256 Checksums (`v2.1.7`):**
  - `syncthing-linux-amd64-v2.1.7.tar.gz`: `2edc416e7ed136b7c858ed5f3f02a3b8316589605e54c380228ceea7acbf0142`
  - `syncthing-linux-arm64-v2.1.7.tar.gz`: `48e456690cd2b97e7d26b02b5ac35f62a3b36172267b144cfeaf02c993ab955c`
  - `syncthing-macos-universal-v2.1.7.zip`: `a98fb709c79412e5586c81a1586bfb256b6e5a97b067ddf7447155bcdf6aac3f`
  - `syncthing-windows-amd64-v2.1.7.zip`: `3ce7da770f546a8d02b65b2e7ee31f2a3b8b7c3f990ede045590cca4172ecfe1`
  - `syncthing-windows-arm64-v2.1.7.zip`: `d535ffd611b3af223de64bc5dfc60c378881eb13d5c8ecb1431b7407094c15ff`
- **Compliance Notes:**
  - Modified Syncthing source files must remain under MPL-2.0 and be made available. Tandem distributes Syncthing `v2.1.7` unmodified.
  - Tandem's own logic, Platform Abstraction Layer (PAL), Link Manager, and UI reside in separate files and packages.
  - Integration is managed via isolated subprocess supervision and loopback REST/Event APIs.

---

## 2. Plexo (Design & Multipath Concept)

- **Project:** Plexo
- **Repository:** https://github.com/anmolkapil/plexo
- **Licence:** MIT License
- **Role in Tandem:** Conceptual architecture for block-level multipath scheduling, interface accounting, and resilient resume.
- **Compliance Notes:** Plexo is an architectural and conceptual reference. Any direct logic adapted into `core/multipath` maintains the original copyright notice and MIT licence text.

---

## 3. Fonts

### Familjen Grotesk
- **Source:** Familjen STHLM / Google Fonts
- **Licence:** SIL Open Font License 1.1 (OFL-1.1)
- **Use:** Headings and screen titles.

### Atkinson Hyperlegible Next
- **Source:** Braille Institute / Applied Design Works
- **Licence:** SIL Open Font License 1.1 (OFL-1.1)
- **Use:** Body text, UI controls, labels, and tabular figures.
