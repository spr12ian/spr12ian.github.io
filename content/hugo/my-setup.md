---
title: "My Setup"
date: 2023-07-28T21:18:15+01:00
draft: true
---
cd ${HOME} or cd ~ depending on your shell. I use cd ~

hugo completion bash > hugo.completion
sudo mv hugo.completion /etc/bash_completion.d/hugo

mkdir projects

cd projects

mkdir spr12ian.github.io

cd spr12ian.github.io

hugo mod init github.com/spr12ian/spr12ian.github.io

hugo mod get -u

hugo mod tidy

hugo mod graph
