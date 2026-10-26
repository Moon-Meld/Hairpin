.PHONY: build release run clean dmg install uninstall

# ── Default target ──
build:
	@bash build_app.sh

# ── Release build ──
release:
	@bash build_app.sh release

# ── Run the app ──
run: build
	@open build/Hairpin.app

# ── Create DMG installer ──
dmg:
	@bash build_app.sh dmg

# ── Install to /Applications ──
install: release
	@echo "  📦  Installing to /Applications..."
	@cp -R build/Hairpin.app /Applications/
	@echo "  ✅  Installed."

# ── Uninstall ──
uninstall:
	@echo "  🗑   Removing from /Applications..."
	@rm -rf /Applications/Hairpin.app
	@defaults delete com.hairpin.app 2>/dev/null || true
	@echo "  ✅  Uninstalled."

# ── Clean build artifacts ──
clean:
	@echo "  🧹  Cleaning..."
	@swift package clean
	@rm -rf build/ .build/
	@echo "  ✅  Clean."
