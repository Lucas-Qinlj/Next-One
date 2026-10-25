import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const directory=path.dirname(fileURLToPath(import.meta.url));
const urls=Object.fromEntries(['garden','coral','moon','fish','plants'].map(name=>[name,'data:image/png;base64,'+fs.readFileSync(path.join(directory,'assets',name+'.png')).toString('base64')]));
const source=fs.readFileSync(path.join(directory,'preview.template.html'),'utf8');
const html=source.replace('__ASSET_URLS__',JSON.stringify(urls));
if(Buffer.byteLength(html)>1_000_000)throw new Error('Inline preview exceeds 1 MB');
for(const file of [path.join(directory,'preview.html'),...process.argv.slice(2)]){fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,html);}
console.log('Built preview: '+Buffer.byteLength(html)+' bytes');
