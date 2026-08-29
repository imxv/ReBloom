SHELL := /bin/zsh
PROJECT := Adonis.xcodeproj
SCHEME := Adonis
DESTINATION := platform=iOS Simulator,name=iPhone 17 Pro,OS=latest
DERIVED_DATA := .derivedData

.PHONY: project build test sample-regression lint format analyze check clean

project:
	./scripts/xcodegen.sh generate --spec project.yml

build: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) build

test: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test

sample-regression: project
	./scripts/verify_sample_regression.sh
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/SampleRegressionTests \
		-only-testing:AdonisTests/StickerProcessorTests \
		-only-testing:AdonisTests/StickerQualityAssessorTests

lint:
	xcrun swift-format lint --recursive --parallel --strict Adonis AdonisShared AdonisShareExtension AdonisTests AdonisUITests

format:
	xcrun swift-format format --in-place --recursive --parallel Adonis AdonisShared AdonisShareExtension AdonisTests AdonisUITests

analyze: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'generic/platform=iOS' -derivedDataPath $(DERIVED_DATA)-analyze analyze CODE_SIGNING_ALLOWED=NO

check: lint analyze

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA) clean
