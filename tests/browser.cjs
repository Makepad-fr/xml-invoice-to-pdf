const {chromium}=require('playwright');
const {readFileSync}=require('node:fs');
const {resolve}=require('node:path');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch();
 try {
 const context=await browser.newContext({offline:true});
 const page=await context.newPage(),network=[],errors=[];
 page.on('request',r=>{if(!r.url().startsWith('file:'))network.push(r.url())});
 page.on('pageerror',e=>errors.push(e.message));
 await page.goto('file://'+resolve('index.html'));
 const xml=readFileSync('tests/fixtures/demo.xml');
 await page.locator('#file').setInputFiles([
  {name:'one.xml',mimeType:'text/xml',buffer:xml},
  {name:'two.xml',mimeType:'text/xml',buffer:xml},
  {name:'broken.xml',mimeType:'text/xml',buffer:Buffer.from('<broken>')}
 ]);
 await page.waitForFunction(()=>document.querySelector('#status').textContent==='2 ready · 1 could not be read');
 assert.equal(await page.locator('.file-row').count(),3);
 assert.match(await page.locator('.totals').textContent(),/720.00 EUR/);
 await page.locator('.file-select').nth(2).click();
 assert(await page.locator('#print').isDisabled());
 assert(await page.locator('#preview').isHidden());
 await page.locator('.file-select').first().click();
 await page.evaluate(()=>{window.print=()=>{window.printed=true}});
 await page.locator('#print-all').click();
 assert.equal(await page.locator('.sheet').count(),2);
 assert(await page.evaluate(()=>window.printed));
 await page.evaluate(()=>dispatchEvent(new Event('afterprint')));
 assert.equal(await page.locator('.sheet').count(),1);
 await page.locator('#clear').click();
 const source=xml.toString();
 await page.evaluate(source=>{const dataTransfer=new DataTransfer();for(const name of ['drop1.xml','drop2.xml'])dataTransfer.items.add(new File([source],name));document.querySelector('#drop').dispatchEvent(new DragEvent('drop',{bubbles:true,dataTransfer}));},source);
 await page.waitForFunction(()=>document.querySelector('#status').textContent==='2 ready');
 await page.locator('.remove').first().click();assert.equal(await page.locator('.file-row').count(),1);
 await page.locator('#clear').click();
 await page.locator('#file').setInputFiles({name:'entity.xml',mimeType:'text/xml',buffer:Buffer.from('<!DOCTYPE x [<!ENTITY e SYSTEM "https://example.com">]><x>&e;</x>')});
 await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('could not'));
 assert(await page.locator('#print-all').isDisabled());
 await page.setViewportSize({width:390,height:844});
 assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 assert.deepEqual(network,[]);assert.deepEqual(errors,[]);
 console.log('PASS: batch, invalid XML, DTD rejection, drag/drop, totals, printing, reset, mobile and offline privacy');
 } finally {await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
