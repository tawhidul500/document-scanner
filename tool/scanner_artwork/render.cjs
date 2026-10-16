const path=require('path');
const sharp=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES
 ? process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES+'/sharp' : 'sharp');
(async()=>{for(const name of ['close','flash','images','files']) {
 await sharp(path.join(__dirname,name+'.svg'),{density:288}).png()
  .toFile(path.resolve(__dirname,'../../assets/scanner',name+'.png'));
}})();
