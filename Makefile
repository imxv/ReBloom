SHELL := /bin/zsh
PROJECT := Adonis.xcodeproj
SCHEME := Adonis
DESTINATION := platform=iOS Simulator,name=iPhone 17 Pro,OS=latest
DERIVED_DATA := .derivedData

.PHONY: project build test sample-regression accessibility-regression permission-regression photo-save-regression persistence-regression wardrobe-visual-regression input-routing-regression performance-regression lookbook-regression figurine-regression cabinet-regression seasonal-regression rebloom-regression rebloom-reminder-regression creative-regression tryon-regression lint format analyze check clean

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
		-only-testing:AdonisTests/StickerMatteRefinerTests \
		-only-testing:AdonisTests/StickerProcessorTests \
		-only-testing:AdonisTests/RawMatteQualityAssessorTests \
		-only-testing:AdonisTests/StickerSourceFidelityAssessorTests \
		-only-testing:AdonisTests/StickerQualityAssessorTests

accessibility-regression: project
	./scripts/verify_accessibility_regression.sh

permission-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/CameraAccessServiceTests \
		-only-testing:AdonisUITests/AdonisFlowUITests/testDeniedCameraPermissionOffersSettingsWithoutOpeningCamera \
		-only-testing:AdonisUITests/AdonisFlowUITests/testRestrictedCameraPermissionKeepsAlbumAlternativeWithoutSettingsShortcut

photo-save-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/PhotoLibrarySaverTests \
		-only-testing:AdonisUITests/AdonisFlowUITests/testPreparedStickerCanBeSavedToPhotosWithoutLeavingResult \
		-only-testing:AdonisUITests/AdonisFlowUITests/testDeniedPhotoSaveOffersStickerShareWithoutLosingResult

persistence-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/ModelStorePolicyTests \
		-only-testing:AdonisUITests/AdonisFlowUITests/testCollectedOutfitSurvivesProcessTerminationAndRelaunch

wardrobe-visual-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/GarmentVisualSignatureTests \
		-only-testing:AdonisTests/WardrobeCandidateMatcherTests \
		-only-testing:AdonisTests/WardrobeVisualSignatureBackfillServiceTests \
		-only-testing:AdonisTests/WardrobeImageAnalyzerTests \
		-only-testing:AdonisTests/OutfitGarmentObserverTests \
		-only-testing:AdonisTests/PersonalDataControlTests/testExportContainsReadableManifestMediaAndPendingSharedImages \
		-only-testing:AdonisUITests/AdonisFlowUITests/testOutfitCluesStayProvisionalUntilOneTapConfirmation

input-routing-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/CreationImageIntentRouterTests \
		-only-testing:AdonisTests/WardrobeImageAnalyzerTests \
		-only-testing:AdonisUITests/AdonisFlowUITests/testCreateInputAutomaticallyRoutesHighConfidenceCatalogGarmentToWardrobe \
		-only-testing:AdonisUITests/AdonisFlowUITests/testAmbiguousCatalogImageAsksBeforeSavingAfterStickerFailure

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

rebloom-reminder-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/RebloomReminderServiceTests \
		-only-testing:AdonisTests/PersonalDataControlTests/testDeleteAllClearsModelsMediaSharedInboxAndTemporaryExports \
		-only-testing:AdonisUITests/AdonisFlowUITests/testConfirmedPiecesFromDifferentOutfitsCreateShareableRebloomSuggestion

creative-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/CreativeExecutionMetadataTests \
		-only-testing:AdonisTests/CreativeRecipeTests \
		-only-testing:AdonisTests/BotanicalPosterRendererTests \
		-only-testing:AdonisTests/MythicGardenCardRendererTests \
		-only-testing:AdonisTests/CreativeWorkPersistenceTests \
		-only-testing:AdonisTests/PersonalDataControlTests/testExportContainsReadableManifestMediaAndPendingSharedImages \
		-only-testing:AdonisTests/PersonalDataControlTests/testDeleteAllClearsModelsMediaSharedInboxAndTemporaryExports \
		-only-testing:AdonisUITests/AdonisFlowUITests/testGeneratedStickerCreatesTraceableBotanicalPosterReadyToCompareSaveAndShare \
		-only-testing:AdonisUITests/AdonisFlowUITests/testUnavailableSystemCreationDoesNotShowADeadEntry \
		-only-testing:AdonisUITests/AdonisFlowUITests/testCuratedStyleGardenSelectsPersistsAndReopensFloralSketch \
		-only-testing:AdonisUITests/AdonisFlowUITests/testAvailableSystemCreationBuildsReviewableMythicGardenAndPersistsIt \
		-only-testing:AdonisUITests/AdonisFlowUITests/testSystemCreationCanBeCancelledWithoutChangingOriginalResult \
		-only-testing:AdonisUITests/AdonisFlowUITests/testSystemCreationTimeoutStopsWaitingAndKeepsOriginalResult

tryon-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:AdonisTests/StickerTryOnRendererTests \
		-only-testing:AdonisTests/CreativeExecutionMetadataTests/testStickerTryOnTraceIsLocalZeroRequestAndRequiresVisualReview \
		-only-testing:AdonisTests/CreativeRecipeTests/testStickerTryOnIsAOneTapLocalCompositionWithExplicitFitBoundary \
		-only-testing:AdonisTests/CreativeWorkPersistenceTests \
		-only-testing:AdonisTests/PersonalDataControlTests/testExportContainsReadableManifestMediaAndPendingSharedImages \
		-only-testing:AdonisUITests/AdonisFlowUITests/testCatalogTopCanCreateReviewSaveShareAndReopenStickerTryOn \
		-only-testing:AdonisUITests/AdonisFlowUITests/testStickerTryOnQualityGateStopsBadResultWithoutCreatingAWork \
		-only-testing:AdonisUITests/AdonisFlowUITests/testStickerTryOnCanBeStoppedWithoutOpeningOrChangingAWork

lint:
	xcrun swift-format lint --recursive --parallel --strict Adonis AdonisShared AdonisShareExtension AdonisTests AdonisUITests

format:
	xcrun swift-format format --in-place --recursive --parallel Adonis AdonisShared AdonisShareExtension AdonisTests AdonisUITests

analyze: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'generic/platform=iOS' -derivedDataPath $(DERIVED_DATA)-analyze analyze CODE_SIGNING_ALLOWED=NO

check: lint analyze

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA) clean
