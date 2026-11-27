part of '../../heart_db.dart';

/// A template changed on this device while the server could not be reached
/// (#448): the server's copy the change started from, as its JSON. Null for a
/// template with nothing owed. Kept so that, once the server answers again,
/// the app can tell a copy nobody else touched (the change is sent) from one
/// replaced meanwhile, by an assistant or another device (both are kept).
///
/// 37, not 35: another open branch holds 35. The runner takes the versions
/// in order whatever the gaps, but only those above the one a device is at:
/// whichever of the branches merges later must sit above every version
/// already merged, renumbering if it has to, or a device that opened the
/// database in between never runs it.
const addTemplateUnsentBase = 'ALTER TABLE templates ADD COLUMN unsent_base TEXT';

/// Who assigned a template, the master it was copied from and whether the
/// master's edits flow down, as the server says them (#448). The mirror kept
/// none of the three, so a template read back from it no longer read as
/// assigned. The profile is its JSON.
const addTemplateAssignedBy = 'ALTER TABLE templates ADD COLUMN assigned_by TEXT';
const addTemplateSource = 'ALTER TABLE templates ADD COLUMN source_template_id TEXT';
const addTemplateSyncEnabled = 'ALTER TABLE templates ADD COLUMN sync_enabled INTEGER';
