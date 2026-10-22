package me.heart.wear

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.AppScaffold
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import androidx.wear.compose.ui.tooling.preview.WearPreviewDevices

@Composable
fun PhoneStateScreen(state: PhoneState) {
    AppScaffold {
        when (state) {
            PhoneState.Awaiting -> ScreenScaffold { AwaitingPhone() }
            is PhoneState.Idle -> ScreenScaffold { Message(state.message) }
            is PhoneState.Off -> ScreenScaffold { Message(state.message) }
            is PhoneState.Workout -> WorkoutScreen(state)
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

/// No workout, or switched off: one line, pointing at the phone.
@Composable
private fun Message(text: String) {
    Column(
        Modifier
            .fillMaxSize()
            .padding(horizontal = 24.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            painter = painterResource(R.drawable.ic_phone),
            contentDescription = null,
            modifier = Modifier.size(32.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
    }
}

@WearPreviewDevices
@Composable
private fun AwaitingPreview() {
    HeartTheme { PhoneStateScreen(PhoneState.Awaiting) }
}

@WearPreviewDevices
@Composable
private fun IdlePreview() {
    HeartTheme { PhoneStateScreen(PhoneState.Idle("Start a workout on your phone")) }
}
