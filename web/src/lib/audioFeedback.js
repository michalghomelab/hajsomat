let audioContext = null;

function audioCtx() {
  const AudioCtx = window.AudioContext || window.webkitAudioContext;
  if (!AudioCtx) return null;

  audioContext ||= new AudioCtx();
  return audioContext;
}

async function ensureAudio() {
  const ctx = audioCtx();
  if (!ctx) return null;
  if (ctx.state === "suspended") {
    await ctx.resume?.();
  }
  return ctx.state === "running" ? ctx : null;
}

function playTone(ctx, frequency, peak = 0.028, duration = 0.07) {
  const now = ctx.currentTime + 0.005;
  const oscillator = ctx.createOscillator();
  const gain = ctx.createGain();

  oscillator.type = "triangle";
  oscillator.frequency.setValueAtTime(frequency, now);
  gain.gain.setValueAtTime(0.0001, now);
  gain.gain.exponentialRampToValueAtTime(peak, now + 0.006);
  gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);
  oscillator.connect(gain);
  gain.connect(ctx.destination);
  oscillator.start(now);
  oscillator.stop(now + duration + 0.01);
}

export async function unlockAudio() {
  const ctx = await ensureAudio();
  if (!ctx) return;
  playTone(ctx, 360, 0.002, 0.025);
}

export async function clickSound(frequency = 560) {
  const ctx = await ensureAudio();
  if (!ctx) return;
  playTone(ctx, frequency);
}

export async function testSound() {
  const ctx = await ensureAudio();
  if (!ctx) return;
  playTone(ctx, 520, 0.04, 0.08);
  window.setTimeout(() => playTone(ctx, 680, 0.035, 0.08), 95);
}
