package com.hsi.harki.live_darbar.oacp

import android.content.Context
import org.oacp.android.OacpParams
import org.oacp.android.OacpReceiver
import org.oacp.android.OacpResult

/**
 * Placeholder receiver for any future background OACP actions.
 *
 * Currently all Live Darbar actions are foreground (activity-based)
 * and handled by MainActivity. This receiver exists so the SDK's
 * auto-registered ContentProvider works and for future expansion
 * (e.g., background "what's playing" queries).
 */
class OacpActionReceiver : OacpReceiver() {

    override fun onAction(
        context: Context,
        action: String,
        params: OacpParams,
        requestId: String?
    ): OacpResult? {
        // All current actions are foreground (activity-based).
        // Future background actions can be added here.
        return null
    }
}
