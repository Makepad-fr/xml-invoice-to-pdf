// Inline the pinned validator so index.html remains a self-contained offline app.
const fs=require('node:fs');
const start='<!-- BEGIN PDF VALIDATOR -->',end='<!-- END PDF VALIDATOR -->';
let html=fs.readFileSync('index.html','utf8');
const library=fs.readFileSync('node_modules/pdf-lib/dist/pdf-lib.min.js','utf8').replace(/\/\/# sourceMappingURL=.*$/m,'');
const license=fs.readFileSync('node_modules/pdf-lib/LICENSE.md','utf8');
if(/<\/script/i.test(library))throw Error('Unexpected script terminator in dependency');
const block=`${start}\n<script>/* pdf-lib 1.17.1 — used only to validate; original bytes are never rewritten.\n${license}\n*/\n${library}\n</script>\n${end}`;
const a=html.indexOf(start),b=html.indexOf(end);
if(a>=0&&b>a)html=html.slice(0,a)+block+html.slice(b+end.length);
else html=html.replace('</main><script>',`</main>${block}<script>`);
fs.writeFileSync('index.html',html);
