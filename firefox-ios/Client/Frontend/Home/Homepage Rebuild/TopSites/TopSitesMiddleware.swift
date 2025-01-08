// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import Foundation
import Redux
import Storage

final class TopSitesMiddleware {
    private let topSitesManager: TopSitesManagerInterface
    private let logger: Logger

    // Raw data to build top sites with, we may want to revisit and fetch only the number of top sites we want
    // but keeping logic consistent for now
    private var otherSites: [TopSiteState] = []
    private var sponsoredTiles: [SponsoredTile] = []

    init(
        profile: Profile = AppContainer.shared.resolve(),
        topSitesManager: TopSitesManagerInterface? = nil,
        logger: Logger = DefaultLogger.shared
    ) {
        self.topSitesManager = topSitesManager ?? TopSitesManager(
            profile: profile,
            googleTopSiteManager: GoogleTopSiteManager(
                prefs: profile.prefs
            ),
            topSiteHistoryManager: TopSiteHistoryManager(profile: profile),
            searchEnginesManager: profile.searchEnginesManager
        )
        self.logger = logger
    }

    lazy var topSitesProvider: Middleware<AppState> = { state, action in
        switch action.actionType {
        case HomepageActionType.initialize,
            TopSitesActionType.fetchTopSites:
            self.getTopSitesDataAndUpdateState(for: action)
        case ContextMenuActionType.tappedOnPinTopSite:
            guard let site = self.getSite(for: action) else { return }
            self.topSitesManager.pinTopSite(site)
        case ContextMenuActionType.tappedOnUnpinTopSite:
            guard let site = self.getSite(for: action) else { return }
            self.topSitesManager.unpinTopSite(site)
        case ContextMenuActionType.tappedOnRemoveTopSite:
            guard let site = self.getSite(for: action) else { return }
            self.topSitesManager.removeTopSite(site)
        default:
            break
        }
    }

    private func getSite(for action: Action) -> Site? {
        guard let site = (action as? ContextMenuAction)?.site else {
            self.logger.log(
                "Unable to retrieve site for \(action.actionType)",
                level: .warning,
                category: .homepage
            )
            return nil
        }
        return site
    }

    private func getTopSitesDataAndUpdateState(for action: Action) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    self.otherSites = await self.topSitesManager.getOtherSites()
                    await self.updateTopSites(
                        for: action.windowUUID,
                        otherSites: self.otherSites,
                        sponsoredTiles: self.sponsoredTiles
                    )
                }
                group.addTask {
                    self.sponsoredTiles = await self.topSitesManager.fetchSponsoredSites()
                    await self.updateTopSites(
                        for: action.windowUUID,
                        otherSites: self.otherSites,
                        sponsoredTiles: self.sponsoredTiles
                    )
                }

                await group.waitForAll()
                await updateTopSites(
                    for: action.windowUUID,
                    otherSites: self.otherSites,
                    sponsoredTiles: self.sponsoredTiles
                )
            }
        }
    }

    private func updateTopSites(
        for windowUUID: WindowUUID,
        otherSites: [TopSiteState],
        sponsoredTiles: [SponsoredTile]
    ) async {
        let topSites = await self.topSitesManager.recalculateTopSites(
            otherSites: otherSites,
            sponsoredSites: sponsoredTiles
        )
        store.dispatch(
            TopSitesAction(
                topSites: topSites,
                windowUUID: windowUUID,
                actionType: TopSitesMiddlewareActionType.retrievedUpdatedSites
            )
        )
    }
}