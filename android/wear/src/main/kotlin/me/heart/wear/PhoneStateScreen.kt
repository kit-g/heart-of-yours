package me.heart.wear

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.AppScaffold
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.ui.tooling.preview.WearPreviewDevices

@Composable
fun PhoneStateScreen(state: PhoneState) {
    AppScaffold {
        ScreenScaffold {
            when (state) {
                PhoneState.Awaiting -> AwaitingPhone()
            }
        }
    }
}

/// Before the phone has sent anything: a phone, which is the whole instruction
/// and reads in every language — there is no copy to say it with yet.
@Composable
private fun AwaitingPhone() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Icon(
            painter = painterResource(R.drawable.ic_phone),
            contentDescription = null,
            modifier = Modifier.size(44.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@WearPreviewDevices
@Composable
private fun AwaitingPreview() {
    HeartTheme { PhoneStateScreen(PhoneState.Awaiting) }
}
