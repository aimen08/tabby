cask "tabby" do
  # Scripts/release.sh rewrites the version and checksum on every release.
  version "1.0.0"
  sha256 "3c015e1e3e493303958841799fed1d3f2002525a2648c7f83ed34f738e1bc143"

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
