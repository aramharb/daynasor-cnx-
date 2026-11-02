// Detects whether the device *really* has internet (not just a Wi-Fi link).
// Uses the Capacitor Network plugin on device when available, browser events
// otherwise, and confirms with a tiny no-cors probe request.

const PROBE_URLS = [
  'https://www.gstatic.com/generate_204',
  'https://www.google.com/favicon.ico',
  'https://cloudflare.com/favicon.ico',
];

export class NetworkMonitor {
  constructor({ interval = 12000, timeout = 4000 } = {}) {
    this.interval = interval;
    this.timeout = timeout;
    this.online = null; // unknown until first check
    this.listeners = new Set();
    this.override = null; // 'online' | 'offline' | null (debug: ?net=online)
  }

  onChange(cb) { this.listeners.add(cb); return () => this.listeners.delete(cb); }

  start() {
    const q = new URLSearchParams(location.search).get('net');
    if (q === 'online' || q === 'offline') this.override = q;

    window.addEventListener('online', () => this.check());
    window.addEventListener('offline', () => this.set(false));
    document.addEventListener('visibilitychange', () => { if (!document.hidden) this.check(); });

    const Net = window.Capacitor?.Plugins?.Network;
    if (Net?.addListener) {
      try {
        Net.addListener('networkStatusChange', (s) => (s.connected ? this.check() : this.set(false)));
      } catch { /* plugin missing */ }
    }

    this.check();
    this.timer = setInterval(() => this.check(), this.interval);
  }

  set(v) {
    if (this.override) v = this.override === 'online';
    if (v === this.online) return;
    const prev = this.online;
    this.online = v;
    this.listeners.forEach((cb) => cb(v, prev));
  }

  async check() {
    if (this.override) return this.set(this.override === 'online');
    if (navigator.onLine === false) return this.set(false);
    for (const url of PROBE_URLS) {
      if (await this.probe(url)) return this.set(true);
    }
    this.set(false);
  }

  async probe(url) {
    const ctrl = typeof AbortController !== 'undefined' ? new AbortController() : null;
    const t = setTimeout(() => ctrl?.abort(), this.timeout);
    try {
      await fetch(`${url}?_=${Date.now()}`, { mode: 'no-cors', cache: 'no-store', signal: ctrl?.signal });
      return true;
    } catch {
      return false;
    } finally {
      clearTimeout(t);
    }
  }
}
