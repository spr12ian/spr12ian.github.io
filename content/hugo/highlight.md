---
title: "Highlight"
date: 2023-07-26T12:54:02+01:00
---
This highlighting is not very good:

{{< highlight toml "linenos=inline, hl_lines=1 10-12" >}}
author = "Ian Sweeney"
baseURL = 'https://spr12ian.github.io'
copyright = 'Ian Sweeney'
enableEmoji = true
enableInlineShortcodes = true
ignoreErrors = ["error-remote-getjson"]
languageCode = 'en-GB'
paginate = 10
pluralizelisttitles = false
sectionPagesMenu = 'main'
theme = "beautifulhugo"
title = 'My UK Gadgets & Me'

DefaultContentLanguage = "en"

[taxonomies]
category = "categories"
tag = "tags"
series = "series"

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

{{< /highlight >}}

What's the solution?