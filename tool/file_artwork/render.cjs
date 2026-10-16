const fs=require('fs'),path=require('path');
const sharp=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES
 ? process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES+'/sharp' : 'sharp');
(async()=>{for(const file of fs.readdirSync(__dirname).filter(x=>x.endsWith('.svg'))) {
 await sharp(path.join(__dirname,file),{density:288}).png()
  .toFile(path.resolve(__dirname,'../../assets/files',file.replace('.svg','.png')));
}})();
