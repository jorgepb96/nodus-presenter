# App Store assets — 0.2.0

Store name: **Nodus Presenter**. Nodus Research is the companion desktop application. Build 9 also pairs with its Windows/Linux Presenter integration on the same local network; the Mac connection retains its existing implementation.

`Metadata` contains descriptions, subtitles, promotional text, keywords and release notes for en-US, es-ES, fr-FR, de-DE, it, pt-PT, ja, zh-Hans and zh-Hant. Fields were checked against App Store Connect character limits. The initial App Store submission has no “What's New” field; these files are retained for subsequent releases.

The fourteen store screenshots are **in English** and show the actual local demo of build 5. Build 8 updates the small header logo and welcome mark; separate native brand validation captures are available in `Screenshots/Brand`. No composited device frames or generated interface mockups are used.

| Set | Device and runtime | Pixels |
| --- | --- | --- |
| `Screenshots/en-US/iphone-6.9` | iPhone 16 Pro Max, iOS 26.3 | 1320 × 2868 |
| `Screenshots/en-US/ipad-13` | iPad Pro 13-inch (M5), iPadOS 26.3 | 2752 × 2064 |

The seven screens cover notes, drawing/next-slide preview, video controls, Mac volume, layout/colors, the slide grid and QR pairing. Use filename order so the presenter workspace is shown first. Other store languages may inherit these English images.

Captures are reproducible with `StoreScreenshotTests/testEnglishStoreScreenshots`. The test selects English by launch arguments, resets app preferences, rotates iPad before launch and exports the complete display as an opaque PNG with normalized orientation. The screenshot test is explicitly selected; it is not needed for routine unit-test runs.

The video on demo slide 4 and the volume changes are simulated. Real playback and volume changes occur on the paired Mac, and the controls are hidden for slides without a video and while reading privately.

App Store Connect status, 1 October 2026: all nine descriptions and subtitles are saved under **Nodus Presenter**, and build **0.2.0 (8)** remains associated with the public draft. Build **0.2.0 (9)** is available in the existing internal TestFlight group with Windows/Linux testing instructions. The public draft's Mac-focused descriptions will need updating alongside release of the desktop integration. Seven iPhone and seven iPad images have finished uploading. One additional, obsolete iPhone screenshot reservation remains stuck processing; its replacement has uploaded successfully, but Apple's UI currently exposes no removal control for the unfinished reservation. The public listing has not been submitted for review.

Apple reference: [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
