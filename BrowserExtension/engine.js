export class TabEngine {
  constructor({media = navigator.mediaDevices, Context = AudioContext, now = () => Date.now()} = {}) {
    this.media = media;
    this.Context = Context;
    this.now = now;
    this.routes = new Map();
    this.errors = new Map();
    this.pending = 0;
    this.pendingIDs = new Set();
    this.pendingResources = new Map();
    this.tabGenerations = new Map();
    this.reservation = false;
    this.generation = 0;
    this.command = null;
    this.released = "";
    this.lastRevision = -1;
  }
  get owns() { return this.reservation || this.pending > 0 || this.routes.size > 0; }
  get permitted() { return this.command?.allow && this.command.expires * 1000 > this.now(); }
  reserve() { this.reservation = true; this.reservationUntil = this.now() + 5000; this.released = ""; }
  cancelReservation() { this.reservation = false; this.confirmRelease(); }
  confirmRelease() {
    if (!this.owns) this.released = this.command?.authority || "";
  }
  async stop(id, error = "") {
    this.tabGenerations.set(id, (this.tabGenerations.get(id) || 0) + 1);
    const route = this.routes.get(id) || this.pendingResources.get(id);
    this.routes.delete(id);
    this.pendingResources.delete(id);
    if (route) {
      route.stream.getTracks().forEach(track => track.stop());
      route.source?.disconnect();
      route.gain?.disconnect();
      route.context?.close().catch(() => {});
    }
    if (error) this.errors.set(id, error);
    this.confirmRelease();
  }
  async stopAll(preserveReservation = false) {
    this.generation++;
    this.reservation = preserveReservation && this.reservation;
    await Promise.all([...new Set([...this.routes.keys(), ...this.pendingResources.keys()])].map(id => this.stop(id)));
    this.confirmRelease();
  }
  async tick() {
    if (!this.permitted && this.owns && (this.routes.size > 0 || this.pending > 0 || this.now() > this.reservationUntil)) await this.stopAll();
  }
  async apply(command) {
    if (!command) { await this.tick(); return; }
    if (command.authority === this.command?.authority && command.revision < this.lastRevision) return;
    if (this.command && (command.authority !== this.command.authority || command.session !== this.command.session)) await this.stopAll();
    this.command = command;
    this.lastRevision = command.revision;
    if (!this.permitted) { await this.stopAll(this.pending === 0 && this.routes.size === 0 && this.now() < this.reservationUntil); return; }
    for (const [id, route] of [...this.routes]) {
      const settings = command.tabs[String(id)];
      if (!settings || settings.release) { await this.stop(id); continue; }
      try {
        await this.configure(route, settings);
        if (this.routes.get(id) === route) route.revision = command.revision;
      } catch (error) { if (this.routes.get(id) === route) await this.stop(id, `Output unavailable: ${error.message}`); }
    }
    this.confirmRelease();
  }
  async configure(route, settings) {
    if (settings.release) throw new Error("Tab released");
    if (!Number.isFinite(settings.volume) || settings.volume < 0 || settings.volume > 1 || typeof settings.output !== "string") throw new Error("Invalid tab settings");
    const sink = settings.output === "default" ? "" : settings.output;
    if ((route.context.sinkId || "") !== sink) {
      if (typeof route.context.setSinkId !== "function") throw new Error("This browser does not support output selection");
      route.switching = true;
      try { await route.context.setSinkId(sink); } finally { route.switching = false; }
    }
    if (!this.permitted) throw new Error("OpenAudio disconnected");
    route.gain.gain.setTargetAtTime(settings.muted ? 0 : settings.volume, route.context.currentTime, 0.01);
    route.settings = {...settings};
  }
  async start(id, streamId) {
    if (this.routes.has(id) || this.pendingIDs.has(id)) { this.cancelReservation(); return; }
    if (!this.permitted) throw new Error("Enable audio control in OpenAudio first");
    const generation = this.generation;
    const tabGeneration = (this.tabGenerations.get(id) || 0) + 1;
    this.tabGenerations.set(id, tabGeneration);
    const valid = () => generation === this.generation && this.tabGenerations.get(id) === tabGeneration && this.permitted && !this.command.tabs[String(id)]?.release;
    this.pendingIDs.add(id);
    this.pending++;
    this.errors.delete(id);
    let stream, context;
    try {
      stream = await this.media.getUserMedia({audio: {mandatory: {chromeMediaSource: "tab", chromeMediaSourceId: streamId}}, video: false});
      if (!valid()) throw new Error("Tab activation was cancelled");
      this.pendingResources.set(id, {stream});
      context = new this.Context();
      this.pendingResources.get(id).context = context;
      const source = context.createMediaStreamSource(stream);
      const gain = context.createGain();
      gain.gain.value = 0;
      const meter = context.createAnalyser?.();
      const samples = meter ? new Float32Array(meter.fftSize) : null;
      source.connect(gain);
      if (meter) gain.connect(meter).connect(context.destination);
      else gain.connect(context.destination);
      const route = {stream, context, source, gain, meter, samples, settings: {volume: 1, muted: false, output: "default", release: false}, revision: 0};
      this.pendingResources.set(id, route);
      do {
        const revision = this.command.revision;
        await this.configure(route, this.command.tabs[String(id)] || route.settings);
        if (!valid()) throw new Error("Tab activation was cancelled");
        await context.resume();
        if (!valid() || context.state !== "running") throw new Error("Tab playback could not start");
        route.revision = revision;
      } while (route.revision !== this.command.revision);
      this.routes.set(id, route);
      stream.getTracks().forEach(track => track.addEventListener("ended", () => this.stop(id)));
    } catch (error) {
      stream?.getTracks().forEach(track => track.stop());
      context?.close().catch(() => {});
      this.errors.set(id, error.message);
      throw error;
    } finally {
      this.pending--;
      this.pendingIDs.delete(id);
      this.pendingResources.delete(id);
      this.reservation = false;
      this.confirmRelease();
    }
  }
}
