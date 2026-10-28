cask "tabby" do
  # Scripts/release.sh rewrites the version and checksum on every release.
  version "1.0.3"
  sha256 "6d3c72514fdfc126bb5e114241bb53bd0abb400845dc48fa71af82b7e4860116"

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
