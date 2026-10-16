// Requires sharp. Run after extract.py. 4x artwork keeps source curves crisp.
const path = require('path');
const fs = require('fs');
const sharp = require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES
  ? process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES + '/sharp' : 'sharp');
const root = path.resolve(__dirname, '../..');
(async () => {
  for (const file of fs.readdirSync(__dirname).filter(x => x.endsWith('.svg') && !x.startsWith('navigation_'))) {
    await sharp(path.join(__dirname, file), {density: 288}).png()
      .toFile(path.join(root, 'assets/home/exact_' + file.replace('.svg', '.png')));
  }
  for (const state of ['settings', 'neutral']) {
    const rendered = await sharp(path.join(__dirname, 'navigation_'+state+'.svg'),
      {density: 288}).png().toBuffer();
    await sharp(rendered).extract({left: 0, top: 2788, width: 1500, height: 464})
      .toFile(path.join(root, 'assets/home/exact_navigation_'+state+'.png'));
  }
  // Flatten nested SVG filters against their original backdrop before slicing.
  // This preserves the exact original shadow compositing, including the notch.
  const reference = await sharp(path.join(root, 'design/home_empty_reference.svg'),
    {density: 288}).png().toBuffer();
  for (const [name, top, height] of [['navigation',697,116],['masthead',44,58]]) {
    await sharp(reference).extract({left: 0, top: top*4, width: 1500, height: height*4})
      .toFile(path.join(root, 'assets/home/exact_'+name+'.png'));
  }
})();
