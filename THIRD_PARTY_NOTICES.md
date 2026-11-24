# Third-Party Notices and Licences

This project incorporates open-source software and font resources. This document records all dependencies, their source locations, and their respective licences in compliance with Section 2.3 of the Tandem Agent Guide.

---

## 1. Syncthing Core Engine

- **Project:** Syncthing
- **Repository:** https://github.com/syncthing/syncthing
- **Licence:** Mozilla Public License 2.0 (MPL-2.0)
- **Role in Tandem:** Sync engine, Block Exchange Protocol (BEP v1), local/global discovery, TLS mutual authentication, relay protocol.
- **Compliance Notes:**
  - Modified Syncthing source files must remain under MPL-2.0 and be made available.
  - Tandem's own logic, Platform Abstraction Layer (PAL), Link Manager, and UI reside in separate files and packages.
  - Integration is managed via isolated interfaces and the localhost REST/Event APIs to prevent unlicensed code entanglement.

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
