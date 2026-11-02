cask "tabby" do
  # Scripts/release.sh rewrites the version and checksum on every release.
  version "1.0.4"
  sha256 "8238f4173627e21be7e7500d0ea7b541f674c29925131f6a18118291e4dff6c8"

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
