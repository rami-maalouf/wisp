import type { Answer, NativeModule, Result, Sources } from './app.contract.d.ts';

export const appId = 'com.rami.exact-recorder';
export const grants = 'device.microphone purpose.microphone';

const unavailable: Result<'recorderStatus'> = {
  available: false, phase: 'idle', microphones: [], selectedMic: '', folder: '',
  elapsed: '00:00', fileName: '', filePath: '', error: 'Recording requires the macOS app.', inputLevel: '', fileWarning: '', level: 0, folderName: '', recents: [], recentError: '',
};

async function command(native: NativeModule | null | undefined, op: string, id = ''): Promise<Result<'startRecording'>> {
  if (!native?.available) return { ok: false, error: unavailable.error };
  try {
    return await native.later({ op, id }) as Result<'startRecording'>;
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : String(error) };
  }
}

const sources: Sources = {
  recorderStatus: (_args, _store, _storage, native) => {
    if (!native?.available) return unavailable;
    native.watch('status');
    return native.call({ op: 'status' }) as Result<'recorderStatus'>;
  },
  selectMicrophone: ([id], _store, _storage, native) => command(native, 'select', id),
  refreshMicrophones: (_args, _store, _storage, native) => command(native, 'refresh'),
  chooseFolder: (_args, _store, _storage, native) => command(native, 'folder'),
  startRecording: (_args, _store, _storage, native) => command(native, 'start'),
  pauseRecording: (_args, _store, _storage, native) => command(native, "pause"),
  resumeRecording: (_args, _store, _storage, native) => command(native, "resume"),
  stopRecording: (_args, _store, _storage, native) => command(native, 'stop'),
  cancelRecording: (_args, _store, _storage, native) => command(native, 'cancel'),
  revealRecording: (_args, _store, _storage, native) => command(native, 'reveal'),
  trashRecording: (_args, _store, _storage, native) => command(native, 'trash'),
  openRecordingFolder: (_args, _store, _storage, native) => command(native, 'open-folder'),
  refreshRecordings: (_args, _store, _storage, native) => command(native, 'refresh-recents'),
  revealRecentRecording: ([id], _store, _storage, native) => command(native, 'reveal-recent', id),
  trashRecentRecording: ([id], _store, _storage, native) => command(native, 'trash-recent', id),
};

export const answer: Answer = (source, args, store, storage, native) =>
  sources[source](args, store, storage, native);
