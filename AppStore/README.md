# App Store assets — 0.2.0

Store name: **Nodus Presenter**. Nodus Research is the companion desktop application. Build 9 also pairs with its Windows/Linux Presenter integration on the same local network. Build 11 improves iOS-side Mac discovery/TLS startup and resource recovery; the desktop Mac helper and TLS-PSK protocol remain unchanged.

`Metadata` contains descriptions, subtitles, promotional text, keywords and release notes for en-US, es-ES, fr-FR, de-DE, it, pt-PT, ja, zh-Hans and zh-Hant. All descriptions now cover Mac, Windows and Linux, their connection requirements, and platform-specific volume behavior. Fields were checked against App Store Connect character limits. The initial App Store submission has no “What's New” field; these files are retained for subsequent releases. `reviewNotes.txt` contains the English instructions prepared for Apple's reviewers.

The fourteen store screenshots are **in English** and show the actual local demo of build 5. Build 8 updates the small header logo and welcome mark; separate native brand validation captures are available in `Screenshots/Brand`. No composited device frames or generated interface mockups are used.

| Set | Device and runtime | Pixels |
| --- | --- | --- |
| `Screenshots/en-US/iphone-6.9` | iPhone 16 Pro Max, iOS 26.3 | 1320 × 2868 |
| `Screenshots/en-US/ipad-13` | iPad Pro 13-inch (M5), iPadOS 26.3 | 2752 × 2064 |

The seven screens cover notes, drawing/next-slide preview, video controls, Mac volume, layout/colors, the slide grid and QR pairing. The owner reordered the iPhone and iPad screenshots directly in App Store Connect; preserve that order. Other store languages may inherit these English images.

Captures are reproducible with `StoreScreenshotTests/testEnglishStoreScreenshots`. The test selects English by launch arguments, resets app preferences, rotates iPad before launch and exports the complete display as an opaque PNG with normalized orientation. The screenshot test is explicitly selected; it is not needed for routine unit-test runs.

The video on demo slide 4 and the volume changes are simulated. Real playback occurs on the paired computer. Mac volume controls system output; Windows/Linux volume controls the presentation video. Controls are hidden for slides without a video and while reading privately.

App Store Connect status, 2 October 2026: the listing remains **Nodus Presenter**. Price is zero in all 175 regions, availability is configured, age rating is 4+, and the authorized **Data Not Collected** privacy declaration is published. The free-app agreement is active. The owner completed and saved the review-contact details and the DSA non-trader declaration. All nine store descriptions, English review instructions and automatic release after approval are saved. The requested opening slogan was removed from the Spanish description.

Build **0.2.0 (10)** was signed, archived and successfully uploaded on 2 October 2026. It adds a localized privacy-policy link to the welcome screen and Settings → About. It passed all 12 core tests, including resource coverage for all nine languages. The link was checked on iPhone 16 Pro Max with iOS 26.3 and opens the published policy. App Store Connect now shows build 10 **In Testing** in the existing internal group. Version **0.2.0 (10)** was submitted to App Review on 2 October 2026 at 00:39 Europe/Madrid and is **Waiting for Review**. There are no remaining draft submissions. Publication remains automatic after Apple approval; the app is not yet publicly available.

Apple subsequently requested additional information and a physical-device recording under Guideline 2.1. Build **0.2.0 (11)** was signed and uploaded on 2 October at 10:28 Europe/Madrid, processed and assigned to the existing internal TestFlight group with Spanish testing instructions. It passed 13 Core tests, four hosted iOS TLS recovery tests, selected UI regressions and CI; the desktop helper remains compatible. The public submission still uses build 10. Physical Mac/iPhone and iPad validation and the requested recording must be completed before declaring the replacement ready for App Review.

Seven iPhone and seven iPad images are complete. The obsolete unuploaded duplicate iPhone reservation was removed through Apple's official API using the existing Apple key in GitHub Actions. Verification compared screenshot IDs before and after and confirmed that all valid images and their exact order, including the iPad set, were preserved. No new API key was created. The temporary maintenance branch was removed and no release workflow change was merged.

The mobile policy is published at [Nodus Presenter Privacy Policy](https://nodusresearch.com/presenter/privacy/). This URL is saved in all nine store localizations. [PR 1032](https://github.com/Drakonis96/nodus/pull/1032) is merged and its GitHub Pages deployment succeeded. The policy explains encrypted local pairing, camera processing, session data and seven-day startup cleanup of cached PDFs. The website has a separate privacy notice.

Apple reference: [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

Submission evidence: [App Review confirmation](https://appstoreconnect.apple.com/apps/6818107823/distribution/reviewsubmissions/details/ad05be10-bbcc-4ca9-97f6-f6973ab5d214). The private review contact is saved in App Store Connect and is not stored in this repository.
