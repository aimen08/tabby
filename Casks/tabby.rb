cask "tabby" do
  # Scripts/release.sh rewrites the version and checksum on every release.
  version "1.0.2"
  sha256 "26630637e8a0b171410e516e09892b2e4c7f478a1bf4cf342fe019c88ec7925e"

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
