---
title: Contact
featured_image: '/images/contact.jpg'
omit_header_text: true
description: I'd love to hear from you
type: page
menu: main
draft: true
---

How do forms work in Hugo?

Is the custom shortcode 'form-contact' anake specific?

This is an example of a custom shortcode that you can put right into your content. You will need to add a form action to the shortcode to make it work. Check out [Formspree](https://formspree.io/) for a simple, free form service. 

Fix these braces
{{< highlight toml "linenos=inline" >}}
{ {< form-contact action="https://example.com"  >}}
{{< /highlight >}}