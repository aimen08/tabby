cask "tabby" do
  # Scripts/release.sh rewrites the version and checksum on every release.
  version "1.0.1"
  sha256 "ea3cfc1f93c30fc6eb94c6db5eb69a51a60d50a33ab0f1cd4771f7af8e063d7c"

  url "https://github.com/aimen08/tabby/releases/download/v#{version}/Tabby.dmg"
  name "Tabby"
  desc "Minimal Option-Tab app switcher with window previews"
  homepage "https://aimen08.github.io/tabby/"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "Tabby.app"

  zap trash: [
    "~/Library/Caches/com.aimen.tabby",
    "~/Library/HTTPStorages/com.aimen.tabby",
    "~/Library/Preferences/com.aimen.tabby.plist",
  ]
end
