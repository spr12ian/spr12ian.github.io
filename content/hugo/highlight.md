---
title: "Highlight"
date: 2023-07-26T12:54:02+01:00
draft: true
---
This highlighting is not very good:

{{< highlight toml "linenos=inline, hl_lines=1 10-12" >}}
baseURL = 'https://spr12ian.github.io/'
languageCode = 'en-GB'
paginate = 100
sectionPagesMenu = 'main'
theme = ["github.com/halogenica/beautifulhugo"]
title = 'My UK Gadgets & Me'

[params]

ShowPostNavLinks = true
ShowBreadCrumbs = true
ShowToc = true
{{< /highlight >}}
