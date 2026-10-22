package me.heart.wear

/// What the phone last told the watch — the twin of `WatchState` in
/// ios/Watch/WatchState.swift. The phone is the only writer: each state is
/// complete on its own, never a delta against one the watch may not have.
sealed interface PhoneState {
    /// Nothing from the phone yet.
    data object Awaiting : PhoneState
}
