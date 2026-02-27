function initPorts(app) {
  if (!('serial' in navigator)) {
    console.warn(
      'Web Serial API not available. ' +
      'Use Chrome 89+ or Edge 89+ and serve from localhost or HTTPS.'
    );
  }

  let serialPort = null;
  let reader = null;

  app.ports.openPort.subscribe(async (baudRate) => {
    try {
      serialPort = await navigator.serial.requestPort();
      await serialPort.open({ baudRate });
      app.ports.portOpened.send(null);
      readLoop();
    } catch (e) {
      app.ports.portError.send(e.message);
    }
  });

  app.ports.sendData.subscribe(async (text) => {
    if (!serialPort || !serialPort.writable) return;
    try {
      const writer = serialPort.writable.getWriter();
      await writer.write(new TextEncoder().encode(text));
      writer.releaseLock();
    } catch (e) {
      app.ports.portError.send(e.message);
    }
  });

  app.ports.closePort.subscribe(async () => {
    try {
      if (reader) {
        await reader.cancel();
        reader = null;
      }
      if (serialPort) {
        await serialPort.close();
        serialPort = null;
      }
      app.ports.portClosed.send(null);
    } catch (e) {
      app.ports.portError.send(e.message);
    }
  });

  app.ports.scrollToBottom.subscribe(() => {
    const el = document.getElementById('terminal-output');
    if (el) el.scrollTop = el.scrollHeight;
  });

  async function readLoop() {
    if (!serialPort || !serialPort.readable) return;
    reader = serialPort.readable.getReader();
    const decoder = new TextDecoder();
    try {
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        app.ports.dataReceived.send(decoder.decode(value));
      }
    } catch (e) {
      app.ports.portError.send(e.message);
    } finally {
      reader.releaseLock();
      reader = null;
      app.ports.portClosed.send(null);
    }
  }
}
