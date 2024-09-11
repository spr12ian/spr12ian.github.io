---
title: "hugo.toml"
date: 2023-07-25T22:36:32+01:00
---

As at 2023-07-30 my hugo.toml file looks like:

```toml
author = "Ian Sweeney"
baseURL = 'https://spr12ian.github.io'
copyright = 'Ian Sweeney'
enableEmoji = true
enableInlineShortcodes = true
ignoreErrors = ["error-remote-getjson"]
languageCode = 'en-GB'
pluralizelisttitles = false
sectionPagesMenu = 'main'
theme = "beautifulhugo"
title = 'My UK Gadgets & Me'

DefaultContentLanguage = "en"

[taxonomies]
category = "categories"
tag = "tags"
series = "series"

[pagination]
pagerSize = 10

[privacy]

[privacy.vimeo]
disabled = false
simple = true

[privacy.twitter]
disabled = false
enableDNT = true
simple = true

[privacy.instagram]
disabled = false
simple = true

[privacy.youtube]
disabled = false
privacyEnhanced = true

[services]

[services.instagram]
disableInlineCSS = true

[services.twitter]
disableInlineCSS = true

```