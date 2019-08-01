workflow "Deploy to gh-pages" {
  on = "push"
  resolves = ["Publish to gh-pages"]
}

action "Checkout submodules" {
  uses = "srt32/git-actions@v0.0.3"
  args = "git submodule update --init --recursive"
}

action "Publish to gh-pages" {
  uses = "nelsonjchen/gh-pages-pelican-action@0.1.4"
  needs = ["Checkout submodules"]
  secrets = ["GIT_DEPLOY_KEY"]
  env = {
    GH_PAGES_BRANCH = "master"
    PELICAN_CONFIG_FILE = "publishconf.py"
  }
}
