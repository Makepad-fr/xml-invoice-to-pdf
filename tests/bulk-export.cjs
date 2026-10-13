const {chromium}=require('playwright');const assert=require('node:assert/strict');const {resolve}=require('node:path');const {originalPDF,ubl}=require('./fixtures.cjs');
(async()=>{const browser=await chromium.launch({channel:'chromium'});try{const context=await browser.newContext({offline:true,acceptDownloads:true});const page=await context.newPage();const original=await originalPDF();let downloads=0;page.on('download',()=>downloads++);
 await page.addInitScript(()=>{
  window.bulk={active:0,max:0,data:{'invoice.pdf':[1,2,3]},calls:0,mode:'ok'};
  const directory={name:'Chosen folder',async *keys(){for(const name of Object.keys(bulk.data))yield name;},async getFileHandle(name,opts){if(!opts?.create&&!(name in bulk.data))throw new DOMException('Missing','NotFoundError');return {async createWritable(){bulk.active++;bulk.max=Math.max(bulk.max,bulk.active);let buffer;return {async write(bytes){await new Promise(r=>setTimeout(r,60));if(bulk.mode==='fail'&&name==='failed.pdf')throw new Error('Disk is full');buffer=Array.from(bytes)},async close(){bulk.data[name]=buffer;bulk.active--},async abort(){bulk.active--;bulk.aborted=true}}}}}};
  window.showDirectoryPicker=async options=>{bulk.calls++;bulk.options=options;if(bulk.mode==='cancel')throw new DOMException('Cancelled','AbortError');if(bulk.mode==='denied')throw new DOMException('Denied','NotAllowedError');if(bulk.mode==='unsupported')throw new DOMException('Unavailable','NotSupportedError');return directory;};
 });
 await page.goto('file://'+resolve('index.html'));
 assert.equal(await page.locator('#batch-format').inputValue(),'files');
 const load=async names=>{if(await page.locator('#clear').isVisible())await page.locator('#clear').click();await page.locator('#file').setInputFiles(names.map(name=>({name,mimeType:'text/xml',buffer:Buffer.from(ubl(original))})));await page.waitForFunction(()=>!document.querySelector('#status').textContent.includes('Reading'));};
 await load(['invoice.xml','invoice.xml','third.xml','fourth.xml','fifth.xml','sixth.xml']);await page.locator('#print-all').click();await page.waitForFunction(()=>document.querySelector('#status').textContent.startsWith('Saved 6 PDFs'));
 const result=await page.evaluate(()=>bulk);assert.equal(result.calls,1);assert.equal(result.options.mode,'readwrite');assert.equal(result.max,4);assert.deepEqual(result.data['invoice.pdf'],[1,2,3]);for(const name of ['invoice (1).pdf','invoice (2).pdf','third.pdf','fourth.pdf','fifth.pdf','sixth.pdf'])assert.deepEqual(Buffer.from(result.data[name]),original);assert.equal(downloads,0);
 // Explicit ZIP never opens a folder picker.
 await page.locator('#batch-format').selectOption('zip');const zipEvent=page.waitForEvent('download');await page.locator('#print-all').click();await zipEvent;assert.equal(await page.evaluate(()=>bulk.calls),1);
 await page.locator('#batch-format').selectOption('files');await page.evaluate(()=>bulk.mode='cancel');await page.locator('#print-all').click();await page.waitForFunction(()=>document.querySelector('#status').textContent==='Export cancelled.');assert.equal(downloads,1);
 await page.evaluate(()=>bulk.mode='denied');await page.locator('#print-all').click();await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('Denied'));assert.equal(downloads,1);
 // Partial failure reports exact counts and does not trigger duplicate ZIPs.
 await page.evaluate(()=>bulk.mode='fail');await load(['good.xml','failed.xml']);await page.locator('#print-all').click();await page.waitForFunction(()=>document.querySelector('#status').textContent.startsWith('Saved 1 of 2'));assert.match(await page.locator('#status').textContent(),/failed.xml: Disk is full/);assert(await page.evaluate(()=>bulk.aborted));assert.equal(downloads,1);
 await page.evaluate(()=>bulk.mode='unsupported');const fallback=page.waitForEvent('download');await page.locator('#print-all').click();await fallback;await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('Downloaded a ZIP'));assert.equal(downloads,2);
 // Browser without API defaults to ZIP without guessing support from its name.
 await page.addInitScript(()=>Object.defineProperty(window,'showDirectoryPicker',{value:undefined,configurable:true}));await page.reload();assert.equal(await page.locator('#batch-format').inputValue(),'zip');assert(await page.locator('#batch-format option[value=files]').isDisabled());await load(['one.xml']);const unsupported=page.waitForEvent('download');await page.locator('#print-all').click();await unsupported;
 // Exercise real browser FileSystemDirectoryHandle/FileSystemWritableFileStream;
 // only the OS folder chooser is substituted, avoiding access to personal folders.
 const native=await browser.newContext();const fsPage=await native.newPage();
 await fsPage.route('https://invoice.test/',route=>route.fulfill({contentType:'text/html',body:require('node:fs').readFileSync(resolve('index.html'),'utf8')}));
 await fsPage.addInitScript(()=>{window.showDirectoryPicker=()=>navigator.storage.getDirectory()});
 await fsPage.goto('https://invoice.test/');
 await fsPage.locator('#file').setInputFiles(['native.xml','native.xml'].map(name=>({name,mimeType:'text/xml',buffer:Buffer.from(ubl(original))})));
 await fsPage.waitForFunction(()=>!document.querySelector('#print-all').disabled);await fsPage.locator('#print-all').click();
 await fsPage.waitForFunction(()=>document.querySelector('#status').textContent.startsWith('Saved 2 PDFs'));
 const actual=await fsPage.evaluate(async()=>{const dir=await navigator.storage.getDirectory();const result={};for await(const [name,handle]of dir.entries())result[name]=Array.from(new Uint8Array(await(await handle.getFile()).arrayBuffer()));return result;});
 assert.deepEqual(Object.keys(actual).sort(),['native (1).pdf','native.pdf']);for(const bytes of Object.values(actual))assert.deepEqual(Buffer.from(bytes),original);await native.close();
 console.log('PASS real browser filesystem writes; parallel saves (max 4), exact bytes, existing/duplicate names, explicit ZIP, cancel, permission refusal, partial failure, unsupported API fallback');await context.close();}finally{await browser.close()}})().catch(e=>{console.error(e);process.exit(1)});
