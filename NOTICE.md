# Notice

pdf-sign-linux, copyright 2026 Ivan Pinatti, licensed under the Apache
License, Version 2.0. See [LICENSE.md](LICENSE.md) for the full terms.

## Third-party software

This repository ships no third-party software. The container image is built
on each user's own machine, and that build downloads and installs:

- Adobe Reader XI, from Adobe, under Adobe's licence agreement for Reader,
  which the user accepts before building. It does not permit redistribution,
  so a built image must not be published.
- Microsoft's core fonts, through Debian's `ttf-mscorefonts-installer`,
  under Microsoft's core fonts EULA, which the user accepts before building.
- Debian packages (Wine, Xwayland, CUPS, Ghostscript, qpdf and others) under
  their own licences, from Debian's archive.

Adobe, Acrobat and Reader are trademarks of Adobe. Microsoft and Arial are
trademarks of their respective owners. This project is not affiliated with
or endorsed by Adobe or Microsoft.
