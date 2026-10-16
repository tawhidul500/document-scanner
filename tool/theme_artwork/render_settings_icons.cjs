const path = require('path');
const sharp = require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES
  ? process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES + '/sharp' : 'sharp');
const names = ['language','theme','vibration','beep','share','rate','privacy','terms','apps','about','chevron'];
(async () => {
  for (const name of names) for (const suffix of ['', '_dark']) {
    await sharp(path.join(__dirname, name+suffix+'.svg'), {density:288})
      .png().toFile(path.join(__dirname,'../../assets/theme', name+suffix+'.png'));
  }
})();
