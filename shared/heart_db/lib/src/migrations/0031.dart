part of '../../heart_db.dart';

/// A coach's copy (#558): the revisions a write starts from, its own fields'
/// and each session's, as the server last gave them. Without them a write made
/// after a launch offline would start from nothing and conflict with what it
/// already holds.
const addProgramRevision = 'ALTER TABLE programs ADD COLUMN revision INTEGER';
const addProgramSessionRevisions = 'ALTER TABLE programs ADD COLUMN session_revisions TEXT';
