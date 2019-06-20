workflow "Deploy to gh-pages" {
  on = "push"
  resolves = ["Publish to gh-pages"]
}

action "Checkout submodules" {
  uses = "srt32/git-actions@v0.0.3"
  args = "git submodule update --init --recursive"
}

action "Publish to gh-pages" {
  uses = "nelsonjchen/gh-pages-pelican-action@adad1db8a5a48fe1c9ffd88ce96e2225af8fa860"
  needs = ["Checkout submodules"]
  secrets = ["GIT_DEPLOY_KEY"]
  env = {
    GH_PAGES_BRANCH = "master"
  }
}
