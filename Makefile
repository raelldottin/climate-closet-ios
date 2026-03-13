PROJECT := ClimateCloset.xcodeproj
SCHEME := ClimateCloset
DESTINATION ?= platform=iOS Simulator,name=iPhone 16

.PHONY: bootstrap verify-layout lint-python lint-swift test ci

bootstrap:
	python3 -m venv .venv
	. .venv/bin/activate && python -m pip install --upgrade pip && python -m pip install -r requirements-dev.txt

verify-layout:
	@if [ -x .venv/bin/python ]; then .venv/bin/python scripts/verify_repo_layout.py; else python3 scripts/verify_repo_layout.py; fi

lint-python:
	@if [ -x .venv/bin/python ]; then .venv/bin/python -m pyright; else python3 -m pyright; fi

lint-swift:
	swift format lint --recursive ClimateCloset ClimateClosetTests ClimateClosetIntegrationTests --strict

test:
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' CODE_SIGNING_ALLOWED=NO

ci: verify-layout lint-python lint-swift test

