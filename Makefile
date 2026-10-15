SHELL := /bin/zsh
PROJECT := ReBloom.xcodeproj
SCHEME := ReBloom
DESTINATION := platform=iOS Simulator,name=iPhone 17 Pro,OS=latest
DERIVED_DATA := .derivedData

.PHONY: project build test server-test sample-regression ai-sticker-regression ai-sticker-visual-regression legacy-provider-isolation accessibility-regression permission-regression photo-save-regression persistence-regression wardrobe-visual-regression input-routing-regression performance-regression lookbook-regression figurine-regression cabinet-regression seasonal-regression rebloom-regression rebloom-reminder-regression creative-regression tryon-regression lint format analyze check clean

project:
	./scripts/xcodegen.sh generate --spec project.yml

build: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) build

test: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test

server-test:
	npm --prefix server test

sample-regression: project
	./scripts/verify_sample_regression.sh
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/SampleRegressionTests \
		-only-testing:ReBloomTests/StickerMatteRefinerTests \
		-only-testing:ReBloomTests/StickerProcessorTests \
		-only-testing:ReBloomTests/RawMatteQualityAssessorTests \
		-only-testing:ReBloomTests/StickerSourceFidelityAssessorTests \
		-only-testing:ReBloomTests/StickerQualityAssessorTests

ai-sticker-regression: project
	npm --prefix server test
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/AIStickerCreationPipelineTests \
		-only-testing:ReBloomTests/AIStickerCloudExtractionClientTests \
		-only-testing:ReBloomTests/AITransparentStickerProcessorTests \
		-only-testing:ReBloomTests/StickerFidelityReviewTests \
		-only-testing:ReBloomTests/CreativeExecutionMetadataTests/testAppleSystemSheetHasDistinctTraceAndKeepsSystemBoundaryHonest \
		-only-testing:ReBloomTests/CreativeExecutionMetadataTests/testTwoPassStickerMetadataKeepsSourceAndTransparentEditProvidersDistinct \
		-only-testing:ReBloomTests/CreativeExecutionMetadataTests/testOlderExecutionMetadataStillDecodesWithoutTwoPassProviderFields \
		-only-testing:ReBloomTests/CreativeExecutionMetadataTests/testCreativeGenerationErrorsUseStableCodesAndPlainRecoveryCopy \
		-only-testing:ReBloomTests/ProcessingTraceTests/testAIStickerGenerationStageAndProviderMetadataSurviveEventPersistence \
		-only-testing:ReBloomTests/ShareCardRendererTests/testProvenanceFooterDisclosesAIGeneratedStickerPixels \
		-only-testing:ReBloomTests/PersonalDataControlTests/testExportContainsReadableManifestMediaAndPendingSharedImages \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testMainCreationGeneratesAIStickerSourceBeforeTransparentStickerAndPersistsIt \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testCancellingSystemImagePlaygroundNeverSendsOriginalToTransparentStage \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testAIStickerFidelityReviewPersistsFromResultIntoHistory \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testHomepageAISampleKeepsAIProvenanceAfterOpeningResult \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testAmbiguousInputDoesNotBypassUnavailableAIStickerGeneration \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testUnavailableAIStickerOffersAnHonestPreparedSampleRecovery

ai-sticker-visual-regression:
	ruby scripts/verify_ai_sticker_visual_experiment.rb

legacy-provider-isolation: project
	./scripts/verify_legacy_image_creator_isolation.sh

accessibility-regression: project
	./scripts/verify_accessibility_regression.sh

permission-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/CameraAccessServiceTests \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testDeniedCameraPermissionOffersSettingsWithoutOpeningCamera \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testRestrictedCameraPermissionKeepsAlbumAlternativeWithoutSettingsShortcut

photo-save-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/PhotoLibrarySaverTests \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testPreparedStickerCanBeSavedToPhotosWithoutLeavingResult \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testDeniedPhotoSaveOffersStickerShareWithoutLosingResult

persistence-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/ModelStorePolicyTests \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testCollectedOutfitSurvivesProcessTerminationAndRelaunch

wardrobe-visual-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/GarmentVisualSignatureTests \
		-only-testing:ReBloomTests/WardrobeCandidateMatcherTests \
		-only-testing:ReBloomTests/WardrobeVisualSignatureBackfillServiceTests \
		-only-testing:ReBloomTests/WardrobeImageAnalyzerTests \
		-only-testing:ReBloomTests/OutfitGarmentObserverTests \
		-only-testing:ReBloomTests/PersonalDataControlTests/testExportContainsReadableManifestMediaAndPendingSharedImages \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testOutfitCluesStayProvisionalUntilOneTapConfirmation

input-routing-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/CreationImageIntentRouterTests \
		-only-testing:ReBloomTests/WardrobeImageAnalyzerTests \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testCreateInputAutomaticallyRoutesHighConfidenceCatalogGarmentToWardrobe \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testAmbiguousInputDoesNotBypassUnavailableAIStickerGeneration

performance-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/GenerationDeadlineControllerTests \
		-only-testing:ReBloomTests/ProcessingTraceTests \
		-only-testing:ReBloomTests/PersonalDataControlTests/testExportContainsReadableManifestMediaAndPendingSharedImages \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testLocalPerformanceTraceShowsBudgetAndStages \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testProcessingOverlayKeepsCancelReachable \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testHardTimeoutExitsWaitingAndRejectsLateResult \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testTimeoutDeliversAndPersistsValidatedBasicStickerFallback

lookbook-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/MonthlyLookbookRendererTests \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testSavedOutfitCreatesMonthlyStickerLookbookReadyToShare

figurine-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/DigitalFigurineCardRendererTests \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testGeneratedStickerCreatesShareableDigitalFigurineCardWithoutConfiguration \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testPreparedSampleCanBeCollectedAndFoundInBloomCalendar

cabinet-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/DigitalCabinetCatalogTests \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testSavedOutfitAutomaticallyAppearsInTraceableDigitalCabinet

seasonal-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/SeasonalBloomCatalogTests \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testSavedOutfitAutomaticallyBuildsSeasonalBloomArchive

rebloom-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/RebloomCatalogTests \
		-only-testing:ReBloomTests/RebloomCardRendererTests \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testConfirmedPiecesFromDifferentOutfitsCreateShareableRebloomSuggestion

rebloom-reminder-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/RebloomReminderServiceTests \
		-only-testing:ReBloomTests/PersonalDataControlTests/testDeleteAllClearsModelsMediaSharedInboxAndTemporaryExports \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testConfirmedPiecesFromDifferentOutfitsCreateShareableRebloomSuggestion

creative-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/CreativeExecutionMetadataTests \
		-only-testing:ReBloomTests/CreativeRecipeTests \
		-only-testing:ReBloomTests/BotanicalPosterRendererTests \
		-only-testing:ReBloomTests/MythicGardenCardRendererTests \
		-only-testing:ReBloomTests/CreativeWorkPersistenceTests \
		-only-testing:ReBloomTests/PersonalDataControlTests/testExportContainsReadableManifestMediaAndPendingSharedImages \
		-only-testing:ReBloomTests/PersonalDataControlTests/testDeleteAllClearsModelsMediaSharedInboxAndTemporaryExports \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testGeneratedStickerCreatesTraceableBotanicalPosterReadyToCompareSaveAndShare \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testUnavailableSystemCreationDoesNotShowADeadEntry \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testCuratedStyleGardenSelectsPersistsAndReopensFloralSketch \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testAvailableSystemCreationBuildsReviewableMythicGardenAndPersistsIt \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testSystemCreationCanBeCancelledWithoutChangingOriginalResult \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testSystemCreationTimeoutStopsWaitingAndKeepsOriginalResult

tryon-regression: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test \
		-only-testing:ReBloomTests/StickerTryOnRendererTests \
		-only-testing:ReBloomTests/CreativeExecutionMetadataTests/testStickerTryOnTraceIsLocalZeroRequestAndRequiresVisualReview \
		-only-testing:ReBloomTests/CreativeRecipeTests/testStickerTryOnIsAOneTapLocalCompositionWithExplicitFitBoundary \
		-only-testing:ReBloomTests/CreativeWorkPersistenceTests \
		-only-testing:ReBloomTests/PersonalDataControlTests/testExportContainsReadableManifestMediaAndPendingSharedImages \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testCatalogTopCanCreateReviewSaveShareAndReopenStickerTryOn \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testStickerTryOnQualityGateStopsBadResultWithoutCreatingAWork \
		-only-testing:ReBloomUITests/AdonisFlowUITests/testStickerTryOnCanBeStoppedWithoutOpeningOrChangingAWork

lint:
	xcrun swift-format lint --recursive --parallel --strict ReBloom ReBloomShared ReBloomShareExtension ReBloomTests ReBloomUITests

format:
	xcrun swift-format format --in-place --recursive --parallel ReBloom ReBloomShared ReBloomShareExtension ReBloomTests ReBloomUITests

analyze: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'generic/platform=iOS' -derivedDataPath $(DERIVED_DATA)-analyze analyze CODE_SIGNING_ALLOWED=NO

check: lint analyze

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA) clean

# Optional evidence-preserving full run. Existing focused regressions remain unchanged.
.PHONY: verified-test test-tools
MINIMUM_TESTS ?= 234

verified-test: project
	PYTHONDONTWRITEBYTECODE=1 python3 scripts/run_verified_tests.py \
		--minimum-tests $(MINIMUM_TESTS) --require ReBloomTests --require ReBloomUITests -- \
		-project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) test

test-tools:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests -v
