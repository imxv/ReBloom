SHELL := /bin/zsh
PROJECT := Adonis.xcodeproj
SCHEME := Adonis
DESTINATION := platform=iOS Simulator,name=iPhone 17 Pro,OS=latest
DERIVED_DATA := .derivedData

.PHONY: project build test sample-regression accessibility-regression permission-regression persistence-regression performance-regression lookbook-regression figurine-regression cabinet-regression seasonal-regression rebloom-regression lint format analyze check clean

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

accessibility-regression: project
	./scripts/verify_accessibility_regression.sh

permission-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/CameraAccessServiceTests \
		-only-testing:AdonisUITests/AdonisFlowUITests/testDeniedCameraPermissionOffersSettingsWithoutOpeningCamera \
		-only-testing:AdonisUITests/AdonisFlowUITests/testRestrictedCameraPermissionKeepsAlbumAlternativeWithoutSettingsShortcut

persistence-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/ModelStorePolicyTests \
		-only-testing:AdonisUITests/AdonisFlowUITests/testCollectedOutfitSurvivesProcessTerminationAndRelaunch

performance-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/GenerationDeadlineControllerTests \
		-only-testing:AdonisTests/ProcessingTraceTests \
		-only-testing:AdonisTests/PersonalDataControlTests/testExportContainsReadableManifestMediaAndPendingSharedImages \
		-only-testing:AdonisUITests/AdonisFlowUITests/testLocalPerformanceTraceShowsBudgetAndStages \
		-only-testing:AdonisUITests/AdonisFlowUITests/testProcessingOverlayKeepsCancelReachable \
		-only-testing:AdonisUITests/AdonisFlowUITests/testHardTimeoutExitsWaitingAndRejectsLateResult \
		-only-testing:AdonisUITests/AdonisFlowUITests/testTimeoutDeliversAndPersistsValidatedBasicStickerFallback

lookbook-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/MonthlyLookbookRendererTests \
		-only-testing:AdonisUITests/AdonisFlowUITests/testSavedOutfitCreatesMonthlyStickerLookbookReadyToShare

figurine-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/DigitalFigurineCardRendererTests \
		-only-testing:AdonisUITests/AdonisFlowUITests/testGeneratedStickerCreatesShareableDigitalFigurineCardWithoutConfiguration \
		-only-testing:AdonisUITests/AdonisFlowUITests/testPreparedSampleCanBeCollectedAndFoundInBloomCalendar

cabinet-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/DigitalCabinetCatalogTests \
		-only-testing:AdonisUITests/AdonisFlowUITests/testSavedOutfitAutomaticallyAppearsInTraceableDigitalCabinet

seasonal-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/SeasonalBloomCatalogTests \
		-only-testing:AdonisUITests/AdonisFlowUITests/testSavedOutfitAutomaticallyBuildsSeasonalBloomArchive

rebloom-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/RebloomCatalogTests \
		-only-testing:AdonisTests/RebloomCardRendererTests \
		-only-testing:AdonisUITests/AdonisFlowUITests/testConfirmedPiecesFromDifferentOutfitsCreateShareableRebloomSuggestion

lint:
	xcrun swift-format lint --recursive --parallel --strict Adonis AdonisShared AdonisShareExtension AdonisTests AdonisUITests

format:
	xcrun swift-format format --in-place --recursive --parallel Adonis AdonisShared AdonisShareExtension AdonisTests AdonisUITests

analyze: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'generic/platform=iOS' -derivedDataPath $(DERIVED_DATA)-analyze analyze CODE_SIGNING_ALLOWED=NO

check: lint analyze

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA) clean
