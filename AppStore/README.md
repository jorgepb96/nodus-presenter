# App Store assets — 0.2.0

Store name: **Nodus Presenter**. Nodus Research is the companion desktop application. Build 9 also pairs with its Windows/Linux Presenter integration on the same local network; the Mac connection retains its existing implementation.

`Metadata` contains descriptions, subtitles, promotional text, keywords and release notes for en-US, es-ES, fr-FR, de-DE, it, pt-PT, ja, zh-Hans and zh-Hant. All descriptions now cover Mac, Windows and Linux, their connection requirements, and platform-specific volume behavior. Fields were checked against App Store Connect character limits. The initial App Store submission has no “What's New” field; these files are retained for subsequent releases. `reviewNotes.txt` contains the English instructions prepared for Apple's reviewers.

The fourteen store screenshots are **in English** and show the actual local demo of build 5. Build 8 updates the small header logo and welcome mark; separate native brand validation captures are available in `Screenshots/Brand`. No composited device frames or generated interface mockups are used.

| Set | Device and runtime | Pixels |
| --- | --- | --- |
| `Screenshots/en-US/iphone-6.9` | iPhone 16 Pro Max, iOS 26.3 | 1320 × 2868 |
| `Screenshots/en-US/ipad-13` | iPad Pro 13-inch (M5), iPadOS 26.3 | 2752 × 2064 |

The seven screens cover notes, drawing/next-slide preview, video controls, Mac volume, layout/colors, the slide grid and QR pairing. The owner reordered the iPhone and iPad screenshots directly in App Store Connect; preserve that order. Other store languages may inherit these English images.

Captures are reproducible with `StoreScreenshotTests/testEnglishStoreScreenshots`. The test selects English by launch arguments, resets app preferences, rotates iPad before launch and exports the complete display as an opaque PNG with normalized orientation. The screenshot test is explicitly selected; it is not needed for routine unit-test runs.

The video on demo slide 4 and the volume changes are simulated. Real playback occurs on the paired computer. Mac volume controls system output; Windows/Linux volume controls the presentation video. Controls are hidden for slides without a video and while reading privately.

App Store Connect status, 1 October 2026: the listing remains **Nodus Presenter**. Price is zero in all 175 regions, availability is configured, age rating is 4+, and the authorized **Data Not Collected** privacy declaration is published. The free-app agreement is already active. Build **0.2.0 (9)** is available in the existing internal TestFlight group and has been selected in the public-version form, replacing build 8. The nine updated descriptions, review notes and automatic release after approval are prepared in that form. Apple prevents saving the version while its review-contact name, surname, phone and email remain empty. These version-form changes are therefore pending the owner's completion and Save; they are not yet a submitted release. The account's DSA trader declaration is also pending for EU distribution. Both owner forms have been left open in the integrated browser.

Seven iPhone and seven iPad images finished uploading previously. An additional obsolete iPhone screenshot reservation was previously stuck processing. Screenshot assets and order were preserved during publication preparation; final submission validation must verify Apple's processing state.

The mobile privacy policy is publicly available at an immutable URL and configured in the primary store locale: [Nodus Presenter Privacy Policy](https://github.com/Drakonis96/nodus/blob/f819944066a2582347e44ff0e4f5f69105367c0d/PRESENTER_PRIVACY.md). Its addition to the desktop repository is tracked in [PR 1032](https://github.com/Drakonis96/nodus/pull/1032).

Apple reference: [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
