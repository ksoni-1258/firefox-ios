// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Redux
import Shared
import Common

struct BrowserViewControllerState: ScreenState, Equatable {
    enum NavigationType {
        case home
        case back
        case forward
        case reload
        case stopLoading
        case newTab
    }

    enum DisplayType {
        case qrCodeReader
        case backForwardList
        case trackingProtectionDetails
        case tabsLongPressActions
        case locationViewLongPressAction
        case menu
        case reloadLongPressAction
        case tabTray
        case share
        case readerMode
        case newTabLongPressActions
        case dataClearance
    }

    let windowUUID: WindowUUID
    var searchScreenState: SearchScreenState
    var showDataClearanceFlow: Bool
    var fakespotState: FakespotState
    var toast: ToastType?
    var showOverlay: Bool
    var reloadWebView: Bool
    var browserViewType: BrowserViewType
    var navigateTo: NavigationType? // use default value when re-creating
    var displayView: DisplayType? // use default value when re-creating
    var buttonTapped: UIButton?
    var microsurveyState: MicrosurveyPromptState

    init(appState: AppState, uuid: WindowUUID) {
        guard let bvcState = store.state.screenState(
            BrowserViewControllerState.self,
            for: .browserViewController,
            window: uuid)
        else {
            self.init(windowUUID: uuid)
            return
        }

        self.init(searchScreenState: bvcState.searchScreenState,
                  showDataClearanceFlow: bvcState.showDataClearanceFlow,
                  fakespotState: bvcState.fakespotState,
                  toast: bvcState.toast,
                  showOverlay: bvcState.showOverlay,
                  windowUUID: bvcState.windowUUID,
                  reloadWebView: bvcState.reloadWebView,
                  browserViewType: bvcState.browserViewType,
                  navigateTo: bvcState.navigateTo,
                  displayView: bvcState.displayView,
                  buttonTapped: bvcState.buttonTapped,
                  microsurveyState: bvcState.microsurveyState)
    }

    init(windowUUID: WindowUUID) {
        self.init(
            searchScreenState: SearchScreenState(),
            showDataClearanceFlow: false,
            fakespotState: FakespotState(windowUUID: windowUUID),
            toast: nil,
            showOverlay: false,
            windowUUID: windowUUID,
            browserViewType: .normalHomepage,
            navigateTo: nil,
            displayView: nil,
            buttonTapped: nil,
            microsurveyState: MicrosurveyPromptState(windowUUID: windowUUID))
    }

    init(
        searchScreenState: SearchScreenState,
        showDataClearanceFlow: Bool,
        fakespotState: FakespotState,
        toast: ToastType? = nil,
        showOverlay: Bool = false,
        windowUUID: WindowUUID,
        reloadWebView: Bool = false,
        browserViewType: BrowserViewType,
        navigateTo: NavigationType? = nil,
        displayView: DisplayType? = nil,
        buttonTapped: UIButton? = nil,
        microsurveyState: MicrosurveyPromptState
    ) {
        self.searchScreenState = searchScreenState
        self.showDataClearanceFlow = showDataClearanceFlow
        self.fakespotState = fakespotState
        self.toast = toast
        self.windowUUID = windowUUID
        self.showOverlay = showOverlay
        self.reloadWebView = reloadWebView
        self.browserViewType = browserViewType
        self.navigateTo = navigateTo
        self.displayView = displayView
        self.buttonTapped = buttonTapped
        self.microsurveyState = microsurveyState
    }

    static let reducer: Reducer<Self> = { state, action in
        // Only process actions for the current window
        guard action.windowUUID == .unavailable || action.windowUUID == state.windowUUID else { return state }

        if let action = action as? FakespotAction {
            return BrowserViewControllerState.reduceStateForFakeSpotAction(action: action, state: state)
        } else if let action = action as? MicrosurveyPromptAction {
            return BrowserViewControllerState.reduceStateForMicrosurveyAction(action: action, state: state)
        } else if let action = action as? PrivateModeAction {
            return BrowserViewControllerState.reduceStateForPrivateModeAction(action: action, state: state)
        } else if let action = action as? GeneralBrowserAction {
            return BrowserViewControllerState.reduceStateForGeneralBrowserAction(action: action, state: state)
        } else {
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                showOverlay: state.showOverlay,
                windowUUID: state.windowUUID,
                reloadWebView: false,
                browserViewType: state.browserViewType,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        }
    }

    static func reduceStateForFakeSpotAction(action: FakespotAction,
                                             state: BrowserViewControllerState) -> BrowserViewControllerState {
        return BrowserViewControllerState(
            searchScreenState: state.searchScreenState,
            showDataClearanceFlow: state.showDataClearanceFlow,
            fakespotState: FakespotState.reducer(state.fakespotState, action),
            windowUUID: state.windowUUID,
            browserViewType: state.browserViewType,
            microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
    }

    static func reduceStateForMicrosurveyAction(action: MicrosurveyPromptAction,
                                                state: BrowserViewControllerState) -> BrowserViewControllerState {
        return BrowserViewControllerState(
            searchScreenState: state.searchScreenState,
            showDataClearanceFlow: state.showDataClearanceFlow,
            fakespotState: state.fakespotState,
            windowUUID: state.windowUUID,
            browserViewType: state.browserViewType,
            microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
    }

    static func reduceStateForPrivateModeAction(action: PrivateModeAction,
                                                state: BrowserViewControllerState) -> BrowserViewControllerState {
        switch action.actionType {
        case PrivateModeActionType.privateModeUpdated:
            let privacyState = action.isPrivate ?? false
            var browserViewType = state.browserViewType
            if browserViewType != .webview {
                browserViewType = privacyState ? .privateHomepage : .normalHomepage
            }
            return BrowserViewControllerState(
                searchScreenState: SearchScreenState(inPrivateMode: privacyState),
                showDataClearanceFlow: privacyState,
                fakespotState: state.fakespotState,
                windowUUID: state.windowUUID,
                reloadWebView: true,
                browserViewType: browserViewType,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        default:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                windowUUID: state.windowUUID,
                reloadWebView: state.reloadWebView,
                browserViewType: state.browserViewType,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        }
    }

    static func reduceStateForGeneralBrowserAction(action: GeneralBrowserAction,
                                                   state: BrowserViewControllerState) -> BrowserViewControllerState {
        switch action.actionType {
        case GeneralBrowserActionType.showToast:
            guard let toastType = action.toastType else { return state }
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: toastType,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.showOverlay:
            let showOverlay = action.showOverlay ?? false
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                showOverlay: showOverlay,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.updateSelectedTab:
            return BrowserViewControllerState.resolveStateForUpdateSelectedTab(action: action, state: state)
        case GeneralBrowserActionType.goToHomepage:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: state.toast,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                navigateTo: .home,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.addNewTab:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: state.toast,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                navigateTo: .newTab,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.showQRcodeReader:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: state.toast,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                displayView: .qrCodeReader,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.showBackForwardList:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: state.toast,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                displayView: .backForwardList,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.showTrackingProtectionDetails:
            return BrowserViewControllerState(
                    searchScreenState: state.searchScreenState,
                    showDataClearanceFlow: state.showDataClearanceFlow,
                    fakespotState: state.fakespotState,
                    toast: state.toast,
                    windowUUID: state.windowUUID,
                    browserViewType: state.browserViewType,
                    displayView: .trackingProtectionDetails,
                    microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.showMenu:
            return BrowserViewControllerState(
                    searchScreenState: state.searchScreenState,
                    showDataClearanceFlow: state.showDataClearanceFlow,
                    fakespotState: state.fakespotState,
                    toast: state.toast,
                    windowUUID: state.windowUUID,
                    browserViewType: state.browserViewType,
                    displayView: .menu,
                    buttonTapped: action.buttonTapped,
                    microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.showTabsLongPressActions:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: state.toast,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                displayView: .tabsLongPressActions,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.showReloadLongPressAction:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: state.toast,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                displayView: .reloadLongPressAction,
                buttonTapped: action.buttonTapped,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.showLocationViewLongPressActionSheet:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: state.toast,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                displayView: .locationViewLongPressAction,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.navigateBack:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: state.toast,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                navigateTo: .back,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.navigateForward:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: state.toast,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                navigateTo: .forward,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.showTabTray:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: state.toast,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                displayView: .tabTray,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.reloadWebsite:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: state.toast,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                navigateTo: .reload,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.stopLoadingWebsite:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: state.toast,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                navigateTo: .stopLoading,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.showShare:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: state.toast,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                displayView: .share,
                buttonTapped: action.buttonTapped,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.showReaderMode:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: state.toast,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                displayView: .readerMode,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.showNewTabLongPressActions:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                toast: state.toast,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                displayView: .newTabLongPressActions,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        case GeneralBrowserActionType.clearData:
            return BrowserViewControllerState(
                searchScreenState: state.searchScreenState,
                showDataClearanceFlow: state.showDataClearanceFlow,
                fakespotState: state.fakespotState,
                windowUUID: state.windowUUID,
                browserViewType: state.browserViewType,
                displayView: .dataClearance,
                microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
        default:
            return state
        }
    }

    static func resolveStateForUpdateSelectedTab(action: GeneralBrowserAction,
                                                 state: BrowserViewControllerState) -> BrowserViewControllerState {
        let isAboutHomeURL = InternalURL(action.selectedTabURL)?.isAboutHomeURL ?? false
        var browserViewType = BrowserViewType.normalHomepage
        let isPrivateBrowsing = action.isPrivateBrowsing ?? false

        if isAboutHomeURL {
            browserViewType = isPrivateBrowsing ? .privateHomepage : .normalHomepage
        } else {
            browserViewType = .webview
        }

        return BrowserViewControllerState(
            searchScreenState: state.searchScreenState,
            showDataClearanceFlow: state.showDataClearanceFlow,
            fakespotState: state.fakespotState,
            showOverlay: state.showOverlay,
            windowUUID: state.windowUUID,
            reloadWebView: true,
            browserViewType: browserViewType,
            microsurveyState: MicrosurveyPromptState.reducer(state.microsurveyState, action))
    }
}
